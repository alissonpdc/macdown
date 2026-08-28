import XCTest
@testable import MacDownCore

final class YAMLRenderBugTests: XCTestCase {
    func testComplexYAMLExtractedAndRenderedInOrder() {
        let input = """
        ---
        title: MacDown Spec
        version: "1.0"
        tags:
          - markdown
          - reader
          - macOS
        status: draft
        authors:
          - Alice
          - Bob
        ---

        # Introduction

        Body text.
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)

        let fm = doc.frontmatter
        let blocks = doc.document.blocks

        XCTAssertNotNil(fm)
        XCTAssertEqual(fm?.count, 5)
        XCTAssertEqual(fm?["title"], .string("MacDown Spec"))
        XCTAssertEqual(fm?["version"], .string("1.0"))
        XCTAssertEqual(fm?["status"], .string("draft"))
        XCTAssertEqual(fm?["tags"], .list(["markdown", "reader", "macOS"]))
        XCTAssertEqual(fm?["authors"], .list(["Alice", "Bob"]))

        // body has heading + paragraph
        let headings = blocks.compactMap { $0 as? HeadingNode }
        XCTAssertEqual(headings.first?.inlineText, "Introduction")
    }

    func testYAMLWithEmptyValuesNotCorruptingBody() {
        let input = """
        ---
        title: Test
        empty_key:
        tags:
          - a
        ---

        # Body

        Paragraph here.
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        let paragraphs = doc.document.blocks.compactMap { $0 as? ParagraphNode }
        XCTAssertFalse(paragraphs.contains { $0.text.contains("title:") }, "YAML should not leak into body")
        XCTAssertFalse(paragraphs.contains { $0.text.contains("tags:") }, "YAML should not leak into body")
    }

    func testYAMLWithColonsInValues() {
        let input = """
        ---
        time: "10:30:00"
        url: "https://example.com"
        ---

        # Body
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        XCTAssertEqual(doc.frontmatter?["time"], .string("10:30:00"))
        XCTAssertEqual(doc.frontmatter?["url"], .string("https://example.com"))
    }

    func testDocWithNoYAMLNotAffected() {
        let input = """
        # Hello

        Some text here.

        ## Section

        More text.
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        XCTAssertNil(doc.frontmatter)
        XCTAssertNil(doc.frontmatterError)
        let blocks = doc.document.blocks
        XCTAssertEqual(blocks.count, 4)
        let headings = blocks.compactMap { $0 as? HeadingNode }
        XCTAssertEqual(headings.map(\.inlineText), ["Hello", "Section"])
    }

    func testYAMLWithMultilineStringNotSupported() {
        let input = """
        ---
        title: Test
        description: |
          This is a
          multiline string
        ---

        # Body
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        XCTAssertNotNil(doc.frontmatterError)
        XCTAssertTrue(doc.document.blocks.contains { $0 is HeadingNode })
    }

    func testQuotedValuesAreStripped() {
        // R10.2 — aspas devem ser removidas dos valores YAML
        let input = """
        ---
        title: "Hello World"
        version: '2.0'
        ---

        # Body
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        XCTAssertEqual(doc.frontmatter?["title"], .string("Hello World"))
        XCTAssertEqual(doc.frontmatter?["version"], .string("2.0"))
    }

    func testBodyNotLeakingYAMLContent() {
        // Regression: YAML keys deve estar APENAS no card, nunca no body renderizado
        let input = """
        ---
        title: Test
        tags:
          - a
          - b
        status: draft
        ---

        # Heading

        Paragraph text.
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        let allText = doc.document.blocks.compactMap { block -> String? in
            switch block {
            case let h as HeadingNode: return h.inlineText
            case let p as ParagraphNode: return p.text
            default: return nil
            }
        }.joined(separator: " ")

        // Nenhum YAML key no body
        XCTAssertFalse(allText.contains("title:"), "YAML key 'title:' leaked into body")
        XCTAssertFalse(allText.contains("tags:"), "YAML key 'tags:' leaked into body")
        XCTAssertFalse(allText.contains("status:"), "YAML key 'status:' leaked into body")
        XCTAssertFalse(allText.contains("- a"), "YAML list item leaked into body")
    }

    func testFrontmatterPreservesInsertionOrder() {
        let input = """
        ---
        zebra: last
        alpha: first
        middle: mid
        ---

        # Body
        """
        let doc = OpenDocument(url: URL(fileURLWithPath: "/test.md"), rawText: input)
        let fm = try! XCTUnwrap(doc.frontmatter)
        XCTAssertEqual(fm.orderedFields.map(\.key), ["zebra", "alpha", "middle"])
    }
}
