import XCTest
@testable import MarkdownCore

// Feedback — arquivos exibidos com extensão na sidebar/abas.
final class DisplayNameTests: XCTestCase {
    func testDisplayNameKeepsExtension() {
        XCTAssertEqual(DisplayName.file(URL(fileURLWithPath: "/x/spec.md")), "spec.md")
        XCTAssertEqual(DisplayName.file(URL(fileURLWithPath: "/x/notas.markdown")), "notas.markdown")
    }

    // Título da aba continua limpo? Não — usuário pediu extensão também na aba.
    func testTabTitleKeepsExtension() {
        let doc = try! OpenDocument(url: URL(fileURLWithPath: "/tmp/a.md"))
        // ReaderTab.title delega para DisplayName
        let tab = ReaderTab(document: doc)
        XCTAssertEqual(tab.title, "a.md")
    }
}
