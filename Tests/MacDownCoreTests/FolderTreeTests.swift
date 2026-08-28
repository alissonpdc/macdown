import XCTest
@testable import MacDownCore

// R2.4 — apenas família markdown na árvore; R2.1 base — scan recursivo de pasta
final class FolderTreeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // estrutura:
        // a.md  b.markdown  notas.txt  code.swift
        // sub/ (c.mdown  d.mkd)  vazio/  img/ (foto.png)
        try "A".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "B".write(to: root.appendingPathComponent("b.markdown"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("notas.txt"), atomically: true, encoding: .utf8)
        try "y".write(to: root.appendingPathComponent("code.swift"), atomically: true, encoding: .utf8)
        let sub = root.appendingPathComponent("sub", isDirectory: true)
        let img = root.appendingPathComponent("img", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: img, withIntermediateDirectories: true)
        try "C".write(to: sub.appendingPathComponent("c.mdown"), atomically: true, encoding: .utf8)
        try "D".write(to: sub.appendingPathComponent("d.mkd"), atomically: true, encoding: .utf8)
        try "p".write(to: img.appendingPathComponent("foto.png"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testScanListsOnlyMarkdownFilesButAllFolders() {
        let tree = FolderScanner.scan(root: root)
        XCTAssertEqual(tree.files.map(\.lastPathComponent), ["a.md", "b.markdown"])
        let sub = tree.children.first { $0.name == "sub" }
        XCTAssertNotNil(sub)
        XCTAssertEqual(sub?.files.map(\.lastPathComponent).sorted(), ["c.mdown", "d.mkd"])
    }

    func testPruningOffKeepsEmptyFolders() {
        // com poda desligada, pasta vazia aparece
        let tree = FolderScanner.scan(root: root, pruningEmptyFolders: false)
        XCTAssertTrue(tree.children.contains { $0.name == "img" && $0.files.isEmpty })
    }

    func testDefaultScanPrunesEmptyFolders() {
        let tree = FolderScanner.scan(root: root)
        XCTAssertFalse(tree.children.contains { $0.name == "img" })
    }

    func testFileNamesAreSorted() {
        // c.mdown < d.mkd já em ordem; testa ordenação alfabética geral
        let tree = FolderScanner.scan(root: root)
        let names = tree.files.map(\.lastPathComponent)
        XCTAssertEqual(names, names.sorted())
    }

    func testMarkdownFamilyDetection() {
        XCTAssertTrue(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/a.md")))
        XCTAssertTrue(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/a.MARKDOWN")))
        XCTAssertTrue(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/b.mdown")))
        XCTAssertTrue(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/c.mkd")))
        XCTAssertFalse(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/notas.txt")))
        XCTAssertFalse(FolderScanner.isMarkdown(URL(fileURLWithPath: "/x/noext")))
    }
}
