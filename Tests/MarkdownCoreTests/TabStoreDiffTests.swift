import XCTest
@testable import MarkdownCore

// R13.1–R13.3 — integração do diff com as abas: rounds cumulativos,
// confirmação de leitura e alternância de visão Nova/Diff.
final class TabStoreDiffTests: XCTestCase {
    private var root: URL!
    private var file: URL!
    private var store: TabStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        file = root.appendingPathComponent("doc.md")
        try "# T\npar um".write(to: file, atomically: true, encoding: .utf8)
        store = TabStore()
        try store.open(url: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func modify(_ text: String) throws {
        try text.write(to: file, atomically: true, encoding: .utf8)
        store.apply([WatchEvent(url: file, kind: .modified)])
    }

    func testFirstRoundProducesStrongHighlightAndSummary() throws {
        try modify("# T\npar um\n\npar dois novo")

        let tab = store.tabs[0]
        XCTAssertEqual(tab.diffResult?.changedCount, 1)
        XCTAssertEqual(tab.diffResult?.statuses, [.unchanged, .unchanged, .strong])
        XCTAssertTrue(tab.diffResult!.summary.hasSuffix("+1 −0"))
        XCTAssertTrue(tab.hasExternalUpdate)
    }

    // R13.2 — conteúdo já destacado em round anterior reaparece como fraco;
    // texto efetivamente novo continua forte.
    func testCumulativeRoundsMarkPersistingChangeAsWeak() throws {
        try modify("# T\npar um\n\npar dois v1")
        try modify("# T\npar um\n\npar dois v1\n") // mesma mudança, nova escrita

        XCTAssertEqual(store.tabs[0].diffResult?.statuses, [.unchanged, .unchanged, .weak])
    }

    func testNewChangeStaysStrongWhileOldOneIsWeak() throws {
        try modify("# T\npar um\n\npar dois v1")
        try modify("# T\npar um\n\npar dois v1\n\npar tres novo")

        XCTAssertEqual(store.tabs[0].diffResult?.statuses, [.unchanged, .unchanged, .weak, .strong])
    }

    // R13.2 — confirmar leitura promove baseline e limpa destaques.
    func testConfirmPromotesBaselineAndClearsHighlights() throws {
        try modify("# T\npar um\n\npar dois")
        let id = store.tabs[0].id

        store.confirmExternalUpdate(in: id)

        XCTAssertNil(store.tabs[0].diffResult)
        XCTAssertFalse(store.tabs[0].hasExternalUpdate)
        XCTAssertTrue(store.tabs[0].knownChanges.isEmpty)

        // próxima mudança difere apenas contra o novo baseline
        try modify("# T\npar um\n\npar dois\n\npar tres")
        XCTAssertEqual(store.tabs[0].diffResult?.statuses, [.unchanged, .unchanged, .unchanged, .strong])
    }

    // R13.3 — alternância de visão por aba.
    func testToggleDiffView() throws {
        let id = store.tabs[0].id

        XCTAssertFalse(store.tabs[0].showsDiff)
        store.toggleDiffView(in: id)
        XCTAssertTrue(store.tabs[0].showsDiff)
        store.toggleDiffView(in: id)
        XCTAssertFalse(store.tabs[0].showsDiff)
    }
}
