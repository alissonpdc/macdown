import XCTest
@testable import MarkdownCore

final class MarkdownHTMLConverterTests: XCTestCase {
    let converter = MarkdownHTMLConverter()

    func testHeadingConversion() {
        let doc = CoreDocument(blocks: [
            HeadingNode(level: 1, inlineText: "Title"),
            HeadingNode(level: 2, inlineText: "Subtitle"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<h1 id=\"title\">Title</h1>"))
        XCTAssertTrue(html.contains("<h2 id=\"subtitle\">Subtitle</h2>"))
    }

    func testParagraphWithInlineFormatting() {
        let doc = CoreDocument(blocks: [
            ParagraphNode(text: "Hello world", rawMarkdown: "Hello **world**"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<strong>world</strong>"))
    }

    func testCodeBlock() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "swift", code: "let x = 1"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<code class=\"language-swift\">"))
        XCTAssertTrue(html.contains("Copiar"))
        XCTAssertTrue(html.contains("code-block"))
        XCTAssertTrue(html.contains("code-header"))
    }

    // R3.10 — fold de código >30 linhas
    func testLineCountCountsNewlineSeparatedLinesIgnoringTrailingNewline() {
        XCTAssertEqual(MarkdownHTMLConverter.lineCount(of: "let x = 1"), 1)
        XCTAssertEqual(MarkdownHTMLConverter.lineCount(of: "a\nb\nc"), 3)
        XCTAssertEqual(MarkdownHTMLConverter.lineCount(of: "a\nb\nc\n"), 3)
        XCTAssertEqual(MarkdownHTMLConverter.lineCount(of: ""), 1)
    }

    func testCodeBlockFoldedWhenMoreThan30Lines() {
        let code = (1...31).map { "line \($0)" }.joined(separator: "\n")
        let doc = CoreDocument(blocks: [CodeBlockNode(language: "swift", code: code)])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("code-block folded"), "31-line block should be folded")
        XCTAssertTrue(html.contains("fold-btn"), "fold button should be present")
        XCTAssertTrue(html.contains("31 linhas"), "fold button should show line count")
    }

    func testCodeBlockNotFoldedAt30LinesOrLess() {
        let code = (1...30).map { "line \($0)" }.joined(separator: "\n")
        let doc = CoreDocument(blocks: [CodeBlockNode(language: "swift", code: code)])
        let html = converter.convert(doc)
        XCTAssertFalse(html.contains("code-block folded"), "30-line block should not be folded")
        XCTAssertFalse(html.contains("<button class=\"fold-btn\""), "fold button should be absent")
    }

    func testFoldCSSAndToggleScriptPresent() {
        let html = converter.convert(CoreDocument(blocks: []))
        XCTAssertTrue(html.contains(".code-block.folded pre"))
        XCTAssertTrue(html.contains("function toggleFold"))
    }

    func testBlockquote() {
        let doc = CoreDocument(blocks: [
            QuoteNode(plainText: "Important quote"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("Important quote"))
    }

    func testTable() {
        let doc = CoreDocument(blocks: [
            TableNode(headerCells: ["A", "B"], rows: [["1", "2"]]),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>A</th>"))
        XCTAssertTrue(html.contains("<td>1</td>"))
    }

    func testTaskList() {
        let doc = CoreDocument(blocks: [
            TaskListItemsNode(items: [
                TaskItem(isChecked: true, text: "Done"),
                TaskItem(isChecked: false, text: "Todo"),
            ]),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("task-list"))
        XCTAssertTrue(html.contains("checked"))
        XCTAssertTrue(html.contains("Done"))
    }

    func testHorizontalRule() {
        let doc = CoreDocument(blocks: [
            HorizontalRuleNode(),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<hr>"))
    }

    func testFrontmatterCard() {
        let fm = Frontmatter([
            (key: "title", value: .string("My Doc")),
            (key: "tags", value: .list(["swift", "ui"])),
        ])
        let html = MarkdownHTMLConverter.frontmatterCardHTML(fm)
        XCTAssertTrue(html.contains("fm-key"))
        XCTAssertTrue(html.contains("title"))
        XCTAssertTrue(html.contains("My Doc"))
        XCTAssertTrue(html.contains("swift, ui"))
    }

    func testFrontmatterError() {
        let doc = CoreDocument(blocks: [])
        let html = converter.convert(doc, frontmatterError: "YAML malformado")
        XCTAssertTrue(html.contains("frontmatter-error"))
        XCTAssertTrue(html.contains("YAML malformado"))
    }

    func testEscapeHTML() {
        let escaped = MarkdownHTMLConverter.escapeHTML("<script>alert('xss')</script>")
        XCTAssertFalse(escaped.contains("<script>"))
        XCTAssertTrue(escaped.contains("&lt;script&gt;"))
    }

    func testInlineMarkdownBold() {
        let html = MarkdownHTMLConverter.inlineMarkdown("**bold text**")
        XCTAssertTrue(html.contains("<strong>bold text</strong>"))
    }

    func testInlineMarkdownItalic() {
        let html = MarkdownHTMLConverter.inlineMarkdown("*italic text*")
        XCTAssertTrue(html.contains("<em>italic text</em>"))
    }

    func testInlineMarkdownCode() {
        let html = MarkdownHTMLConverter.inlineMarkdown("`code`")
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    func testInlineMarkdownLink() {
        let html = MarkdownHTMLConverter.inlineMarkdown("[link](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">link</a>"))
    }

    func testInlineMarkdownStrikethrough() {
        let html = MarkdownHTMLConverter.inlineMarkdown("~~deleted~~")
        XCTAssertTrue(html.contains("<del>deleted</del>"))
    }

    func testFullDocumentConversion() {
        let doc = CoreDocument(blocks: [
            HeadingNode(level: 1, inlineText: "Hello"),
            ParagraphNode(text: "A paragraph", rawMarkdown: "A **bold** paragraph"),
            CodeBlockNode(language: "python", code: "print('hi')"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<h1"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("python"))
    }

    func testHTMLHeaderContainsCSS() {
        let header = MarkdownHTMLConverter.htmlHeader()
        XCTAssertTrue(header.contains("--bg:"))
        XCTAssertTrue(header.contains("prefers-color-scheme: dark"))
    }

    func testHTMLFooterContainsScript() {
        XCTAssertTrue(MarkdownHTMLConverter.htmlFooter.contains("copyCode"))
    }
}
