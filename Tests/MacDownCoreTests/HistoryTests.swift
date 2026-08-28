import XCTest
@testable import MacDownCore

// R6.3 — histórico de navegação por aba (estado puro, sem I/O)
final class HistoryTests: XCTestCase {
    func testEmptyHistoryCannotNavigate() {
        let h = History()
        XCTAssertFalse(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
    }

    func testPushAdvancesAndEnablesBack() {
        var h = History()
        h.push("/a.md")
        h.push("/b.md")
        XCTAssertTrue(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
        XCTAssertEqual(h.current, "/b.md")
    }

    func testBackThenForward() {
        var h = History()
        h.push("/a.md")
        h.push("/b.md")
        h.goBack()
        XCTAssertEqual(h.current, "/a.md")
        XCTAssertTrue(h.canGoForward)

        h.goForward()
        XCTAssertEqual(h.current, "/b.md")
        XCTAssertFalse(h.canGoForward)
    }

    func testNewVisitAfterBackTruncatesForward() {
        var h = History()
        h.push("/a.md")
        h.push("/b.md")
        h.goBack()          // está em a, forward tem b
        h.push("/c.md")     // nova visita descarta b
        XCTAssertNil(h.entries.first(where: { $0 == "/b.md" }))
        XCTAssertEqual(h.current, "/c.md")
        XCTAssertFalse(h.canGoForward)
    }
}
