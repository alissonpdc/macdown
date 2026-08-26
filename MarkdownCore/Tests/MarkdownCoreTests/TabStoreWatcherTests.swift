import XCTest
@testable import MarkdownCore

// R4.4 — rename/move externo não deixa aba órfã: url, título e histórico atualizam;
// identidade da aba (id) e scroll position são preservados.
final class TabStoreWatcherTests: XCTestCase {
    private var root: URL!
    private var store: TabStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# A\nv1".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        store = TabStore()
        try store.open(url: root.appendingPathComponent("a.md"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private let oldPath: String = ""
    private var aURL: URL { root.appendingPathComponent("a.md") }

    func testRenameUpdatesDocumentURLAndTitle() throws {
        let newURL = root.appendingPathComponent("b.md")
        try "# B\nv1".write(to: newURL, atomically: true, encoding: .utf8)

        store.apply([WatchEvent(url: newURL, kind: .renamed(previous: aURL))])

        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs[0].document.url.standardizedFileURL, newURL.standardizedFileURL)
        XCTAssertEqual(store.tabs[0].title, "b.md")
    }

    func testRenamePreservesTabIdentityScrollAndSelection() throws {
        let newURL = root.appendingPathComponent("b.md")
        try "v1".write(to: newURL, atomically: true, encoding: .utf8)
        let id = store.tabs[0].id
        store.setScrollOffset(42, for: id)

        store.apply([WatchEvent(url: newURL, kind: .renamed(previous: aURL))])

        XCTAssertEqual(store.tabs[0].id, id)
        XCTAssertEqual(store.tabs[0].scrollOffset, 42)
        XCTAssertEqual(store.activeTabID, id)
    }

    func testRenameRemapsHistoryEntries() throws {
        let newURL = root.appendingPathComponent("b.md")
        try "v1".write(to: newURL, atomically: true, encoding: .utf8)
        let other = root.appendingPathComponent("c.md")
        try "v1".write(to: other, atomically: true, encoding: .utf8)
        let id = store.tabs[0].id
        store.recordVisit(other.resolvingSymlinksInPath().path, in: id) // histórico: [a, c]

        store.apply([WatchEvent(url: newURL, kind: .renamed(previous: aURL))]) // [b, c]

        XCTAssertTrue(store.canGoBack(in: id))
        _ = store.goBack(in: id)
        XCTAssertEqual(store.tabs[0].document.url.standardizedFileURL, newURL.standardizedFileURL,
                       "voltar no histórico abre pelo caminho novo (remapeado)")
    }

    // MARK: R4.2 — indicador discreto de atualizado

    func testModifiedEventMarksTabAsUpdated() throws {
        try "# A\nv2 externo".write(to: aURL, atomically: true, encoding: .utf8)
        store.apply([WatchEvent(url: aURL, kind: .modified)])

        XCTAssertTrue(store.tabs[0].hasExternalUpdate)
    }

    func testConfirmClearsUpdatedFlag() throws {
        store.apply([WatchEvent(url: aURL, kind: .modified)])
        let id = store.tabs[0].id

        store.confirmExternalUpdate(in: id)

        XCTAssertFalse(store.tabs[0].hasExternalUpdate)
    }

    func testModifiedReloadsDocumentContentPreservingScroll() throws {
        try "# A\nv2 externo".write(to: aURL, atomically: true, encoding: .utf8)
        let id = store.tabs[0].id
        store.setScrollOffset(99, for: id)

        store.apply([WatchEvent(url: aURL, kind: .modified)])

        XCTAssertEqual(store.tabs[0].document.rawText, "# A\nv2 externo")
        XCTAssertEqual(store.tabs[0].scrollOffset, 99)
        XCTAssertEqual(store.activeTabID, id)
    }

    func testUnrelatedEventsAreIgnored() throws {
        let other = root.appendingPathComponent("c.md")
        try "x".write(to: other, atomically: true, encoding: .utf8)

        store.apply([WatchEvent(url: other, kind: .modified)])
        store.apply([WatchEvent(url: other, kind: .created)])

        XCTAssertEqual(store.tabs[0].document.url.standardizedFileURL, aURL.standardizedFileURL)
    }
}
