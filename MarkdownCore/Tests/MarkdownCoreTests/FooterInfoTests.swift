import XCTest
@testable import MarkdownCore

// R8.1 / R3.13 — Footer: breadcrumb, contagens e tasks agregadas.
final class FooterInfoTests: XCTestCase {

    func testBreadcrumbWithoutRootShowsFilename() {
        let url = URL(fileURLWithPath: "/Users/test/docs/README.md")
        let doc = OpenDocument(url: url, rawText: "# Hello")
        let footer = FooterInfo(document: doc)
        XCTAssertEqual(footer.breadcrumb, "README.md")
    }

    func testBreadcrumbWithRootShowsRelativePath() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let file = URL(fileURLWithPath: "/Users/test/project/docs/guide.md")
        let doc = OpenDocument(url: file, rawText: "# Guide")
        let footer = FooterInfo(document: doc, folderRoot: root)
        XCTAssertEqual(footer.breadcrumb, "docs/guide.md")
    }

    func testBreadcrumbRootIsSameAsFilePath() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let doc = OpenDocument(url: root, rawText: "# Root")
        let footer = FooterInfo(document: doc, folderRoot: root)
        XCTAssertEqual(footer.breadcrumb, "project")
    }

    func testBreadcrumbFileOutsideRootShowsFilename() {
        let root = URL(fileURLWithPath: "/Users/test/project")
        let file = URL(fileURLWithPath: "/Users/other/external.md")
        let doc = OpenDocument(url: file, rawText: "# External")
        let footer = FooterInfo(document: doc, folderRoot: root)
        XCTAssertEqual(footer.breadcrumb, "external.md")
    }

    func testWordCountAndCharacterCount() {
        let text = "# Title\n\nHello world"
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let doc = OpenDocument(url: url, rawText: text)
        let footer = FooterInfo(document: doc)
        XCTAssertEqual(footer.wordCount, 3)
        XCTAssertEqual(footer.characterCount, text.count)
    }

    func testTaskSummaryWhenNoTasks() {
        let doc = OpenDocument(url: URL(fileURLWithPath: "/tmp/t.md"), rawText: "# No tasks")
        let footer = FooterInfo(document: doc)
        XCTAssertNil(footer.taskSummary)
    }

    func testTaskSummaryWithMixedTasks() {
        let doc = OpenDocument(url: URL(fileURLWithPath: "/tmp/t.md"),
                               rawText: "- [x] done\n- [ ] pending\n- [x] also done")
        let footer = FooterInfo(document: doc)
        XCTAssertEqual(footer.taskSummary, "2/3 tasks")
    }
}
