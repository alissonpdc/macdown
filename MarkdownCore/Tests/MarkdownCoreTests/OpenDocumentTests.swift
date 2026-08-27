import XCTest
@testable import MarkdownCore

// R1.1/R1.3 base — modelo de documento aberto: carrega arquivo, separa frontmatter,
// parseia corpo; arquivo inexistente → erro estruturado.
final class OpenDocumentTests: XCTestCase {
    private var tmpDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        fileURL = tmpDir.appendingPathComponent("spec.md")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testLoadPlainMarkdownFile() throws {
        try "# Título\n\nparágrafo".write(to: fileURL, atomically: true, encoding: .utf8)
        let doc = try OpenDocument(url: fileURL)
        XCTAssertEqual(doc.url, fileURL)
        XCTAssertNil(doc.frontmatterError)
        XCTAssertTrue(doc.document.blocks.contains { $0 is HeadingNode })
    }

    func testLoadWithFrontmatter() throws {
        // R3.4
        try "---\ntitle: Minha Spec\n---\n# Corpo".write(to: fileURL, atomically: true, encoding: .utf8)
        let doc = try OpenDocument(url: fileURL)
        let fm = doc.frontmatter
        XCTAssertEqual(fm?["title"], .string("Minha Spec"))
        // frontmatter não vaza para os blocos renderizáveis
        XCTAssertFalse(doc.document.blocks.compactMap { $0 as? ParagraphNode }.contains { $0.text == "title: Minha Spec" })
    }

    func testInvalidFrontmatterSurfacesErrorButLoadsBody() throws {
        // R10.2 — sinaliza sem perder o corpo
        try "---\nbroken: [x\n---\n# Corpo válido".write(to: fileURL, atomically: true, encoding: .utf8)
        let doc = try OpenDocument(url: fileURL)
        XCTAssertNotNil(doc.frontmatterError)
        XCTAssertTrue(doc.document.blocks.contains { $0 is HeadingNode })
    }

    func testMissingFileThrowsStructuredError() {
        XCTAssertThrowsError(try OpenDocument(url: tmpDir.appendingPathComponent("nao-existe.md"))) { error in
            guard case OpenDocumentError.readFailed = error else {
                return XCTFail("esperado readFailed, veio \(error)")
            }
        }
    }

    func testWordAndCharacterCounts() throws {
        // R8.1 base — stats do rodapé
        try "olá mundo\n\nsegundo".write(to: fileURL, atomically: true, encoding: .utf8)
        let doc = try OpenDocument(url: fileURL)
        XCTAssertEqual(doc.wordCount, 3)
        XCTAssertEqual(doc.characterCount, "olá mundo\n\nsegundo".count)
    }
}
