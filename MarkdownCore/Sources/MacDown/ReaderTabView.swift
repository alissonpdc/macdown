import SwiftUI
import MarkdownCore

/// Conteúdo de uma aba com renderização via WKWebView.
///
/// Layout em duas colunas: à esquerda a coluna de CONTEÚDO (abas, busca, banner
/// de update, render e rodapé de estatísticas); à direita, altura total, a
/// coluna TOC — que contém apenas o TOC.
struct ReaderTabView: View {
    let tabID: ReaderTab.ID
    @ObservedObject var store: TabStore
    @ObservedObject var readingPrefs: ReadingPrefs
    var onOpenLink: (URL) -> Void = { _ in }
    var folderRoot: URL?
    /// Abre o painel de seleção de arquivos (botão + da barra de abas).
    var onOpenFile: () -> Void = {}
    @EnvironmentObject private var uiPrefs: UIPrefs
    /// R3.7 — último pedido de navegação do TOC (token crescente).
    @State private var tocRequest: TocNavigateRequest?
    /// R3.7 sync inversa — seção ativa reportada pelo scroll do WebView.
    @State private var activeHeadingSlug: String?
    /// Fase 7 — busca no documento (R5.1), restrita à coluna de conteúdo.
    @State private var showSearch = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        let tab = store.tabs.first(where: { $0.id == tabID })
        let search = tab?.search
        let tabScrollOffset = tab?.scrollOffset ?? 0
        let tabShowsDiff = tab?.showsDiff == true
        let tabDiffStatuses = tabShowsDiff ? tab?.diffResult?.statuses : nil
        let isActiveSearch = search?.isActive == true
        let searchQuery = isActiveSearch ? (search?.query ?? "") : ""
        let searchCurrent = search?.current ?? 0
        let searchCount = search?.count ?? 0
        let tocOutline = (tab?.document).map { DocumentOutline($0.document) }

