import XCTest
@testable import MacDown

@MainActor
final class DocumentStoreTests: XCTestCase {
    var store: DocumentStore!
    var tempFiles: [URL] = []

    override func setUp() async throws {
        store = DocumentStore()
    }

    override func tearDown() async throws {
        tempFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        tempFiles = []
    }

    private func makeTempFile(content: String = "# Test") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try content.write(to: url, atomically: true, encoding: .utf8)
        tempFiles.append(url)
        return url
    }

    func test_openAddsDocument() throws {
        let url = try makeTempFile()
        try store.open(url)
        XCTAssertEqual(store.documents.count, 1)
    }

    func test_openSetsTitle_toFilenameWithoutExtension() throws {
        let url = try makeTempFile()
        try store.open(url)
        XCTAssertEqual(store.documents[0].title, url.deletingPathExtension().lastPathComponent)
    }

    func test_openSetsContent() throws {
        let url = try makeTempFile(content: "# Hello World")
        try store.open(url)
        XCTAssertEqual(store.documents[0].content, "# Hello World")
    }

    func test_openSameFileTwice_doesNotDuplicate() throws {
        let url = try makeTempFile()
        try store.open(url)
        try store.open(url)
        XCTAssertEqual(store.documents.count, 1)
    }

    func test_openSecondFile_setsActiveIndexToLast() throws {
        let url1 = try makeTempFile()
        let url2 = try makeTempFile()
        try store.open(url1)
        try store.open(url2)
        XCTAssertEqual(store.activeIndex, 1)
    }

    func test_openInNewTab_duplicatesDocument() throws {
        let url = try makeTempFile()
        try store.open(url)
        try store.openInNewTab(url)
        XCTAssertEqual(store.documents.count, 2)
        XCTAssertEqual(store.activeIndex, 1)
    }

    func test_replaceActive_swapsContent() throws {
        let url1 = try makeTempFile(content: "# A")
        let url2 = try makeTempFile(content: "# B")
        try store.open(url1)
        try store.replaceActive(with: url2)
        XCTAssertEqual(store.documents.count, 1)
        XCTAssertEqual(store.documents[0].content, "# B")
    }

    func test_closeDocument_removesIt() throws {
        let url = try makeTempFile()
        try store.open(url)
        store.close(at: 0)
        XCTAssertTrue(store.documents.isEmpty)
    }

    func test_closeLastDocument_clampsActiveIndex() throws {
        let url1 = try makeTempFile()
        let url2 = try makeTempFile()
        try store.open(url1)
        try store.open(url2)
        store.close(at: 1)
        XCTAssertEqual(store.activeIndex, 0)
    }

    func test_activeDocument_returnsNilWhenEmpty() {
        XCTAssertNil(store.activeDocument)
    }

    func test_activeDocument_returnsCurrentDoc() throws {
        let url = try makeTempFile(content: "# Active")
        try store.open(url)
        XCTAssertEqual(store.activeDocument?.content, "# Active")
    }
}
