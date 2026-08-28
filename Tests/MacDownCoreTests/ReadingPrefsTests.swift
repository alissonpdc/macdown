import XCTest
@testable import MacDownCore

final class ReadingPrefsTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let name = "test.readingprefs.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    func testDefaultValues() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        XCTAssertEqual(prefs.widthCh, ReadingPrefs.defaultWidth)
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.defaultFontSize)
    }

    func testWidthPersistence() {
        let defaults = freshDefaults()
        let prefs = ReadingPrefs(defaults: defaults)
        prefs.widthCh = 80
        let prefs2 = ReadingPrefs(defaults: defaults)
        XCTAssertEqual(prefs2.widthCh, 80)
    }

    func testFontSizePersistence() {
        let defaults = freshDefaults()
        let prefs = ReadingPrefs(defaults: defaults)
        prefs.fontSize = 20
        let prefs2 = ReadingPrefs(defaults: defaults)
        XCTAssertEqual(prefs2.fontSize, 20)
    }

    func testIncreaseWidth() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.increaseWidth()
        XCTAssertEqual(prefs.widthCh, ReadingPrefs.defaultWidth + 10)
    }

    func testDecreaseWidth() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.decreaseWidth()
        XCTAssertEqual(prefs.widthCh, ReadingPrefs.defaultWidth - 10)
    }

    func testMethodClampsWidth() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.widthCh = ReadingPrefs.maxWidth - 5
        prefs.increaseWidth()
        XCTAssertEqual(prefs.widthCh, ReadingPrefs.maxWidth)
        prefs.widthCh = ReadingPrefs.minWidth + 5
        prefs.decreaseWidth()
        XCTAssertEqual(prefs.widthCh, ReadingPrefs.minWidth)
    }

    func testZoomIn() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.zoomIn()
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.defaultFontSize + ReadingPrefs.stepFontSize)
    }

    func testZoomOut() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.zoomOut()
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.defaultFontSize - ReadingPrefs.stepFontSize)
    }

    func testResetZoom() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.zoomIn()
        prefs.zoomIn()
        prefs.resetZoom()
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.defaultFontSize)
    }

    func testFontSizeClampsMinMax() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        for _ in 0..<20 { prefs.zoomIn() }
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.maxFontSize)
        for _ in 0..<20 { prefs.zoomOut() }
        XCTAssertEqual(prefs.fontSize, ReadingPrefs.minFontSize)
    }
}
