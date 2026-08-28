import XCTest
@testable import MacDownCore

// R3.4 / R10.2 — Frontmatter YAML mínimo
final class FrontmatterTests: XCTestCase {
    func testDocumentWithoutFrontmatterHasNilMetadata() {
        let result = FrontmatterExtractor.extract(from: "# Olá\n\ntexto")
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.markdown, "# Olá\n\ntexto")
    }

    func testExtractsSimpleKeyValues() throws {
        let input = "---\ntitle: Minha Spec\nstatus: draft\n---\n# Conteúdo"
        let result = FrontmatterExtractor.extract(from: input)
        let fm = try XCTUnwrap(result.frontmatter)
        XCTAssertEqual(fm["title"], .string("Minha Spec"))
        XCTAssertEqual(fm["status"], .string("draft"))
        XCTAssertEqual(result.markdown, "# Conteúdo")
    }

    func testExtractsListValue() throws {
        let input = "---\ntags:\n  - a\n  - b\n---\nbody"
        let fm = try XCTUnwrap(FrontmatterExtractor.extract(from: input).frontmatter)
        XCTAssertEqual(fm["tags"], .list(["a", "b"]))
    }

    func testInvalidYAMLProducesError() throws {
        // R10.2
        let input = "---\nbroken: [unclosed\n---\nbody"
        let result = FrontmatterExtractor.extract(from: input)
        XCTAssertNotNil(try XCTUnwrap(result.error))
    }

    func testUnterminatedFrontmatterIsError() {
        // --- de abertura sem fechamento não é frontmatter válido
        let result = FrontmatterExtractor.extract(from: "---\ntitle: x\nsem fim")
        XCTAssertNotNil(result.error)
    }
}