        HStack(spacing: 0) {
            // MARK: Coluna central — abas, busca, update, render, estatísticas
            VStack(spacing: 0) {
                TabBarView(store: store, onOpenFile: onOpenFile)
                if showSearch {
                    SearchBarView(store: store, isFocused: $searchFieldFocused) {
                        showSearch = false
                        store.setSearchActive(false, in: tabID)
                    }
                }
                if let tab, tab.diffResult != nil && tab.hasExternalUpdate {
                    ExternalUpdateBanner(
                        showsDiff: tabShowsDiff,
                        summary: tab.diffResult?.summary
                    ) {
                        store.toggleDiffView(in: tabID)
                    } onConfirm: {
                        store.confirmExternalUpdate(in: tabID)
                    }
                }
                if let doc = tab?.document {
                    let html = buildHTML(doc: doc, statuses: tabDiffStatuses)
                    MarkdownWebView(
                        html: html,
                        scrollPosition: tabScrollOffset,
                        searchQuery: searchQuery,
                        searchMatches: searchCount,
                        searchCurrent: searchCurrent,
                        baseURL: doc.url.deletingLastPathComponent(),
                        scrollToHeading: tocRequest,
                        onActiveHeadingChange: { slug in
                            activeHeadingSlug = slug
                        },
                        onOpenLink: onOpenLink
                    )
                }
                Divider()
                if let doc = tab?.document {
                    FooterView(info: FooterInfo(document: doc, folderRoot: folderRoot))
                }
            }

            // MARK: Coluna TOC — apenas TOC, altura total
            if uiPrefs.showTOC {
                if let outline = tocOutline {
                    TocPanelView(
                        outline: outline,
                        onSelect: { slug in
                            tocRequest = TocNavigateRequest(token: (tocRequest?.token ?? 0) + 1, slug: slug)
                        },
                        requiredWidth: TocPanelView.idealWidth(for: outline),
                        // Largura da SESSÃO: default (ideal do 1º doc) a cada launch
                        initialWidth: TocPanelView.idealWidth(for: outline),
                        activeSlug: activeHeadingSlug
                    )
                }
            }
        }
        .onChange(of: tabID) { _, _ in
            // aba trocada: destaque precisa ser re-aprendido do novo documento
            activeHeadingSlug = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownFind)) { _ in
            // R5.1 — Cmd+F abre a busca no documento (coluna central)
            showSearch = true
            store.setSearchActive(true, in: tabID)
            DispatchQueue.main.async { searchFieldFocused = true }
        }
    }

    // MARK: - HTML generation

    private func buildHTML(doc: OpenDocument, statuses: [BlockDiffer.Status]?) -> String {
        let converter = MarkdownHTMLConverter()

        if let statuses = statuses {
            return buildDiffHTML(doc: doc, statuses: statuses, converter: converter)
        }

        return converter.convert(doc.document,
                                 frontmatter: doc.frontmatter,
                                 frontmatterError: doc.frontmatterError,
                                 baseFileURL: doc.url,
                                 readingPrefs: readingPrefs)
    }

    private func buildDiffHTML(doc: OpenDocument, statuses: [BlockDiffer.Status],
                               converter: MarkdownHTMLConverter) -> String {
        let fm = buildFrontmatterHTML(doc: doc)
        var body = ""

        let blocks = doc.document.blocks
        let removals = store.tabs.first { $0.id == tabID }?.diffResult?.removals ?? []
        var nextRemoval = 0

        for (index, block) in blocks.enumerated() {
            while nextRemoval < removals.count && removals[nextRemoval].insertAt <= index {
                let r = removals[nextRemoval]
                let text = r.texts.joined(separator: "\n")
                body += "<div class=\"diff-removed\">\(MarkdownHTMLConverter.escapeHTML(text))</div>\n"
                nextRemoval += 1
            }

            let blockHTML = converter.convertBlock(block, baseFileURL: doc.url)
            let status = statuses.indices.contains(index) ? statuses[index] : .unchanged
            switch status {
            case .strong:
                body += "<div class=\"diff-added-strong\">\(blockHTML)</div>\n"
            case .weak:
                body += "<div class=\"diff-added\">\(blockHTML)</div>\n"
            default:
                body += blockHTML
            }
        }
        while nextRemoval < removals.count {
            let r = removals[nextRemoval]
            let text = r.texts.joined(separator: "\n")
            body += "<div class=\"diff-removed\">\(MarkdownHTMLConverter.escapeHTML(text))</div>\n"
            nextRemoval += 1
        }

        return MarkdownHTMLConverter.htmlHeader(readingPrefs: readingPrefs) + fm + body + MarkdownHTMLConverter.htmlFooter
    }

    private func buildFrontmatterHTML(doc: OpenDocument) -> String {
        if let error = doc.frontmatterError {
            return "<div class=\"frontmatter-error\">\(MarkdownHTMLConverter.escapeHTML(error))</div>\n"
        }
        guard let fm = doc.frontmatter, !fm.isEmpty else { return "" }
        var html = "<div class=\"frontmatter\"><table>"
        for field in fm.orderedFields {
            let value: String
            switch field.value {
            case .string(let s): value = s
            case .list(let items): value = items.joined(separator: ", ")
            }
            html += "<tr><td class=\"fm-key\">\(MarkdownHTMLConverter.escapeHTML(field.key))</td>"
            html += "<td class=\"fm-value\">\(MarkdownHTMLConverter.escapeHTML(value))</td></tr>"
        }
        html += "</table></div>\n"
        return html
    }
}

// MARK: - Banner de atualização externa

/// R4.2/R13.x — banner visualmente distinto de "arquivo mudou fora do app":
/// destaque laranja, ícone de sincronização, resumo do diff, alternância
/// Nova/Diff e confirmação de leitura. Fica na coluna central, claramente
/// separado do conteúdo renderizado.
private struct ExternalUpdateBanner: View {
    let showsDiff: Bool
    let summary: String?
    let onToggleView: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Arquivo atualizado externamente")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if showsDiff, let summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Picker("Visão", selection: Binding(
                get: { showsDiff },
                set: { _ in onToggleView() }
            )) {
                Text("Nova").tag(false)
                Text("Diff").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 130)
            .help("Alternar entre conteúdo novo e diff (⌘D)")
            Button("Confirmar leitura", action: onConfirm)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Marcar mudanças como lidas")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arquivo atualizado externamente\(summary.map { ": \($0)" } ?? "")")
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
