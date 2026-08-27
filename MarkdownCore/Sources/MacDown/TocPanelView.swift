import SwiftUI
import AppKit
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

/// R3.7 — painel TOC lateral direito: headings indentados por nível; 1 clique rola
/// suave até a seção ficar no topo da área de leitura. Coluna redimensionável pelo
/// divider (DragGesture), com largura ideal inicial medida a partir dos títulos.
struct TocPanelView: View {
    let outline: DocumentOutline
    let onSelect: (_ slug: String) -> Void
    /// Largura atual da coluna (controlada do lado de fora p/ persistência).
    @Binding var width: CGFloat

    static let minWidth: CGFloat = 150
    static let maxWidth: CGFloat = 420

    /// 1ª ocorrência fica sem indent extra (h1); cada nível abaixo desloca igual à sidebar.
    private let indentStep: CGFloat = 14
    private let rowHorizontalPadding: CGFloat = 4
    private let containerPadding: CGFloat = 8
    /// Respiro além do texto mais largo para que nada quebre de linha.
    private let breathingRoom: CGFloat = 16

    @State private var hoveringSlug: String?
    @State private var dragBaseWidth: CGFloat?

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle
            panelContent
                .frame(width: max(Self.minWidth, min(Self.maxWidth, width)))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private var panelContent: some View {
        if outline.entries.isEmpty {
            Text("No headings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(outline.entries.enumerated()), id: \.offset) { _, entry in
                        row(entry)
                    }
                }
                .padding(containerPadding)
            }
        }
    }

    /// Divider arrastável (replica o comportamento nativo do split da sidebar).
    private var resizeHandle: some View {
        ZStack {
            Color(nsColor: .separatorColor).frame(width: 1)
            Rectangle()
                .fill(.clear)
                .frame(width: 8)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragBaseWidth == nil { dragBaseWidth = width }
                    width = max(Self.minWidth,
                                min(Self.maxWidth, (dragBaseWidth ?? width) - value.translation.width))
                }
                .onEnded { _ in dragBaseWidth = nil }
        )
        .accessibilityLabel("Resize table of contents")
    }

    // MARK: - Largura ideal

    /// Menor largura que exibe o título mais largo sem quebra de linha:
    /// mede cada título com a fonte real, soma indentação por nível e paddings.
    static func idealWidth(for outline: DocumentOutline) -> CGFloat {
        guard !outline.entries.isEmpty else { return minWidth }
        var widest: CGFloat = 0
        for entry in outline.entries {
            let font = NSFont.systemFont(ofSize: 12,
                                         weight: entry.level <= 1 ? .semibold : .regular)
            let textWidth = (entry.title as NSString).size(withAttributes: [.font: font]).width
            let indent = CGFloat(max(entry.level - 1, 0)) * 14
            widest = max(widest, indent + textWidth)
        }
        return min(maxWidth, max(minWidth, widest + 2 * 4 + 2 * 8 + 16))
    }

    // MARK: - Linhas

    private func row(_ entry: OutlineEntry) -> some View {
        Button {
            onSelect(entry.slug)
        } label: {
            Text(entry.title)
                .lineLimit(1)
                .font(entry.level <= 1 ? .system(size: 12, weight: .semibold) : .system(size: 12))
                .foregroundStyle(hoveringSlug == entry.slug ? Color.accentColor : .primary)
                .padding(.vertical, 2)
                .padding(.horizontal, rowHorizontalPadding)
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
