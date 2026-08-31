import XCTest
@testable import MacDownCore

final class MermaidRenderTests: XCTestCase {
    let converter = MarkdownHTMLConverter()

    // MARK: R3.3 — Mermaid block detection

    func testMermaidCodeBlockRendersAsDiagramContainer() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("mermaid-container"), "mermaid block should produce a container")
        XCTAssertTrue(html.contains("<div class=\"mermaid\">"), "should have a .mermaid div")
        XCTAssertTrue(html.contains("graph LR"), "mermaid code should be inside the container")
    }

    func testMermaidBlockNotRenderedAsCodeBlock() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertFalse(html.contains("<pre><code class=\"language-mermaid\">"),
                       "mermaid should NOT render as a normal code block")
    }

    func testMermaidBlockHasCopyButton() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("copyMermaidCode"), "mermaid block should have a copy button")
        XCTAssertTrue(html.contains("MERMAID"), "language label should show MERMAID")
    }

    func testMermaidBlockHasHiddenSourceForCopy() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph TD\n  X-->Y"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("mermaid-source"), "should have hidden source for copy")
        XCTAssertTrue(html.contains("display:none"), "source should be hidden")
    }

    func testMermaidBlockHasErrorPlaceholder() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("mermaid-error"), "should have error placeholder div")
    }

    func testMermaidBlockIsCaseInsensitive() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "MERMAID", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("mermaid-container"),
                       "MERMAID (uppercase) should also be detected")
    }

    func testRegularCodeBlockNotAffectedByMermaid() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "swift", code: "let x = 1"),
        ])
        let html = converter.convert(doc)
        XCTAssertFalse(html.contains("<div class=\"mermaid-container\">"),
                       "swift code block should not produce a mermaid-container div element")
        XCTAssertTrue(html.contains("language-swift"), "swift block should keep normal code rendering")
    }

    func testMermaidScriptTagInjectedWhenProvided() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc, mermaidScriptTag: "<script src=\"mermaid.min.js\"></script>")
        XCTAssertTrue(html.contains("mermaid.min.js"), "mermaid script tag should be injected")
        XCTAssertTrue(html.contains("mermaidInitScript") || html.contains("mermaid.initialize"),
                       "mermaid init script should be present")
    }

    func testMermaidScriptTagNotInjectedWhenEmpty() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
        ])
        let html = converter.convert(doc, mermaidScriptTag: "")
        XCTAssertFalse(html.contains("mermaid.initialize"),
                       "mermaid init should NOT be present when script tag is empty")
    }

    func testMermaidCSSPresentInHeader() {
        let header = MarkdownHTMLConverter.htmlHeader()
        XCTAssertTrue(header.contains(".mermaid-container"), "CSS should style mermaid containers")
        XCTAssertTrue(header.contains(".mermaid-error"), "CSS should style mermaid errors")
    }

    func testMermaidCodeWithSpecialCharactersEscaped() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A[\"Hello & World\"]-->B"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("&amp;"), "ampersands in mermaid source should be escaped in the hidden source")
        XCTAssertTrue(html.contains("Hello & World"), "raw mermaid code should be preserved in the .mermaid div")
    }

    func testMixedMermaidAndRegularCodeBlocks() {
        let doc = CoreDocument(blocks: [
            CodeBlockNode(language: "swift", code: "let x = 1"),
            CodeBlockNode(language: "mermaid", code: "graph LR\n  A-->B"),
            CodeBlockNode(language: "python", code: "print('hi')"),
        ])
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("language-swift"), "swift block should remain")
        XCTAssertTrue(html.contains("mermaid-container"), "mermaid block should be a container")
        XCTAssertTrue(html.contains("language-python"), "python block should remain")
    }
}
