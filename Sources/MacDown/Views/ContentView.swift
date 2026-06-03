import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var theme: ThemeState

    @StateObject private var folderManager = FolderManager()
    @StateObject private var searchState = SearchState()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(store.recentsManager)
                .environmentObject(folderManager)
        } detail: {
            VStack(spacing: 0) {
                if searchState.isVisible {
                    FindBarView()
                        .environmentObject(searchState)
                    Divider()
                }

                if store.documents.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $store.activeIndex) {
                        ForEach(Array(store.documents.enumerated()), id: \.offset) { index, doc in
                            MarkdownView(content: doc.content, theme: theme.current, documentID: doc.id)
                                .environmentObject(searchState)
                                .tabItem { Text(doc.title) }
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.automatic)
                }
            }
        }
        .onAppear {
            searchState.onNavigate = { tab, local in
                if store.activeIndex != tab { store.activeIndex = tab }
                guard store.documents.indices.contains(tab) else { return }
                let id = store.documents[tab].id
                if let controller = searchState.controllers[id] {
                    Task { await controller.goToMatch(local) }
                }
            }
        }
        .onChange(of: searchState.query) { _ in runSearchPass() }
        .onChange(of: searchState.mode) { _ in runSearchPass() }
        .onChange(of: store.activeIndex) { _ in
            if searchState.isVisible && searchState.mode == .currentFile {
                runSearchPass()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateFindCurrentFile)) { _ in
            searchState.activate(mode: .currentFile)
            runSearchPass()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateFindAllTabs)) { _ in
            searchState.activate(mode: .allTabs)
            runSearchPass()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportFolderToWorkspace"))) { notification in
            if let url = notification.userInfo?["folderURL"] as? URL {
                try? folderManager.importFolder(url)
            }
        }
    }

    private func runSearchPass() {
        Task { await performSearch() }
    }

    @MainActor
    private func performSearch() async {
        let docs = store.documents
        let query = searchState.query
        let activeIndex = store.activeIndex
        var counts = [Int](repeating: 0, count: docs.count)

        for (i, doc) in docs.enumerated() {
            guard let controller = searchState.controllers[doc.id] else { continue }
            if query.isEmpty {
                await controller.clearSearch()
            } else if searchState.mode == .allTabs || i == activeIndex {
                counts[i] = await controller.highlight(query)
            } else {
                await controller.clearSearch()
            }
        }
        searchState.updateCounts(counts)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Nenhum arquivo aberto")
                .foregroundColor(.secondary)
            Button("Abrir arquivo…") { openFile() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func openFile() {
        presentOpenPanel(store: store)
    }
}

@MainActor
func presentOpenPanel(store: DocumentStore? = nil) {
    let resolvedStore = store ?? DocumentStore.shared
    let panel = NSOpenPanel()
    let mdType = UTType(filenameExtension: "md") ?? .plainText
    let markdownType = UTType(filenameExtension: "markdown") ?? .plainText
    panel.allowedContentTypes = [mdType, markdownType]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? resolvedStore.open(url)
}
