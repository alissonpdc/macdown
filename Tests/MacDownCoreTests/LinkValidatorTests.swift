// R10.1 — validação de links internos quebrados: arquivo inexistente e âncora inexistente.

import XCTest
@testable import MacDownCore

final class LinkValidatorTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinkValidatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ content: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func broken(_ markdown: String, file: String = "doc.md") throws -> [BrokenLink] {
        let url = try write(file, markdown)
        return LinkValidator.brokenLinks(in: try OpenDocument(url: url))
    }

    // arquivo interno existente → ok

    func testLinkParaArquivoExistenteNaoSeraQuebrado() throws {
        _ = try write("target.md", "# T\n")
        let result = try broken("[t](target.md)")
        XCTAssertTrue(result.isEmpty)
    }

    // arquivo interno inexistente → fileNotFound

    func testLinkParaArquivoInexistente() throws {
        let result = try broken("[t](missing.md)")
        XCTAssertEqual(result, [BrokenLink(href: "missing.md", reason: .fileNotFound)])
    }

    // externos ignorados

    func testLinksExternosSaoIgnorados() throws {
        let result = try broken("[site](https://example.com) [mail](mailto:a@b.c) [ftp](ftp://x.com)")
        XCTAssertTrue(result.isEmpty)
    }

    // âncora pura no próprio documento

    func testAncoraPuraExistente() throws {
        let result = try broken("[vai](#seção-dois)\n\n## Seção Dois\n")
        XCTAssertTrue(result.isEmpty)
    }

    func testAncoraPuraInexistente() throws {
        let result = try broken("[vai](#nao-existe)")
        XCTAssertEqual(result, [BrokenLink(href: "#nao-existe", reason: .anchorNotFound)])
    }

    // arquivo + âncora

    func testAncoraInexistenteEmArquivoExistente() throws {
        _ = try write("target.md", "# Unico\n")
        let result = try broken("[t](target.md#fantasma)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].href, "target.md#fantasma")
        XCTAssertEqual(result[0].reason, .anchorNotFound)
    }

    func testAncoraExistenteEmArquivoAlvo() throws {
        _ = try write("target.md", "# Alvo\n")
        let result = try broken("[t](target.md#alvo)")
        XCTAssertTrue(result.isEmpty)
    }

    // âncora em arquivo não-markdown é ignorada (não dá para extrair slugs)

    func testAncoraEmArquivoNaoMarkdownEhIgnorada() throws {
        _ = try write("page.html", "<h1 id=\"x\">x</h1>\n")
        let result = try broken("[t](page.html#x)")
        XCTAssertTrue(result.isEmpty)
    }

    // imagens locais

    func testImagemLocalInexistente() throws {
        let result = try broken("![logo](img/fantasma.png)")
        XCTAssertEqual(result, [BrokenLink(href: "img/fantasma.png", reason: .fileNotFound)])
    }

    func testImagemLocalExistente() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("img"), withIntermediateDirectories: true)
        _ = try write("img/logo.png", "binário")
        let result = try broken("![logo](img/logo.png)")
        XCTAssertTrue(result.isEmpty)
    }

    // path com %20

    func testLinkComEspacoCodificado() throws {
        _ = try write("meu arquivo.md", "# X\n")
        let result = try broken("[t](meu%20arquivo.md)")
        XCTAssertTrue(result.isEmpty)
    }

    // caminho relativo com ../

    func testLinkComParentDirectory() throws {
        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        _ = try write("target.md", "# X\n")
        let result = try broken("[t](../target.md)", file: "sub/doc.md")
        XCTAssertTrue(result.isEmpty)
    }

    // deduplicação: mesmo link quebrado duas vezes aparece uma vez

    func testLinksRepetidosSaoDeduplicados() throws {
        let result = try broken("[a](fantasma.md) e [b](fantasma.md)")
        XCTAssertEqual(result.count, 1)
    }

    // frontmatter não gera falso positivo

    func testFrontmatterNaoGeraFalsoPositivo() throws {
        let result = try broken("---\ntags: [a, b]\n---\n\n[t](#nada)")
        XCTAssertEqual(result, [BrokenLink(href: "#nada", reason: .anchorNotFound)])
    }
}
