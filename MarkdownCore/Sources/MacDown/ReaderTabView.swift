import SwiftUI
import MarkdownCore

/// Conteúdo de uma aba com persistência da posição de scroll (R2.5) e links clicáveis (R6.2).
struct ReaderTabView: View {
    let tabID: ReaderTab.ID
    @ObservedObject var store: TabStore
    var onOpenLink: (URL) -> Void = { _ in }

    var body: some View {
        let tab = store.tabs.first(where: { $0.id == tabID })
        ScrollView([.vertical]) {
            VStack(alignment: .leading, spacing: 12) {
                if let tab, tab.diffResult != nil && tab.hasExternalUpdate {
                    diffHeader(tab)
                }
                if let doc = tab?.document {
                    documentBody(doc,
                                 statuses: tab?.showsDiff == true ? tab?.diffResult?.statuses : nil)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named("reader")).origin.y
                )
            })
        }
        .coordinateSpace(name: "reader")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            store.setScrollOffset(-offset, for: tabID)
        }
    }

    /// R13.3 — alterna visão "Nova"/"Diff" e mostra o resumo do round atual.
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
                // R13.1 — resumo do indicador
                Text(result.summary)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button("Confirmar leitura") {
                store.confirmExternalUpdate(in: tabID)
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private func documentBody(_ doc: OpenDocument, statuses: [BlockDiffer.Status]?) -> some View {
        if let error = doc.frontmatterError {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        } else if let fm = doc.frontmatter, !fm.fields.isEmpty {
            FrontmatterCard(fields: fm.fields)
        }
        let rows = displayRows(doc, statuses: statuses)
        ForEach(rows) { row in
            switch row.content {
            case .block(let block):
                // R13.1 — blocos adicionados/modificados: gutter "+" verde estilo GitHub
                if let status = row.status, status != .unchanged {
                    diffRow(sign: "+", color: .green, strong: status == .strong) {
                        BlockView(block: block, onOpenLink: onOpenLink, linkBaseURL: doc.url)
                    }
                } else {
                    BlockView(block: block, onOpenLink: onOpenLink, linkBaseURL: doc.url)
                }
            case .removed(let texts):
                // R13.1 — blocos removidos do baseline: gutter "−" vermelho estilo GitHub
                diffRow(sign: "-", color: .red, strong: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(texts, id: \.self) { text in
                            Text(text)
                                .strikethrough()
                                .font(.callout)
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Linha estilo "compare" do GitHub web: gutter com sinal (+/−) e fundo colorido.
    @ViewBuilder
    private func diffRow<Content: View>(sign: String, color: Color, strong: Bool,
                                        @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(sign)
                .font(.callout.bold())
                .foregroundStyle(color)
                .frame(width: 12, alignment: .leading)
            content()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            color.opacity(strong ? 0.28 : 0.12),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    /// Intercala os blocos atuais com as remoções nas posições corretas.
    private func displayRows(_ doc: OpenDocument,
                             statuses: [BlockDiffer.Status]?) -> [DisplayRow] {
        var rows: [DisplayRow] = []
        var nextRemoval = 0
        let removals = statuses != nil ? (store.tabs.first { $0.id == tabID }?.diffResult?.removals ?? []) : []

        func appendRemoved(_ r: BlockDiffer.Removal) {
            rows.append(DisplayRow(content: .removed(r.texts), status: nil))
            nextRemoval += 1
        }

        for (index, block) in doc.document.blocks.enumerated() {
            while nextRemoval < removals.count && removals[nextRemoval].insertAt <= index {
                appendRemoved(removals[nextRemoval])
            }
            rows.append(DisplayRow(content: .block(block),
                                   status: statuses?[index]))
        }
        while nextRemoval < removals.count {
            appendRemoved(removals[nextRemoval])
        }
        return rows
    }
}

/// Linha de renderização: bloco atual ou conteúdo removido do baseline (visão Diff).
private struct DisplayRow: Identifiable {
    enum Content {
        case block(any BlockNode)
        case removed([String])
    }

    let content: Content
    let status: BlockDiffer.Status?
    var id: String {
        switch content {
        case .block(let b): return "b-\(ObjectIdentifier(b as AnyObject).hashValue)-\(String(describing: type(of: b)))"
        case .removed(let t): return "r-" + t.joined(separator: "|")
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct FrontmatterCard: View {
    let fields: [String: YAMLValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fields.keys.sorted(), id: \.self) { key in
                HStack(alignment: .top, spacing: 8) {
                    Text(key).bold()
                    Text(valueText(fields[key]!))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    func valueText(_ value: YAMLValue) -> String {
        switch value {
        case .string(let s): return s
        case .list(let items): return items.joined(separator: ", ")
        }
    }
}

struct BlockView: View {
    let block: any BlockNode
    var onOpenLink: (URL) -> Void = { _ in }
    var linkBaseURL: URL = URL(fileURLWithPath: "/")

    var body: some View {
        switch block {
        case let h as HeadingNode:
            heading(h)
        case let p as ParagraphNode:
            // R6.2 — links inline clicáveis; clique é interceptado pelo EnvironmentValues openURL da ReaderTabView
            Text(InlineLinkExtractor.attributed(markdown: p.rawMarkdown, baseURL: linkBaseURL))
                .environment(\.openURL, OpenURLAction { url in
                    onOpenLink(URL(fileURLWithPath: url.path))
                    return .handled
                })
        case let c as CodeBlockNode:
            Text(c.code)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        case let q as QuoteNode:
            Text(q.plainText).italic().padding(.leading, 12)
        case let l as ListNode:
            VStack(alignment: .leading) { ForEach(l.items, id: \.self) { Text("• " + $0) } }
        case let t as TaskListItemsNode:
            VStack(alignment: .leading) {
                ForEach(t.items.indices, id: \.hashValue) { i in
                    HStack {
                        Image(systemName: t.items[i].isChecked ? "checkmark.square" : "square")
                        Text(t.items[i].text)
                    }
                }
            }
        case let t as TableNode:
            TableView(node: t)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func heading(_ h: HeadingNode) -> some View {
        switch h.level {
        case 1: Text(h.inlineText).font(.largeTitle.bold())
        case 2: Text(h.inlineText).font(.title.bold())
        case 3: Text(h.inlineText).font(.title2.bold())
        default: Text(h.inlineText).font(.title3.bold())
        }
    }
}

struct TableView: View {
    let node: TableNode

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                ForEach(node.headerCells, id: \.self) { Text($0).bold() }
            }
            Divider()
            ForEach(node.rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(node.rows[r], id: \.self) { Text($0) }
                }
            }
        }
    }
}
