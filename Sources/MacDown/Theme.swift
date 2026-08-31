import Combine
import SwiftUI

/// Paleta das três colunas (árvore, conteúdo, TOC) + cromo das abas.
/// Tons explícitos por aparência: no modo claro as colunas precisam de
/// contrastes visíveis entre si; no escuro seguem a família #0D1117 do
/// `--bg` do MarkdownHTMLConverter.
///
/// `MDThemeManager` é um `ObservableObject` que observa mudanças de aparência
/// via KVO em `NSApp.effectiveAppearance`. Quando `NSApp.appearance` é
/// alterado (light ↔ dark), o manager publica `objectWillChange`, forçando
/// todas as views que dependem dele a re-renderizarem com as cores corretas.
final class MDThemeManager: ObservableObject {
    @Published var isDark: Bool
    private var cancellable: AnyCancellable?

    init() {
        isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        cancellable = NSApp.publisher(for: \.effectiveAppearance).sink { [weak self] _ in
            guard let self else { return }
            let newDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark != newDark {
                isDark = newDark
            }
        }
    }

    // Conteúdo central — mesmo valor de `--bg` do conversor HTML.
    static let contentLight = Color.white
    static let contentDark = Color(red: 0.051, green: 0.067, blue: 0.090)

    // Sidebar (árvore) — tom mais fechado.
    static let sidebarLight = Color(red: 0.929, green: 0.933, blue: 0.945)
    static let sidebarDark = Color(red: 0.086, green: 0.106, blue: 0.133)

    // TOC — tom intermediário, distinto da sidebar e do conteúdo.
    static let tocLight = Color(red: 0.961, green: 0.965, blue: 0.976)
    static let tocDark = Color(red: 0.071, green: 0.086, blue: 0.110)

    // Cromo das abas — acompanha o tom da sidebar/TOC, não do conteúdo.
    static let chromeLight = Color(red: 0.949, green: 0.953, blue: 0.961)
    static let chromeDark = Color(red: 0.078, green: 0.094, blue: 0.118)

    var contentBackground: Color {
        isDark ? Self.contentDark : Self.contentLight
    }

    var sidebarBackground: Color {
        isDark ? Self.sidebarDark : Self.sidebarLight
    }

    var tocBackground: Color {
        isDark ? Self.tocDark : Self.tocLight
    }

    var chromeBackground: Color {
        isDark ? Self.chromeDark : Self.chromeLight
    }
}
