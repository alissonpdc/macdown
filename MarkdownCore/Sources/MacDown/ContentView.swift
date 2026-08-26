import SwiftUI
import MarkdownCore

struct ContentView: View {
    let initialURL: URL?
    @StateObject private var tabStore = TabStore()
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(store: tabStore)
            if let tab = tabStore.activeTab {
                ReaderTabView(tabID: tab.id, store: tabStore)
            } else if let error = loadError {
                ContentUnavailableView("Couldn't open file",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(error))
            } else {
                ContentUnavailableView("MacDown",
                                       systemImage: "doc.richtext",
                                       description: Text("Open a .md file to start reading"))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear(perform: openInitial)
    }

    private func openInitial() {
        guard let url = initialURL else { return }
        do {
            try tabStore.open(url: url)
            loadError = nil
        } catch OpenDocumentError.readFailed {
            loadError = "File not found or unreadable: \(url.path)"
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Conteúdo de uma aba com persistência da posição de scroll (R2.5).
struct ReaderTabView: View {
    let tabID: ReaderTab.ID
    @ObservedObject var store: TabStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical]) {
                VStack(alignment: .leading, spacing: 12) {
                    blocks
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
    }

    private var doc: OpenDocument? {
        store.tabs.first(where: { $0.id == tabID })?.document
    }

    @ViewBuilder
    private var blocks: some View {
        if let doc = doc {
            documentBody(doc)
        }
    }

    @ViewBuilder
    private func documentBody(_ doc: OpenDocument) -> some View {
        Group {
            if let error = doc.frontmatterError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let fm = doc.frontmatter, !fm.fields.isEmpty {
                FrontmatterCard(fields: fm.fields)
            }
            ForEach(Array(doc.document.blocks.enumerated()), id: \.offset) { _, block in
                BlockView(block: block)
            }
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
    let block: BlockNode

    var body: some View {
        switch block {
        case let h as HeadingNode:
            heading(h)
        case let p as ParagraphNode:
            Text(p.text)
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
