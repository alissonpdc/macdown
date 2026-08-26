import XCTest
@testable import MarkdownCore

final class MarkdownParserTests: XCTestCase {
    // R3.1 — heading vira nó de árvore com nível e texto
    func testParsesHeading() throws {
        let doc = MarkdownParser().parse("## Requisitos")
        let heading = try XCTUnwrap(doc.blocks.first as? HeadingNode)
        XCTAssertEqual(heading.level, 2)
        XCTAssertEqual(heading.inlineText, "Requisitos")
    }

    func testEmptyDocumentHasNoBlocks() {
        XCTAssertTrue(MarkdownParser().parse("").blocks.isEmpty)
    }
}
