import XCTest
@testable import MarkdownCore

// R3.12 — imagens locais relativas: conversor gera <img> com caminho
// resolvido contra a pasta do arquivo base.
final class ImageResolutionTests: XCTestCase {
    func testRelativeImageResolvesAgainstDocumentFolder() {
        let doc = MarkdownParser().parse("![logo](images/logo.png)")
        let base = URL(fileURLWithPath: "/tmp/docs/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<img src="file:///tmp/docs/images/logo.png" alt="logo">"#),
                      "got: \(html)")
    }

    func testImageWithoutBaseURLKeepsRelativePath() {
        let doc = MarkdownParser().parse("![logo](images/logo.png)")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains(#"<img src="images/logo.png" alt="logo">"#))
    }

    func testRemoteImageURLIsKept() {
        let doc = MarkdownParser().parse("![x](https://example.com/a.png)")
        let base = URL(fileURLWithPath: "/tmp/docs/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<img src="https://example.com/a.png" alt="x">"#))
    }

    func testImagePathWithSpacesIsPercentEncoded() {
        let doc = MarkdownParser().parse("![a](my image.png)")
        let base = URL(fileURLWithPath: "/tmp/docs/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<img src="file:///tmp/docs/my%20image.png" alt="a">"#))
    }

    func testAltTextIsEscaped() {
        let doc = MarkdownParser().parse("![<b>alt</b>](a.png)")
        let html = MarkdownHTMLConverter().convert(doc)
        XCTAssertTrue(html.contains(#"alt="&lt;b&gt;alt&lt;/b&gt;""#))
    }

    func testImageWithDotDotPath() {
        let doc = MarkdownParser().parse("![x](../assets/x.png)")
        let base = URL(fileURLWithPath: "/tmp/docs/sub/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<img src="file:///tmp/docs/assets/x.png" alt="x">"#))
    }

    func testRegularLinksAreNotAffectedByImageRule() {
        let doc = MarkdownParser().parse("[text](outro.md)")
        let base = URL(fileURLWithPath: "/tmp/docs/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<a href="outro.md">text</a>"#))
    }

    func testImageInsideListResolves() {
        let doc = MarkdownParser().parse("- ![logo](images/logo.png)")
        let base = URL(fileURLWithPath: "/tmp/docs/notes.md")
        let html = MarkdownHTMLConverter().convert(doc, baseFileURL: base)
        XCTAssertTrue(html.contains(#"<img src="file:///tmp/docs/images/logo.png""#))
    }
}
