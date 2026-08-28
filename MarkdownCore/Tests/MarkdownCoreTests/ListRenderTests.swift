import XCTest
@testable import MarkdownCore

// Renderização de listas: ordered/unordered + aninhamento preservado
final class ListRenderTests: XCTestCase {
    let parser = MarkdownParser()

    func testOrderedListRendersOL() {
        let doc = parser.parse("1. um\n2. dois")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<ol>\n  <li>um</li>\n  <li>dois</li>\n</ol>"),
                      "got: \(html)")
    }

    func testUnorderedListStillRendersUL() {
        let doc = parser.parse("- a\n- b")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<ul>\n  <li>a</li>\n  <li>b</li>\n</ul>"))
    }

    func testNestedListInsideOrderedItem() {
        let markdown = "1. Primeiro nível\n   - Sub-item com `código`\n   - Outro sub-item\n2. Segundo nível"
        let doc = parser.parse(markdown)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<li>Primeiro nível<ul>"),
                      "nested list should render inside the parent <li>: \(html)")
        XCTAssertTrue(html.contains("<li>Sub-item com <code>código</code></li>"))
        XCTAssertTrue(html.contains("<li>Segundo nível</li>"))
    }

    func testNestedListModelKeepsChildren() {
        let markdown = "- pai\n  - filho"
        let doc = parser.parse(markdown)
        let node = try! XCTUnwrap(doc.blocks.first as? ListNode)
        let nested = try! XCTUnwrap(node.items.first?.children.first)
        XCTAssertEqual(nested.items.map(\.text), ["filho"])
    }

    // R3.2/R3.1 — GFM strikethrough com til simples
    func testSingleTildeStrikethrough() {
        let doc = parser.parse("texto ~riscado~ fim")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<del>riscado</del>"), "got: \(html)")
    }

    func testDoubleTildeStrikethroughStillWorks() {
        let doc = parser.parse("texto ~~riscado~~ fim")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains("<del>riscado</del>"))
    }
}
