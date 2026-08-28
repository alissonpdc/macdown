import XCTest
@testable import MarkdownCore

// Blockquote multiline: cada parágrafo da citação vira um <p> próprio
final class QuoteMultilineTests: XCTestCase {
    let parser = MarkdownParser()

    func testMultilineQuoteKeepsParagraphs() {
        let markdown = "> linha um\n>\n> linha dois"
        let doc = parser.parse(markdown)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<blockquote><p>linha um</p>\n<p>linha dois</p></blockquote>"),
                      "got: \(html)")
    }

    func testQuoteWithMultipleBlocksGetsOneParagraphEach() {
        let markdown = "> primeiro\n>\n> segundo\n>\n> terceiro"
        let node = try! XCTUnwrap(parser.parse(markdown).blocks.first as? QuoteNode)
        XCTAssertEqual(node.paragraphs, ["primeiro", "segundo", "terceiro"])
    }

    func testPlainTextStillJoinsForSearchAndDiff() {
        let node = QuoteNode(plainText: "a\nb")
        XCTAssertEqual(node.paragraphs, ["a", "b"])
        XCTAssertEqual(node.plainText, "a b")
    }
}
