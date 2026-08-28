import XCTest
@testable import MarkdownCore

// R13.1/R13.2 — diff puro baseline→atual por blocos, com rounds cumulativos.
final class DiffEngineTests: XCTestCase {
    private func p(_ t: String) -> any BlockNode { ParagraphNode(text: t, rawMarkdown: t) }
    private func h(_ t: String) -> any BlockNode { HeadingNode(level: 2, inlineText: t) }

    private func doc(_ blocks: [any BlockNode]) -> CoreDocument {
        CoreDocument(blocks: blocks)
    }

    private var known: Set<String> { [] }

    func testUnchangedDocumentsProduceNoChanges() {
        let result = BlockDiffer.diff(baseline: doc([h("T"), p("a")]), updated: doc([h("T"), p("a")]))
        XCTAssertEqual(result.statuses, [.unchanged, .unchanged])
        XCTAssertEqual(result.changedCount, 0)
        XCTAssertEqual(result.removedCount, 0)
    }

    func testAppendedBlockIsStrong() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a")]),
            updated: doc([p("a"), p("b novo")])
        )
        XCTAssertEqual(result.statuses, [.unchanged, .strong])
        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(result.removedCount, 0)
    }

    func testRewrittenBlockIsStrong() {
        let result = BlockDiffer.diff(baseline: doc([p("antes")]), updated: doc([p("depois")]))
        XCTAssertEqual(result.statuses, [.strong])
        XCTAssertEqual(result.removedCount, 1) // o bloco antigo foi substituído
    }

    func testRemovedBaselineBlocksAreCounted() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c")]),
            updated: doc([p("a")])
        )
        XCTAssertEqual(result.statuses, [.unchanged])
        XCTAssertEqual(result.removedCount, 2)
    }

    func testMixedEditCountsAdditionsAndRemovals() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c")]),
            updated: doc([p("a"), p("x"), p("y"), p("z")])
        )
        // x,y,z sem correspondência exata: +3; b,c não sobreviveram: −2
        XCTAssertEqual(result.statuses, [.unchanged, .strong, .strong, .strong])
        XCTAssertEqual(result.changedCount, 3)
        XCTAssertEqual(result.removedCount, 2)
    }

    func testRemovalsInMiddleAreCounted() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c")]),
            updated: doc([p("a"), p("c")])
        )
        XCTAssertEqual(result.statuses, [.unchanged, .unchanged])
        XCTAssertEqual(result.removedCount, 1)
    }

    // MARK: R13.1 — remoções reportadas para renderização

    func testRemovedMiddleBlockIsReportedBetweenNeighbors() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c")]),
            updated: doc([p("a"), p("c")])
        )
        XCTAssertEqual(result.removals.count, 1)
        XCTAssertEqual(result.removals[0].insertAt, 1)
        XCTAssertEqual(result.removals[0].texts, ["b"])
    }

    func testRemovedTailIsReportedAtEnd() {
        let result = BlockDiffer.diff(baseline: doc([p("a"), p("b")]), updated: doc([p("a")]))
        XCTAssertEqual(result.removals, [.init(insertAt: 1, texts: ["b"])])
    }

    func testRemovedHeadIsReportedAtStart() {
        let result = BlockDiffer.diff(baseline: doc([p("a"), p("b")]), updated: doc([p("b")]))
        XCTAssertEqual(result.removals, [.init(insertAt: 0, texts: ["a"])])
    }

    func testConsecutiveRemovedBlocksAreGrouped() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c"), p("d")]),
            updated: doc([p("a"), p("d")])
        )
        XCTAssertEqual(result.removals, [.init(insertAt: 1, texts: ["b", "c"])])
    }

    func testNoRemovalsWhenNothingDisappears() {
        let result = BlockDiffer.diff(baseline: doc([p("a")]), updated: doc([p("a"), p("x")]))
        XCTAssertTrue(result.removals.isEmpty)
    }

    func testPlainTextOfBlockKinds() {
        XCTAssertEqual(BlockDiffer.plainText(of: h("Título")), "Título")
        XCTAssertEqual(BlockDiffer.plainText(of: p("texto")), "texto")
        XCTAssertEqual(BlockDiffer.plainText(of: ListNode(items: [.init(text: "um"), .init(text: "dois")], isTaskList: false)),
                       "- um\n- dois")
        let task = TaskListItemsNode(items: [.init(isChecked: true, text: "feito"),
                                             .init(isChecked: false, text: "falta")])
        XCTAssertEqual(BlockDiffer.plainText(of: task), "[x] feito\n[ ] falta")
    }

    // R13.2 — mudanças já presentes em rounds anteriores ficam fracas.
    func testKnownChangeIsWeak() {
        let midSig = BlockDiffer.signature(of: p("conteúdo do round 1"))
        let result = BlockDiffer.diff(
            baseline: doc([p("original")]),
            updated: doc([p("conteúdo do round 1")]),
            knownChanges: [midSig]
        )
        XCTAssertEqual(result.statuses, [.weak])
    }

    func testNewAndPersistingChangesMixStrongAndWeak() {
        let persisting = BlockDiffer.signature(of: p("mudança antiga"))
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b")]),
            updated: doc([p("mudança antiga"), p("nova!")]),
            knownChanges: [persisting]
        )
        XCTAssertEqual(result.statuses, [.weak, .strong])
    }

    // R13.1 — resumo textual do indicador.
    func testSummaryFormat() {
        let result = BlockDiffer.diff(
            baseline: doc([p("a"), p("b"), p("c")]),
            updated: doc([p("a"), p("x"), p("y"), p("z")])
        )
        XCTAssertTrue(result.summary.hasSuffix("+3 −2"))
        XCTAssertTrue(result.summary.hasPrefix("Atualizado"))
    }

    func testSignatureIgnoresMarkdownDecorationButKeepsText() {
        let plain = BlockDiffer.signature(of: p("texto igual"))
        let decorated = BlockDiffer.signature(of: ParagraphNode(text: "texto igual", rawMarkdown: "**texto igual**"))
        XCTAssertEqual(plain, decorated)
        XCTAssertNotEqual(plain, BlockDiffer.signature(of: h("texto igual")))
    }
}
