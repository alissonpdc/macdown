import XCTest
@testable import MacDown

@MainActor
final class ThemeStateTests: XCTestCase {

    override func setUp() async throws {
        UserDefaults.standard.removeObject(forKey: "appTheme")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "appTheme")
    }

    func test_defaultTheme_isSystem() {
        let state = ThemeState()
        XCTAssertEqual(state.current, .system)
    }

    func test_setLight_persistsAcrossInstances() {
        let state = ThemeState()
        state.current = .light
        let state2 = ThemeState()
        XCTAssertEqual(state2.current, .light)
    }

    func test_setDark_persistsAcrossInstances() {
        let state = ThemeState()
        state.current = .dark
        let state2 = ThemeState()
        XCTAssertEqual(state2.current, .dark)
    }

    func test_invalidStoredValue_fallsBackToSystem() {
        UserDefaults.standard.set("invalid", forKey: "appTheme")
        let state = ThemeState()
        XCTAssertEqual(state.current, .system)
    }
}
