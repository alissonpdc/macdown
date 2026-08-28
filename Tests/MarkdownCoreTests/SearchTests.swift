import XCTest
import MarkdownCore

final class SearchTests: XCTestCase {
    private func doc(_ blocks: [any BlockNode]) -> CoreDocument { CoreDocument(blocks: blocks) }

    func testFindSingleMatchReturnsOrdinalAndRange() {
        let d = doc([ParagraphNode(text: "The quick brown fox", rawMarkdown: "The quick brown fox")])
        let matches = SearchEngine.findMatches(in: d, query: "quick")
        XCTAssertEqual(matches.count, 1)
        let m = matches[0]
        XCTAssertEqual(m.blockIndex, 0)
        XCTAssertEqual(m.ordinal, 0)
        let text = SearchEngine.searchableText(of: d.blocks[0])
        let start = text.utf16.index(text.utf16.startIndex, offsetBy: m.range.lowerBound)
        let end = text.utf16.index(text.utf16.startIndex, offsetBy: m.range.upperBound)
        XCTAssertEqual(String(text[start..<end]), "quick")
    }

    func testFindCaseInsensitiveByDefault() {
        let d = doc([ParagraphNode(text: "Hello WORLD", rawMarkdown: "Hello WORLD")])
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "world").count, 1)
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "world",
                                                options: .caseSensitive).count, 0)
    }

    func testFindMultipleOccurrencesAcrossBlocks() {
        let d = doc([
            ParagraphNode(text: "cat cat", rawMarkdown: "cat cat"),
            HeadingNode(level: 1, inlineText: "cat header"),
        ])
        let matches = SearchEngine.findMatches(in: d, query: "cat")
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].blockIndex, 0)
        XCTAssertEqual(matches[1].blockIndex, 0)
        XCTAssertEqual(matches[2].blockIndex, 1)
        XCTAssertEqual(matches.map { $0.ordinal }, [0, 1, 2])
    }

    func testWholeWordExcludesSubstring() {
        let d = doc([ParagraphNode(text: "cat category scatter", rawMarkdown: "cat category scatter")])
        let matches = SearchEngine.findMatches(in: d, query: "cat", options: .wholeWord)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(SearchEngine.searchableText(of: d.blocks[0])[...]
                        .dropFirst(matches[0].range.lowerBound).prefix(3), "cat")
    }

    func testEmptyQueryReturnsNothing() {
        let d = doc([ParagraphNode(text: "anything", rawMarkdown: "anything")])
        XCTAssertTrue(SearchEngine.findMatches(in: d, query: "").isEmpty)
    }

    func testSnippetHasContextAroundMatch() {
        let text = String(repeating: "word ", count: 20) + "TARGET" + String(repeating: " word", count: 20)
        let d = doc([ParagraphNode(text: text, rawMarkdown: text)])
        let m = SearchEngine.findMatches(in: d, query: "TARGET")[0]
        XCTAssertTrue(m.snippet.contains("TARGET"))
        XCTAssertTrue(m.snippet.hasPrefix("word ") || m.snippet.count > "TARGET".count)
        XCTAssertEqual(m.snippetMatchStart >= 0, true)
        let sStart = m.snippet.utf16.index(m.snippet.utf16.startIndex, offsetBy: m.snippetMatchStart)
        let sEnd = m.snippet.utf16.index(sStart, offsetBy: "TARGET".utf16.count)
        XCTAssertEqual(String(m.snippet.utf16[sStart..<sEnd]), "TARGET")
    }

    func testSearchableTextOfCodeAndTable() {
        let code = CodeBlockNode(language: "swift", code: "let x = 1")
        XCTAssertEqual(SearchEngine.searchableText(of: code), "let x = 1")

        let table = TableNode(headerCells: ["A", "B"], rows: [["1", "2"]])
        let t = SearchEngine.searchableText(of: table)
        XCTAssertTrue(t.contains("A") && t.contains("B") && t.contains("1") && t.contains("2"))
    }

    func testFindInFilesReturnsOnlyMatching() {
        let a = (URL(fileURLWithPath: "/a.md"), doc([ParagraphNode(text: "match here", rawMarkdown: "match here")]))
        let b = (URL(fileURLWithPath: "/b.md"), doc([ParagraphNode(text: "nothing", rawMarkdown: "nothing")]))
        let results = SearchEngine.findInFiles([a, b], query: "match")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].url.path, "/a.md")
        XCTAssertEqual(results[0].count, 1)
    }

    // MARK: Busca por regex (R5.2)

    func testRegexPatternMatches() {
        let d = doc([ParagraphNode(text: "foo123 bar456 foo789", rawMarkdown: "x")])
        let matches = SearchEngine.findMatches(in: d, query: "foo\\d+", options: .regex)
        XCTAssertEqual(matches.count, 2)
        let text = SearchEngine.searchableText(of: d.blocks[0])
        for (i, expected) in ["foo123", "foo789"].enumerated() {
            let start = text.utf16.index(text.utf16.startIndex, offsetBy: matches[i].range.lowerBound)
            let end = text.utf16.index(start, offsetBy: matches[i].range.count)
            XCTAssertEqual(String(text[start..<end]), expected)
        }
    }

    func testRegexCaseInsensitiveByDefault() {
        let d = doc([ParagraphNode(text: "ABC abc", rawMarkdown: "x")])
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "abc", options: .regex).count, 2)
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "abc",
                                                options: [.regex, .caseSensitive]).count, 1)
    }

    func testRegexLiteralsAreTreatedAsPatterns() {
        let d = doc([ParagraphNode(text: "a.b axb", rawMarkdown: "x")])
        // sem .regex, "a.b" é literal e casa só com "a.b"; com .regex, "." casa qualquer char
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "a.b").count, 1)
        XCTAssertEqual(SearchEngine.findMatches(in: d, query: "a.b", options: .regex).count, 2)
    }

    func testInvalidRegexReturnsNoMatches() {
        let d = doc([ParagraphNode(text: "anything", rawMarkdown: "x")])
        XCTAssertTrue(SearchEngine.findMatches(in: d, query: "[unclosed", options: .regex).isEmpty)
    }

    func testRegexCombinesWithWholeWord() {
        let d = doc([ParagraphNode(text: "cat scatter catalog", rawMarkdown: "x")])
        let matches = SearchEngine.findMatches(in: d, query: "cat", options: [.regex, .wholeWord])
        XCTAssertEqual(matches.count, 1)
    }
}
