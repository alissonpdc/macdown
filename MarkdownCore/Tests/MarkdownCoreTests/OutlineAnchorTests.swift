import XCTest
@testable import MarkdownCore

// R3.7 TOC / R3.8 âncoras — consistência entre DocumentOutline e ids do HTML
final class OutlineAnchorTests: XCTestCase {
    let parser = MarkdownParser()

    func testOutlineExtractsLevelsInOrder() {
        let doc = parser.parse("# Um\n\n## Dois\n\n### Três")
        let outline = DocumentOutline(doc)
        XCTAssertEqual(outline.entries.map(\.level), [1, 2, 3])
        XCTAssertEqual(outline.entries.map(\.title), ["Um", "Dois", "Três"])
    }

    func testSlugDeduplicatesThreeOccurrences() {
        let doc = parser.parse("# Uso\n\n## Uso\n\n### Uso")
        let outline = DocumentOutline(doc)
        XCTAssertEqual(outline.entries.map(\.slug), ["uso", "uso-1", "uso-2"])
    }

    func testDistinctTitlesAreNotAffectedByDeduplication() {
        let doc = parser.parse("# Uso\n\n## Instalação")
        let outline = DocumentOutline(doc)
        XCTAssertEqual(outline.entries.map(\.slug), ["uso", "instalação"])
    }

    func testConverterIdsMatchDocumentOutlineSlugs() {
        let markdown = "# Intro\n\ntexto\n\n## Instalação\n\nmais texto"
        let doc = parser.parse(markdown)
        let html = MarkdownHTMLConverter().convert(doc)
        for entry in DocumentOutline(doc).entries {
            XCTAssertTrue(html.contains("id=\"\(entry.slug)\""),
                          "HTML should contain anchor id=\"\(entry.slug)\"")
        }
    }

    func testConverterAssignsSameUniqueIdsAsOutlineToDuplicates() {
        let markdown = "# Uso\n\na\n\n## Uso\n\nb\n\n# Outro"
        let doc = parser.parse(markdown)
        let html = MarkdownHTMLConverter().convert(doc)
        let slugs = DocumentOutline(doc).entries.map(\.slug)
        XCTAssertEqual(slugs, ["uso", "uso-1", "outro"])
        for slug in slugs {
            XCTAssertTrue(html.contains("id=\"\(slug)\""),
                          "Duplicate heading should get id \"\(slug)\" in HTML")
        }
    }

    // R3.8 — ícone hover `#` para copiar link da seção
    func testHeadingContainsHoverAnchorLink() {
        let doc = parser.parse("# Intro\n\ntexto")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains(##"<h1 id="intro"><a class="anchor" href="#intro""##),
                      "Heading should contain hover anchor link to its own slug")
        XCTAssertTrue(html.contains("copyAnchor"),
                      "Anchor click should trigger copy of the section link")
    }

    func testEachHeadingAnchorLinksToItsOwnSlug() {
        let markdown = "# Intro\n\na\n\n## Instalação\n\nb"
        let doc = parser.parse(markdown)
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains(##"<h1 id="intro"><a class="anchor" href="#intro""##))
        XCTAssertTrue(html.contains(##"<h2 id="instalação"><a class="anchor" href="#instalação""##))
    }

    func testAnchorCopyUsesBaseFileURLWhenProvided() {
        let doc = parser.parse("# Intro")
        let url = URL(fileURLWithPath: "/tmp/notes/guia.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: url)
        XCTAssertTrue(html.contains(#"var BASE_URL"#),
                      "Converter should inject the base file URL for anchor copying")
        XCTAssertTrue(html.contains(#"function copyAnchor"#),
                      "Footer script should define copyAnchor for section links")
    }
}
