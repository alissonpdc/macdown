import SwiftUI
import MarkdownCore

/// Conteúdo de uma aba com renderização via WKWebView.
struct ReaderTabView: View {
    let tabID: ReaderTab.ID
    @ObservedObject var store: TabStore
    @ObservedObject var readingPrefs: ReadingPrefs
    var onOpenLink: (URL) -> Void = { _ in }
    var folderRoot: URL?
    @EnvironmentObject private var uiPrefs: UIPrefs
    @State private var scrollOffset: CGFloat = 0
    /// R3.7 — último pedido de navegação do TOC (token crescente).
    @State private var tocRequest: TocNavigateRequest?
    /// R3.7 sync inversa — seção ativa reportada pelo scroll do WebView.
    @State private var activeHeadingSlug: String?

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
        VStack(spacing: 0) {
            if let tab, tab.diffResult != nil && tab.hasExternalUpdate {
                diffHeader(tab)
            }
            HStack(spacing: 0) {
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
            Divider()
            if let doc = tab?.document {
                FooterView(info: FooterInfo(document: doc, folderRoot: folderRoot))
            }
        }
        .onChange(of: tabID) { _, _ in
            // aba trocada: destaque precisa ser re-aprendido do novo documento
            activeHeadingSlug = nil
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

    // MARK: - Diff header

    @ViewBuilder
    private func diffHeader(_ tab: ReaderTab) -> some View {
        HStack(spacing: 10) {
            Picker("Visão", selection: Binding(
                get: { tab.showsDiff },
                set: { _ in store.toggleDiffView(in: tabID) }
            )) {
                Text("Nova").tag(false)
                Text("Diff").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            Spacer()
            if tab.showsDiff, let result = tab.diffResult {
                Text(result.summary)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button("Confirmar leitura") {
                store.confirmExternalUpdate(in: tabID)
            }
            .buttonStyle(.link)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
