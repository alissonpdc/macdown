import SwiftUI
import MarkdownCore

/// R3.7 — estado de UI persistido em UserDefaults (mesmo padrão de ReadingPrefs).
final class UIPrefs: ObservableObject {
    static let showTOCKey = "showTableOfContents"

    private let defaults: UserDefaults

    @Published var showTOC: Bool {
        didSet { defaults.set(showTOC, forKey: Self.showTOCKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showTOC = defaults.object(forKey: Self.showTOCKey) as? Bool ?? true
    }

    func toggleTOC() { showTOC.toggle() }
}

/// Requisição de navegação do TOC para o WebView. O token crescente garante que
/// clicar de novo no mesmo heading re-navegue.
struct TocNavigateRequest: Equatable {
    let token: Int
    let slug: String
}

/// R3.7 — painel TOC lateral direito: headings indentados por nível; clicar rola
/// até a seção correspondente no WKWebView via âncora gerada pelo conversor.
struct TocPanelView: View {
    let outline: DocumentOutline
    let onSelect: (_ slug: String) -> Void

    /// 1ª ocorrência fica sem indent extra (h1); cada nível abaixo desloca igual à sidebar.
    private let indentStep: CGFloat = 14
    @State private var hoveringSlug: String?

    var body: some View {
        Group {
            if outline.entries.isEmpty {
                Text("No headings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(outline.entries.enumerated()), id: \.offset) { _, entry in
                            row(entry)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minWidth: 180)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func row(_ entry: OutlineEntry) -> some View {
        Button {
            onSelect(entry.slug)
        } label: {
            Text(entry.title)
                .lineLimit(1)
                .font(entry.level <= 1 ? .system(size: 12, weight: .semibold) : .system(size: 12))
                .foregroundStyle(hoveringSlug == entry.slug ? Color.accentColor : .primary)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .padding(.leading, CGFloat(max(entry.level - 1, 0)) * indentStep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    hoveringSlug == entry.slug ? Color.primary.opacity(0.05) : .clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in hoveringSlug = hovering ? entry.slug : nil }
        .help("Go to \(entry.title)")
        .accessibilityLabel("Section \(entry.title), level \(entry.level)")
    }
}
