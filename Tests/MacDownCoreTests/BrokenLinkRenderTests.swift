// R10.1 — render marca links quebrados com class="broken-link" + data-broken
// para o badge do rodapé rolar até a ocorrência no documento.

import XCTest
@testable import MacDownCore

final class BrokenLinkRenderTests: XCTestCase {

    private func convert(_ markdown: String, broken: Set<String>) -> String {
        let converter = MarkdownHTMLConverter()
        converter.brokenHrefs = broken
        return converter.convertRawMarkdown(markdown)
    }

    func testLinkQuebradoRecebeClasseEAtributo() {
        let html = convert("[t](fantasma.md)", broken: ["fantasma.md"])
        XCTAssertTrue(html.contains(#"<a href="fantasma.md" class="broken-link" data-broken="fantasma.md">"#))
    }

    func testLinkValidoNaoRecebeClasse() {
        let html = convert("[t](ok.md)", broken: ["fantasma.md"])
        XCTAssertTrue(html.contains(#"<a href="ok.md">"#))
        XCTAssertFalse(html.contains("class=\"broken-link\""))
    }

    func testImagemQuebradaRecebeClasseEAtributo() {
        let html = convert("![logo](img/fantasma.png)", broken: ["img/fantasma.png"])
        XCTAssertTrue(html.contains(#"class="broken-link" data-broken="img/fantasma.png""#))
    }

    func testHrefComCaracteresEscapadosCasaComHrefBruto() {
        // `&` vira `&amp;` no HTML, mas data-broken decodificado deve casar com o href bruto
        let html = convert("[t](a&b.md)", broken: ["a&b.md"])
        XCTAssertTrue(html.contains(#"class="broken-link""#))
        XCTAssertTrue(html.contains(#"data-broken="a&amp;b.md""#))
    }

    func testSetVazioNaoAlteraRenderPadrao() {
        let plain = MarkdownHTMLConverter().convertRawMarkdown("[t](x.md) ![i](y.png)")
        let marked = convert("[t](x.md) ![i](y.png)", broken: [])
        XCTAssertEqual(plain, marked)
    }

    func testConvertBlockTambemMarca() {
        let converter = MarkdownHTMLConverter()
        converter.brokenHrefs = ["fantasma.md"]
        let p = ParagraphNode(text: "t", rawMarkdown: "[t](fantasma.md)")
        let html = converter.convertBlock(p, baseFileURL: nil)
        XCTAssertTrue(html.contains("broken-link"))
    }
}
