import XCTest
@testable import MacDownCore

// Feedback do usuário: pastas sem nenhum .md na subárvore não aparecem;
// indentação hierárquica é responsabilidade da view (testada visualmente).
final class FolderTreePruningTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "A".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)

        // com-docs/ (tem .md no próprio nível)
        let withDocs = root.appendingPathComponent("with-docs", isDirectory: true)
        try FileManager.default.createDirectory(at: withDocs, withIntermediateDirectories: true)
        try "C".write(to: withDocs.appendingPathComponent("c.md"), atomically: true, encoding: .utf8)

        // fundo-do-poco/ (sem .md no nível, mas tem em sub-subpasta) → deve aparecer
        let deep = root.appendingPathComponent("fundo-do-poco").appendingPathComponent("nivel2")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try "D".write(to: deep.appendingPathComponent("d.md"), atomically: true, encoding: .utf8)

        // vazia-total/ (nenhum .md em lugar nenhum) → deve ser podada
        let empty = root.appendingPathComponent("vazia-total/x/y", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try "bin".write(to: empty.appendingPathComponent("blob.bin"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testFolderWithOwnMarkdownIsKept() throws {
        let tree = FolderScanner.scan(root: root, pruningEmptyFolders: true)
        XCTAssertTrue(tree.children.contains { $0.name == "with-docs" })
    }

    func testFolderWithMarkdownOnlyDeepDownIsKept() {
        let tree = FolderScanner.scan(root: root, pruningEmptyFolders: true)
        let deep = tree.children.first { $0.name == "fundo-do-poco" }
        XCTAssertNotNil(deep)
        XCTAssertEqual(deep?.children.first?.name, "nivel2")
    }

    func testTotallyEmptyBranchIsPruned() {
        let tree = FolderScanner.scan(root: root, pruningEmptyFolders: true)
        XCTAssertFalse(tree.children.contains { $0.name == "vazia-total" })
    }

    func testPruningDisabledKeepsEverything() {
        let tree = FolderScanner.scan(root: root, pruningEmptyFolders: false)
        XCTAssertTrue(tree.children.contains { $0.name == "vazia-total" })
    }
}
