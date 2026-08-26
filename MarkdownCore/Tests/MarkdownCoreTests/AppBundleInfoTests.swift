import XCTest
@testable import MarkdownCore

final class AppBundleInfoTests: XCTestCase {
    // R1.2 base — bundle declara a família markdown como documento suportado
    func testInfoPlistDeclaresMarkdownExtensions() {
        let plist = AppBundleInfo.infoPlist
        for ext in ["md", "markdown", "mdown", "mkd"] {
            XCTAssertTrue(plist.contains("<string>\(ext)</string>"), "faltou extensão \(ext)")
        }
    }

    func testInfoPlistIsWellFormedXML() throws {
        let plist = AppBundleInfo.infoPlist
        // sanity: tags essenciais presentes e balanceadas
        XCTAssertTrue(plist.hasPrefix("<?xml"))
        XCTAssertEqual(plist.components(separatedBy: "<dict>").count - 1,
                       plist.components(separatedBy: "</dict>").count - 1)
    }
}
