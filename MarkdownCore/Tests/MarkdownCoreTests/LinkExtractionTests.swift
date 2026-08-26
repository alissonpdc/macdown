import XCTest
import Markdown
@testable import MarkdownCore

// R3.5/R6.2 — extrair links de um bloco para renderização clicável
final class LinkExtractionTests: XCTestCase {
    func testExtractLinksFromParagraph() throws {
        let links = InlineLinkExtractor.links(in: "veja [b](b.md) e [spec](sub/spec.md)")
        XCTAssertEqual(links.map(\.href), ["b.md", "sub/spec.md"])
        XCTAssertEqual(links.map(\.label), ["b", "spec"])
    }

    func testParagraphWithoutLinksIsEmpty() {
        XCTAssertTrue(InlineLinkExtractor.links(in: "texto simples").isEmpty)
    }

    func testAttributedTextMarksLinkRanges() {
        let attributed = InlineLinkExtractor.attributed(
            markdown: "veja [b](b.md)",
            baseURL: URL(fileURLWithPath: "/tmp/a.md")
        )
        let ns = NSAttributedString(attributed)
        var found = false
        ns.enumerateAttribute(.link, in: NSRange(location: 0, length: ns.length)) { value, range, _ in
            if let url = value as? URL {
                found = true
                XCTAssertEqual(url.lastPathComponent, "b.md")
                XCTAssertGreaterThan(range.length, 0)
            }
        }
        XCTAssertTrue(found, "esperado range com .link")
    }
}
