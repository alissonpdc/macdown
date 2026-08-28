import SwiftUI

/// Paleta das três colunas (árvore, conteúdo, TOC) + cromo das abas.
/// Tons explícitos por aparência: no modo claro as colunas precisam de
/// contrastes visíveis entre si; no escuro seguem a família #0D1117 do
/// `--bg` do MarkdownHTMLConverter.
enum MDTheme {
    static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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

    static var contentBackground: Color { isDark ? contentDark : contentLight }
    static var sidebarBackground: Color { isDark ? sidebarDark : sidebarLight }
    static var tocBackground: Color { isDark ? tocDark : tocLight }
    static var chromeBackground: Color { isDark ? chromeDark : chromeLight }
}
