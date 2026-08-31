import Foundation
import SwiftUI

/// R3.11/R11.1 — preferências de leitura (largura + zoom) persistidas em UserDefaults.
public final class ReadingPrefs: ObservableObject {
    static let widthKey = "readingWidthCh"
    static let fontSizeKey = "readingFontSize"

    public static let defaultWidth: Double = 70
    public static let defaultFontSize: Double = 16

    public static let minWidth: Double = 50
    public static let maxWidth: Double = 120
    public static let minFontSize: Double = 12
    public static let maxFontSize: Double = 24
    public static let stepFontSize: Double = 1

    private let defaults: UserDefaults

    @Published public var widthCh: Double {
        didSet { defaults.set(widthCh, forKey: Self.widthKey) }
    }

    @Published public var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Self.fontSizeKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let w = defaults.object(forKey: Self.widthKey) != nil
            ? defaults.double(forKey: Self.widthKey) : Self.defaultWidth
        widthCh = max(Self.minWidth, min(Self.maxWidth, w))
        let f = defaults.object(forKey: Self.fontSizeKey) != nil
            ? defaults.double(forKey: Self.fontSizeKey) : Self.defaultFontSize
        fontSize = max(Self.minFontSize, min(Self.maxFontSize, f))
    }

    // MARK: - Width

    public func increaseWidth() {
        widthCh = min(Self.maxWidth, widthCh + 10)
    }

    public func decreaseWidth() {
        widthCh = max(Self.minWidth, widthCh - 10)
    }

    // MARK: - Font size (zoom)

    public func zoomIn() {
        fontSize = min(Self.maxFontSize, fontSize + Self.stepFontSize)
    }

    public func zoomOut() {
        fontSize = max(Self.minFontSize, fontSize - Self.stepFontSize)
    }

    public func resetZoom() {
        fontSize = Self.defaultFontSize
    }
}
