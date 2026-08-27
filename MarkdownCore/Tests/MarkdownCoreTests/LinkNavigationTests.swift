import XCTest
@testable import MarkdownCore

// R6.2/R6.3 — resolução de links relativos + histórico por aba
final class LinkNavigationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# A\nveja [b](b.md)".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        let sub = root.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "# C".write(to: sub.appendingPathComponent("c.md"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testResolveSiblingLink() throws {
        // R3.5 — link relativo entre arquivos da pasta
        let resolved = LinkResolver.resolve(href: "b.md", from: root.appendingPathComponent("a.md"))
        XCTAssertEqual(resolved?.lastPathComponent, "b.md")
    }

    func testResolveSubdirectoryLink() throws {
        let resolved = LinkResolver.resolve(href: "sub/c.md", from: root.appendingPathComponent("a.md"))
        XCTAssertEqual(resolved?.path, root.appendingPathComponent("sub/c.md").path)
    }

    func testAnchorOnlyLinkIsNil() {
        XCTAssertNil(LinkResolver.resolve(href: "#secao", from: root.appendingPathComponent("a.md")))
    }

    func testExternalURLIsNil() {
        XCTAssertNil(LinkResolver.resolve(href: "https://example.com", from: root.appendingPathComponent("a.md")))
    }

    // R6.3 — histórico por aba
    func testHistoryRecordsSequenceAndNavigates() throws {
        let store = TabStore()
        let a = root.appendingPathComponent("a.md")
        let c = root.appendingPathComponent("sub/c.md")
        try store.open(url: a)
        let tabID = store.activeTabID!

        store.recordVisit(a.path, in: tabID)   // abertura já registra a; visita repetida não duplica
        store.recordVisit(c.path, in: tabID)

        XCTAssertTrue(store.canGoBack(in: tabID))
        XCTAssertFalse(store.canGoForward(in: tabID))

        store.goBack(in: tabID)
        XCTAssertEqual(store.currentHistoryEntry(in: tabID)?.lastPathComponent, "a.md")
        XCTAssertTrue(store.canGoForward(in: tabID))

        store.goForward(in: tabID)
        XCTAssertEqual(store.currentHistoryEntry(in: tabID)?.lastPathComponent, "c.md")

        // nova visita após back trunca o forward
        store.goBack(in: tabID)
        store.recordVisit(a.path, in: tabID)
        XCTAssertFalse(store.canGoForward(in: tabID))
    }

    func testOpenRecordsVisitInActiveTab() throws {
        let store = TabStore()
        let a = root.appendingPathComponent("a.md")
        try store.open(url: a)
        XCTAssertEqual(store.currentHistoryEntry(in: store.activeTabID!)?.lastPathComponent, "a.md")
    }

    // MARK: - HTML link href generation

    func testRelativeLinkPreservedInHTML() {
        let input = "Veja [outro](sub/outro.md) aqui."
        let doc = MarkdownParser().parse(input)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("href=\"sub/outro.md\""), "Relative href should be preserved in HTML")
    }

    func testSiblingLinkPreservedInHTML() {
        let input = "Veja [arquivo](b.md) aqui."
        let doc = MarkdownParser().parse(input)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("href=\"b.md\""), "Sibling link href should be preserved")
    }

    func testAnchorLinkPreservedInHTML() {
        let input = "Veja [seção](#minha-seção) aqui."
        let doc = MarkdownParser().parse(input)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("href=\"#minha-seção\""), "Anchor link should be preserved")
    }

    func testExternalLinkPreservedInHTML() {
        let input = "Veja [site](https://example.com) aqui."
        let doc = MarkdownParser().parse(input)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("href=\"https://example.com\""), "External link should be preserved")
    }
}
