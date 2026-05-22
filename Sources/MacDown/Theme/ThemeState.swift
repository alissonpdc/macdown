import SwiftUI

enum AppTheme: String, CaseIterable, Hashable {
    case light, dark, system
}

@MainActor
final class ThemeState: ObservableObject {
    static let shared = ThemeState()

    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appTheme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? ""
        current = AppTheme(rawValue: saved) ?? .system
    }
}
