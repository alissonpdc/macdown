import XCTest
@testable import MarkdownCore

// R6.1 — abas; R2.5 — estado de leitura (scroll) por documento
final class TabStoreTests: XCTestCase {
    private var tmpDir: URL!
    private var a: URL! { tmpDir.appendingPathComponent("a.md") }
    private var b: URL! { tmpDir.appendingPathComponent("b.md") }

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try "# A".write(to: a, atomically: true, encoding: .utf8)
        try "# B".write(to: b, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testOpenFirstTabBecomesActive() throws {
        let store = TabStore()
        try store.open(url: a)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, store.tabs.first?.id)
        XCTAssertEqual(store.activeTab?.document.url, a)
    }

    func testOpenSameFileTwiceReusesExistingTab() throws {
        let store = TabStore()
        try store.open(url: a)
        try store.open(url: a)
        XCTAssertEqual(store.tabs.count, 1)
    }

    func testOpenSecondTabActivatesIt() throws {
        let store = TabStore()
        try store.open(url: a)
        let first = store.activeTabID
        try store.open(url: b)
        XCTAssertEqual(store.tabs.count, 2)
        XCTAssertNotEqual(store.activeTabID, first)
    }

    func testCloseActiveTabActivatesNeighbor() throws {
        let store = TabStore()
        try store.open(url: a)
        try store.open(url: b)
        let bTab = store.activeTabID
        store.close(id: bTab!)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, store.tabs.first?.id)
    }

    func testCloseLastTabEmptiesStore() throws {
        let store = TabStore()
        try store.open(url: a)
        store.close(id: store.tabs[0].id)
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertNil(store.activeTabID)
    }

    // R2.5 — scroll lembrado por aba na sessão
    func testScrollPositionSurvivesTabSwitch() throws {
        let store = TabStore()
        try store.open(url: a)
        try store.open(url: b)
        let aTab = store.tabs[0]
        store.setScrollOffset(420, for: aTab.id)

        try store.open(url: b) // no-op, já aberta
        store.select(aTab.id)
        XCTAssertEqual(store.activeTab?.scrollOffset, 420)
    }

    func testTitleIsFileNameWithoutExtension() throws {
        let store = TabStore()
        try store.open(url: a)
        XCTAssertEqual(store.tabs[0].title, "a")
    }
}
