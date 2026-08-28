import XCTest
@testable import MacDownCore

final class LaunchArgsTests: XCTestCase {
    func testNoArgumentsReturnsNil() {
        XCTAssertNil(LaunchArgs.fileURL(from: ["MacDown"]))
    }

    func testRelativePathIsResolvedToAbsolute() throws {
        let url = try XCTUnwrap(LaunchArgs.fileURL(from: ["MacDown", "PRD.md"]))
        XCTAssertTrue(url.isFileURL)
        XCTAssertTrue(url.path.hasSuffix("PRD.md"))
        XCTAssertTrue(url.path.hasPrefix("/"))
    }

    func testFlagsAreSkipped() throws {
        let url = try XCTUnwrap(LaunchArgs.fileURL(from: ["MacDown", "-v", "doc.md"]))
        XCTAssertEqual(url.lastPathComponent, "doc.md")
    }

    func testFileSchemeURL() throws {
        let url = try XCTUnwrap(LaunchArgs.fileURL(from: ["MacDown", "file:///tmp/a.md"]))
        XCTAssertEqual(url.path, "/tmp/a.md")
    }
}
