import XCTest
@testable import MarkdownCore

// Feedback — arquivos exibidos com extensão na sidebar/abas.
final class DisplayNameTests: XCTestCase {
    func testDisplayNameKeepsExtension() {
        XCTAssertEqual(DisplayName.file(URL(fileURLWithPath: "/x/spec.md")), "spec.md")
        XCTAssertEqual(DisplayName.file(URL(fileURLWithPath: "/x/notas.markdown")), "notas.markdown")
    }

    // Título da aba continua limpo? Não — usuário pediu extensão também na aba.
    func testTabTitleKeepsExtension() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("a.md")
        try "# title".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try OpenDocument(url: url)
        // ReaderTab.title delega para DisplayName
        let tab = ReaderTab(document: doc)
        XCTAssertEqual(tab.title, "a.md")
    }
}
