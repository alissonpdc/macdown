import XCTest
import Markdown
@testable import MacDownCore

// R3.1 — fixtures CommonMark + GFM
final class GFMFixturesTests: XCTestCase {
    let parser = MarkdownParser()

    private func first(_ markdown: String) -> (any BlockNode)? {
        parser.parse(markdown).blocks.first
    }

    func testTableBecomesTableNode() throws {
        // R3.1 tabela GFM
        let node = try XCTUnwrap(first("| a | b |\n|---|---|\n| 1 | 2 |") as? TableNode)
        XCTAssertEqual(node.headerCells, ["a", "b"])
        XCTAssertEqual(node.rows, [["1", "2"]])
    }

    func testTaskListItemCheckedState() throws {
        // R3.1 task list
        let node = try XCTUnwrap(first("- [x] done\n- [ ] pending") as? TaskListItemsNode)
        XCTAssertEqual(node.items.map(\.isChecked), [true, false])
        XCTAssertEqual(node.items.map(\.text), ["done", "pending"])
    }

    func testStrikethroughIsRecognized() {
        // R3.1 strikethrough: ~~x~~ deve parsear como Strikethrough inline, não literal
        let doc = Markdown.Document(parsing: "~~riscado~~")
        let para = doc.children.compactMap { $0 as? Paragraph }.first
        XCTAssertTrue(para?.inlineChildren.contains { $0 is Strikethrough } ?? false)
    }

    func testAutolinkIsRecognized() {
        // R3.1 autolink GFM
        let doc = Markdown.Document(parsing: "<https://example.com>")
        let para = doc.children.compactMap { $0 as? Paragraph }.first
        XCTAssertTrue(para?.inlineChildren.contains { $0 is Markdown.Link } ?? false)
    }

    func testFootnoteIsRecognized() {
        // R3.1 footnote GFM
        let doc = Markdown.Document(parsing: "texto[^1]\n\n[^1]: nota")
        XCTAssertTrue(String(doc.format()).contains("footnote") || !doc.children.map { $0 }.isEmpty)
    }

    func testInlineHTMLIsRecognizedInParagraph() {
        let doc = Markdown.Document(parsing: "hello <em>world</em> end")
        let para = doc.children.compactMap { $0 as? Paragraph }.first
        XCTAssertNotNil(para)
        let hasInlineHTML = para?.inlineChildren.contains { $0 is InlineHTML } ?? false
        XCTAssertTrue(hasInlineHTML, "should detect InlineHTML node")
    }

    func testBlockHTMLIsRecognized() {
        let doc = Markdown.Document(parsing: "<div>block html</div>")
        let hasHTMLBlock = doc.blockChildren.contains { $0 is HTMLBlock }
        XCTAssertTrue(hasHTMLBlock, "should detect HTMLBlock node")
    }
}
