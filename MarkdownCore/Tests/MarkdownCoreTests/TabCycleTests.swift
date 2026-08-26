import XCTest
@testable import MarkdownCore

// Feedback UX — navegação entre abas:
// Cmd+←/→ muda para aba anterior/seguinte; Ctrl+Tab alterna ciclicamente.
final class TabCycleTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        for name in ["a", "b", "c"] {
            try "# \(name)".write(to: tmpDir.appendingPathComponent("\(name).md"), atomically: true, encoding: .utf8)
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func makeStoreWith3Tabs() throws -> TabStore {
        let store = TabStore()
        try store.open(url: tmpDir.appendingPathComponent("a.md"))
        try store.open(url: tmpDir.appendingPathComponent("b.md"))
        try store.open(url: tmpDir.appendingPathComponent("c.md"))
        return store
    }

    func testSelectNextMovesToFollowingTab() throws {
        let store = try makeStoreWith3Tabs()
        store.select(store.tabs[1].id)
        store.selectNext()
        XCTAssertEqual(store.activeTabID, store.tabs[2].id)
    }

    func testSelectNextAtEndWrapsAround() throws {
        let store = try makeStoreWith3Tabs()
        // ativa é a 3ª
        store.selectNext()
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
    }

    func testSelectPreviousMovesBack() throws {
        let store = try makeStoreWith3Tabs()
        store.select(store.tabs[1].id)
        store.selectPrevious()
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
    }

    func testSelectPreviousAtStartWrapsAround() throws {
        let store = try makeStoreWith3Tabs()
        store.select(store.tabs[0].id)   // vai para a primeira
        store.selectPrevious()           // deve envolver para a última
        XCTAssertEqual(store.activeTabID, store.tabs[2].id)
    }

    func testCycleOnSingleTabIsNoOp() throws {
        let store = TabStore()
        try store.open(url: tmpDir.appendingPathComponent("a.md"))
        store.selectNext()
        store.selectPrevious()
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
    }
}
