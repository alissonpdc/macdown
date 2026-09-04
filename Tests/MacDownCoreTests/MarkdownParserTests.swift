import XCTest
@testable import MacDownCore

final class MarkdownParserTests: XCTestCase {
    // R3.1 — heading vira nó de árvore com nível e texto
    func testParsesHeading() throws {
        let doc = MarkdownParser().parse("## Requisitos")
        let heading = try XCTUnwrap(doc.blocks.first as? HeadingNode)
        XCTAssertEqual(heading.level, 2)
        XCTAssertEqual(heading.inlineText, "Requisitos")
    }

    func testEmptyDocumentHasNoBlocks() {
        XCTAssertTrue(MarkdownParser().parse("").blocks.isEmpty)
    }

    func testParsesHTMLBlock() throws {
        let doc = MarkdownParser().parse("<div class=\"custom\">Hello</div>")
        let html = try XCTUnwrap(doc.blocks.first as? HTMLBlockNode)
        XCTAssertTrue(html.rawHTML.contains("<div"))
        XCTAssertTrue(html.rawHTML.contains("Hello"))
    }

    func testParsesInlineHTMLInParagraph() throws {
        let doc = MarkdownParser().parse("hello <em>world</em> end")
        let para = try XCTUnwrap(doc.blocks.first as? ParagraphNode)
        XCTAssertTrue(para.rawMarkdown.contains("<em>"))
        XCTAssertTrue(para.rawMarkdown.contains("</em>"))
    }

    func testParsesAdmonitionNote() throws {
        let doc = MarkdownParser().parse("> [!NOTE]\n> Informational note")
        print("blocks: \(doc.blocks.map { type(of: $0) })")
        for block in doc.blocks {
            print("  block: \(type(of: block))")
        }
        let admonition = doc.blocks.first as? AdmonitionNode
        XCTAssertNotNil(admonition, "Expected AdmonitionNode but got \(type(of: doc.blocks.first!)): \(doc.blocks.first!)")
        XCTAssertEqual(admonition?.type, "note")
        XCTAssertEqual(admonition?.body, "Informational note")
    }

    func testParsesAdmonitionWarning() throws {
        let doc = MarkdownParser().parse("> [!WARNING]\n> Be careful!")
        let admonition = try XCTUnwrap(doc.blocks.first as? AdmonitionNode)
        XCTAssertEqual(admonition.type, "warning")
        XCTAssertEqual(admonition.body, "Be careful!")
    }

    func testParsesAdmonitionWithMultilineBody() throws {
        let doc = MarkdownParser().parse("> [!TIP]\n> First line\n> Second line")
        let admonition = try XCTUnwrap(doc.blocks.first as? AdmonitionNode)
        XCTAssertEqual(admonition.type, "tip")
        XCTAssertTrue(admonition.body.contains("First line"))
        XCTAssertTrue(admonition.body.contains("Second line"))
    }

    func testRegularBlockQuoteIsNotAdmonition() throws {
        let doc = MarkdownParser().parse("> Just a quote")
        let quote = try XCTUnwrap(doc.blocks.first as? QuoteNode)
        XCTAssertEqual(quote.paragraphs, ["Just a quote"])
    }

    func testParsesAdmonitionCaution() throws {
        let doc = MarkdownParser().parse("> [!CAUTION]\n> Danger zone")
        let admonition = try XCTUnwrap(doc.blocks.first as? AdmonitionNode)
        XCTAssertEqual(admonition.type, "caution")
    }

    func testParsesAdmonitionImportant() throws {
        let doc = MarkdownParser().parse("> [!IMPORTANT]\n> Pay attention")
        let admonition = try XCTUnwrap(doc.blocks.first as? AdmonitionNode)
        XCTAssertEqual(admonition.type, "important")
    }
}
