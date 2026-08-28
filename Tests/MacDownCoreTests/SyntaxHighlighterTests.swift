import XCTest
@testable import MacDownCore

// R3.2 — syntax highlighting: tokenização completa (comentários, strings,
// números, operadores, keywords, funções, tipos) com escape correto.
final class SyntaxHighlighterTests: XCTestCase {
    func highlight(_ code: String, _ language: String) -> String {
        SyntaxHighlighter.highlight(code, language: language)
    }

    // MARK: - Keywords

    func testSwiftKeywords() {
        let html = highlight("let x = 1", "swift")
        XCTAssertTrue(html.contains(#"<span class="kw">let</span>"#))
        XCTAssertFalse(html.contains(#"<span class="kw">x</span>"#))
    }

    func testUnknownLanguageReturnsEscapedPlainHTML() {
        let html = highlight("let <b>", "brainfuck")
        XCTAssertEqual(html, "let &lt;b&gt;")
    }

    // MARK: - Strings

    func testStringWithKeywordInsideIsNotDoubleHighlighted() {
        let html = highlight(#"print("let me in")"#, "python")
        XCTAssertTrue(html.contains(#"<span class="st">"let me in"</span>"#))
        XCTAssertFalse(html.contains("class=\"kw\""))
    }

    func testStringWithEscapedQuote() {
        let html = highlight(#"let s = "a\"b""#, "swift")
        XCTAssertTrue(html.contains(#"<span class="st">"a\"b"</span>"#))
    }

    // MARK: - Comments

    func testLineCommentSwallowsKeywords() {
        let html = highlight("// let x = 1", "swift")
        XCTAssertTrue(html.contains(#"<span class="cm">// let x = 1</span>"#))
        XCTAssertFalse(html.contains(#"class="kw""#))
    }

    func testBlockCommentSwift() {
        let html = highlight("/* let */ x", "swift")
        XCTAssertTrue(html.contains(#"<span class="cm">/* let */</span>"#))
        XCTAssertTrue(html.contains("x"))
    }

    func testHashCommentPython() {
        let html = highlight("# let\nx = 1", "python")
        XCTAssertTrue(html.contains(#"<span class="cm"># let</span>"#))
    }

    func testShebangBash() {
        let html = highlight("#!/bin/bash\necho hi", "bash")
        XCTAssertTrue(html.contains(#"<span class="cm">#!/bin/bash</span>"#))
        XCTAssertTrue(html.contains(#"<span class="kw">echo</span>"#))
    }

    func testCommentAfterStringIsStillComment() {
        let html = highlight(#"x = "http://a" # nota"#, "python")
        XCTAssertTrue(html.contains(#"<span class="cm"># nota</span>"#))
        XCTAssertTrue(html.contains(#"<span class="st">"http://a"</span>"#))
    }

    // MARK: - Numbers

    func testNumbers() {
        let html = highlight("x = 42 y = 3.14 z = 0x1F", "python")
        XCTAssertTrue(html.contains(#"<span class="num">42</span>"#))
        XCTAssertTrue(html.contains(#"<span class="num">3.14</span>"#))
        XCTAssertTrue(html.contains(#"<span class="num">0x1F</span>"#))
    }

    // MARK: - Operators

    func testOperators() {
        let html = highlight("a = b + 2", "swift")
        XCTAssertTrue(html.contains(#"<span class="op">=</span>"#))
        XCTAssertTrue(html.contains(#"<span class="op">+</span>"#))
    }

    // MARK: - Function calls & types

    func testFunctionCallIdentifier() {
        let html = highlight("foo(1)", "swift")
        XCTAssertTrue(html.contains(#"<span class="fn">foo</span>"#))
    }

    func testCapitalizedIdentifierAsType() {
        let html = highlight("let v = Foo()", "swift")
        XCTAssertTrue(html.contains(#"<span class="ty">Foo</span>"#))
    }

    func testPythonHasNoCapitalizedTypes() {
        let html = highlight("Foo = 1", "python")
        XCTAssertFalse(html.contains(#"class="ty""#))
    }

    // MARK: - Escaping

    func testEscapesHTMLInsideCode() {
        let html = highlight(#"<script>alert("x")</script>"#, "javascript")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;"))
        XCTAssertTrue(html.contains("&gt;"))
    }

    // MARK: - Language coverage

    func testGoRawString() {
        let html = highlight("s := `let x`", "go")
        XCTAssertTrue(html.contains(#"<span class="st">`let x`</span>"#))
    }

    func testPythonTripleQuotedString() {
        let html = highlight("x = 1\n\"\"\"\nlet doc\n\"\"\"\ny = 2", "python")
        XCTAssertTrue(html.contains(#"<span class="st">""""#))
    }

    func testJSON() {
        let html = highlight(#"{"k": null, "n": 1}"#, "json")
        XCTAssertTrue(html.contains(#"<span class="kw">null</span>"#))
        XCTAssertTrue(html.contains(#"<span class="num">1</span>"#))
    }

    func testYAMLKey() {
        let html = highlight("name: vale\nflag: true", "yaml")
        XCTAssertTrue(html.contains(#"<span class="fn">name</span>"#))
        XCTAssertTrue(html.contains(#"<span class="kw">true</span>"#))
    }

    func testSQLCaseInsensitiveKeywords() {
        let html = highlight("select * from users -- all", "sql")
        XCTAssertTrue(html.contains(#"<span class="kw">select</span>"#))
        XCTAssertTrue(html.contains(#"<span class="kw">from</span>"#))
        XCTAssertTrue(html.contains(#"<span class="cm">-- all</span>"#))
    }

    func testHTMLTags() {
        let html = highlight(#"<div class="a">x</div>"#, "html")
        XCTAssertTrue(html.contains(#"<span class="kw">&lt;div</span>"#))
        XCTAssertTrue(html.contains(#"<span class="st">"a"</span>"#))
        XCTAssertTrue(html.contains(#"<span class="fn">class</span>"#))
    }

    func testCSSPropertyAndComment() {
        let html = highlight("body { color: red; } /* c */", "css")
        XCTAssertTrue(html.contains(#"<span class="fn">color</span>"#))
        XCTAssertTrue(html.contains(#"<span class="cm">/* c */</span>"#))
    }

    func testBashVariables() {
        let html = highlight("echo $HOME", "bash")
        XCTAssertTrue(html.contains(#"<span class="fn">$HOME</span>"#))
    }

    func testLanguageAliases() {
        XCTAssertEqual(highlight("let", "js"), highlight("let", "javascript"))
        XCTAssertEqual(highlight("# x", "shell"), highlight("# x", "sh"))
        XCTAssertTrue(highlight("let", "ts").contains(#"class="kw""#))
        XCTAssertTrue(highlight("# x", "zsh").contains(#"class="cm""#))
        XCTAssertTrue(highlight("func", "golang").contains(#"class="kw""#))
        XCTAssertTrue(highlight("YES", "objc").contains(#"class="kw""#))
    }
}
