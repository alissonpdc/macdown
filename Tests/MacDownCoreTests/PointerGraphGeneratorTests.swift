import XCTest
@testable import MacDownCore

final class PointerGraphGeneratorTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PointerGraphTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Link extraction

    func testExtractsInternalLinks() {
        let text = "See [other doc](other.md) and [external](https://example.com)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertEqual(links, ["other.md"])
    }

    func testExtractsImageLinks() {
        let text = "![logo](assets/logo.md)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertEqual(links, ["assets/logo.md"])
    }

    func testIgnoresAnchorOnlyLinks() {
        let text = "See [section](#section)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertTrue(links.isEmpty)
    }

    func testIgnoresExternalLinks() {
        let text = "See [google](https://google.com) and [mail](mailto:test@example.com)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertTrue(links.isEmpty)
    }

    func testIgnoresDataUris() {
        let text = "![img](data:image/png;base64,abc)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertTrue(links.isEmpty)
    }

    func testExtractsLinkWithFragment() {
        let text = "See [doc](doc.md#section)"
        let links = PointerGraphGenerator.extractLinks(from: text)
        XCTAssertEqual(links, ["doc.md"])
    }

    // MARK: - File scanning

    func testScanFindsMarkdownFiles() {
        createFile("a.md", content: "# A")
        createFile("b.txt", content: "not md")
        createFile("c.markdown", content: "# C")
        let files = PointerGraphGenerator.scanMarkdownFiles(root: tempDir)
        XCTAssertEqual(files.count, 2)
    }

    func testScanSkipsHiddenDirectories() {
        createFile("visible.md", content: "# Visible")
        let hiddenDir = tempDir.appendingPathComponent(".hidden")
        try? FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        createFile(".hidden/secret.md", content: "# Secret", in: hiddenDir)
        let files = PointerGraphGenerator.scanMarkdownFiles(root: tempDir)
        XCTAssertEqual(files.count, 1)
    }

    // MARK: - Graph generation

    func testEmptyFolderProducesEmptyGraph() {
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 0)
        XCTAssertEqual(result.edgeCount, 0)
        XCTAssertTrue(result.isolatedFiles.isEmpty)
        XCTAssertTrue(result.mermaidCode.contains("graph LR"))
    }

    func testSingleFileWithNoLinks() {
        createFile("readme.md", content: "# Hello\n\nNo links here.")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 1)
        XCTAssertEqual(result.edgeCount, 0)
        XCTAssertEqual(result.isolatedFiles.count, 1)
        XCTAssertTrue(result.isolatedFiles.first?.contains("readme.md") ?? false)
    }

    func testTwoFilesLinked() {
        createFile("a.md", content: "# A\n\nSee [B](b.md)")
        createFile("b.md", content: "# B\n\nBack to [A](a.md)")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 2)
        XCTAssertEqual(result.edgeCount, 2, "a→b and b→a")
        XCTAssertTrue(result.isolatedFiles.isEmpty, "both files are connected")
    }

    func testOneWayLink() {
        createFile("source.md", content: "# Source\n\nLink to [target](target.md)")
        createFile("target.md", content: "# Target\n\nNo outgoing links.")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 2)
        XCTAssertEqual(result.edgeCount, 1)
        XCTAssertTrue(result.isolatedFiles.isEmpty)
    }

    func testIsolatedFileDetected() {
        createFile("linked.md", content: "# Linked\n\nSee [other](other.md)")
        createFile("other.md", content: "# Other\n\nSee [linked](linked.md)")
        createFile("lonely.md", content: "# Lonely\n\nNo links at all.")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 3)
        XCTAssertEqual(result.edgeCount, 2)
        XCTAssertEqual(result.isolatedFiles.count, 1)
        XCTAssertTrue(result.isolatedFiles.first?.contains("lonely.md") ?? false)
    }

    func testSubdirectoryLinks() {
        createFile("a.md", content: "# A\n\nSee [B](sub/b.md)")
        let subDir = tempDir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        createFile("b.md", content: "# B\n\nBack to [A](../a.md)", in: subDir)
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.nodeCount, 2)
        XCTAssertEqual(result.edgeCount, 2)
    }

    func testDuplicateLinksDeduped() {
        createFile("a.md", content: "# A\n\n[b](b.md) and [b](b.md) again")
        createFile("b.md", content: "# B")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertEqual(result.edgeCount, 1, "duplicate links should be deduped")
    }

    func testMermaidCodeContainsGraphDirective() {
        createFile("a.md", content: "# A")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertTrue(result.mermaidCode.contains("graph LR"))
    }

    func testNodeLabelsUseFileNames() {
        createFile("my-doc.md", content: "# Doc")
        let result = PointerGraphGenerator.generate(root: tempDir)
        XCTAssertTrue(result.mermaidCode.contains("my-doc.md"))
    }

    func testSanitizeLabelRemovesQuotes() {
        let sanitized = PointerGraphGenerator.sanitizeLabel("file\"name.md")
        XCTAssertFalse(sanitized.contains("\""))
    }

    func testRelativePathCalculation() {
        let file = tempDir.appendingPathComponent("sub/file.md")
        let rel = PointerGraphGenerator.relativePath(of: file, from: tempDir)
        XCTAssertEqual(rel, "sub/file.md")
    }

    // MARK: - Helpers

    private func createFile(_ name: String, content: String, in dir: URL? = nil) {
        let fileURL = (dir ?? tempDir).appendingPathComponent(name)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
