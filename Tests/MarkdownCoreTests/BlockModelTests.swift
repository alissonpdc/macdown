import XCTest
import Markdown
@testable import MarkdownCore

// Fase 1 — AST navegável completa: nós restantes de bloco + inline
final class BlockModelTests: XCTestCase {
    let parser = MarkdownParser()

    func testParagraphBecomesParagraphNode() throws {
        let node = try XCTUnwrap(parser.parse("texto simples").blocks.first as? ParagraphNode)
        XCTAssertEqual(node.text, "texto simples")
    }

    func testFencedCodeBlockKeepsLanguageAndContent() throws {
        // R3.2 base
        let node = try XCTUnwrap(parser.parse("```bash\necho hi\n```").blocks.first as? CodeBlockNode)
        XCTAssertEqual(node.language, "bash")
        XCTAssertEqual(node.code, "echo hi\n")
    }

    func testOrderedListIsNotTaskList() throws {
        let node = try XCTUnwrap(parser.parse("1. um\n2. dois").blocks.first as? ListNode)
        XCTAssertEqual(node.items.map(\.text), ["um", "dois"])
        XCTAssertFalse(node.isTaskList)
    }

    func testPlainBulletList() throws {
        let node = try XCTUnwrap(parser.parse("- a\n- b").blocks.first as? ListNode)
        XCTAssertEqual(node.items.map(\.text), ["a", "b"])
        XCTAssertFalse(node.isTaskList)
    }

    func testBlockQuoteText() throws {
        let node = try XCTUnwrap(parser.parse("> citação").blocks.first as? QuoteNode)
        XCTAssertTrue(node.plainText.contains("citação"))
    }

    // TOC (R3.7) / âncoras (R3.8) — extração de outline
    func testOutlineExtractsHeadingsInOrderWithSlugs() {
        let doc = MarkdownParser().parse("# Intro\n\ntexto\n## Passo Um\n### Detalhe\n# Fim")
        let outline = DocumentOutline(doc)
        XCTAssertEqual(outline.entries.map(\.title), ["Intro", "Passo Um", "Detalhe", "Fim"])
        XCTAssertEqual(outline.entries.map(\.slug), ["intro", "passo-um", "detalhe", "fim"])
    }

    func testSlugDeduplicatesRepeatedTitles() {
        let doc = MarkdownParser().parse("# Uso\n\nx\n## Uso")
        let outline = DocumentOutline(doc)
        XCTAssertEqual(outline.entries.map(\.slug), ["uso", "uso-1"])
    }

    // Tasks agregadas (R3.13) e busca em texto plano
    func testTaskSummaryCountsCheckedAndTotal() {
        let doc = MarkdownParser().parse("- [x] a\n- [ ] b\n- [x] c")
        XCTAssertEqual(TaskSummary(doc).checked, 2)
        XCTAssertEqual(TaskSummary(doc).total, 3)
    }

    func testPlainTextOfDocumentJoinsBlocks() {
        let doc = MarkdownParser().parse("# Título\n\nparágrafo com palavras")
        let plain = PlainTextExtractor.extract(from: doc)
        XCTAssertTrue(plain.contains("Título"))
        XCTAssertTrue(plain.contains("parágrafo com palavras"))
    }
}
