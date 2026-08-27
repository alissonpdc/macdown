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
/// suave até a seção ficar no topo da área de leitura.
///
/// Coluna redimensionável pelo divider. Performance do drag: a largura vive em
/// @State LOCAL deste view — o pai nunca re-renderiza durante o arrasto.
///
/// Crescimento grow-only dentro da SESSÃO: se um documento aberto exige mais
/// largura que a atual, expande; documentos com títulos menores NUNCA encolhem
/// a coluna. Nada é persistido: ao reiniciar o app, volta ao default (ideal).
struct TocPanelView: View {
    let outline: DocumentOutline
    let onSelect: (_ slug: String) -> Void
    /// Menor largura que exibe o título mais largo do documento atual sem quebra.
    let requiredWidth: CGFloat
    /// Largura inicial da sessão (largura ideal do primeiro documento aberto).
    let initialWidth: CGFloat

    static let minWidth: CGFloat = 150
    static let maxWidth: CGFloat = 420

    /// 1ª ocorrência fica sem indent extra (h1); cada nível abaixo desloca igual à sidebar.
    private let indentStep: CGFloat = 14
    private let rowHorizontalPadding: CGFloat = 4
    private let containerPadding: CGFloat = 8
    /// Respiro além do texto mais largo para que nada quebre de linha.
    private let breathingRoom: CGFloat = 16

    @State private var width: CGFloat
    @State private var dragBaseWidth: CGFloat?

    init(outline: DocumentOutline,
         onSelect: @escaping (_ slug: String) -> Void,
         requiredWidth: CGFloat,
         initialWidth: CGFloat) {
        self.outline = outline
        self.onSelect = onSelect
        self.requiredWidth = requiredWidth
        self.initialWidth = initialWidth
        _width = State(initialValue: Self.clamp(initialWidth))
    }

    static func clamp(_ value: CGFloat) -> CGFloat {
        max(minWidth, min(maxWidth, value))
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

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle
            Group {
                if outline.entries.isEmpty {
                    noHeadingsPlaceholder
                } else {
                    TocList(outline: outline,
                            indentStep: indentStep,
                            rowHorizontalPadding: rowHorizontalPadding,
                            onSelect: onSelect)
                }
            }
            // Constante única atualizada durante o drag; sem animação implícita.
            .frame(width: Self.clamp(width))
            .transaction { $0.animation = nil }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { growOnlyToFit() }
        .onChange(of: requiredWidth) { _, newRequired in
            growOnlyToFit(target: newRequired)
        }
    }

    // MARK: - Estados vazios

    private var noHeadingsPlaceholder: some View {
        HStack {
            Text("No headings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Grow-only (R3.7)

    /// Só CRESCER até caber o conteúdo; nunca encolhe. Válido apenas na sessão.
    private func growOnlyToFit(target: CGFloat? = nil) {
        let required = Self.clamp(target ?? requiredWidth)
        guard required > width else { return }
        width = required
    }

    // MARK: - Divider arrastável

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
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        width = Self.clamp((dragBaseWidth ?? width) - value.translation.width)
                    }
                }
                .onEnded { _ in
                    dragBaseWidth = nil
                }
        )
        .accessibilityLabel("Resize table of contents")
    }
}

// MARK: - Lista (isolada da largura: drag não re-renderiza as linhas)

/// Subview separada porque não depende de `width`: enquanto o usuário arrasta o
/// divider, apenas a constante do frame muda — este subtree é preservado pelo diff.
private struct TocList: View {
    let outline: DocumentOutline
    let indentStep: CGFloat
    let rowHorizontalPadding: CGFloat
    let onSelect: (_ slug: String) -> Void

    @State private var hoveringSlug: String?
    private let containerPadding: CGFloat = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(outline.entries.enumerated()), id: \.offset) { _, entry in
                    row(entry)
                }
            }
            .padding(containerPadding)
        }
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
