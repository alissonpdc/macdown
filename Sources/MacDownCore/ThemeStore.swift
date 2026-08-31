import Foundation
import SwiftUI

public enum AppearanceMode: String, CaseIterable, Equatable {
    case system, light, dark

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// R9.1 — seleção de aparência persistida em UserDefaults.
public final class ThemeStore: ObservableObject {
    static let key = "appearanceMode"

    private let defaults: UserDefaults

    @Published public private(set) var current: AppearanceMode

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        current = AppearanceMode(rawValue: defaults.string(forKey: Self.key) ?? "") ?? .system
    }

    public func set(_ mode: AppearanceMode) {
        current = mode
        defaults.set(mode.rawValue, forKey: Self.key)
    }
}
