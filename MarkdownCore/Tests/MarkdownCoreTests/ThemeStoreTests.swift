import XCTest
@testable import MarkdownCore

// R9.1 — Claro, Escuro, Sistema; persistido entre sessões
final class ThemeStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultThemeIsSystem() {
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .system)
    }

    func testSetDarkPersistsAndReloads() {
        let store = ThemeStore(defaults: defaults)
        store.set(.dark)
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .dark)
    }

    func testSetLightPersists() {
        ThemeStore(defaults: defaults).set(.light)
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .light)
    }

    func testAllThreeModesExist() {
        XCTAssertEqual(Set(AppearanceMode.allCases), [.system, .light, .dark])
    }
}
