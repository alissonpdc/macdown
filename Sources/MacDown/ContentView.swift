import SwiftUI
import MarkdownCore

struct ContentView: View {
    let initialURL: URL?
    @StateObject private var tabStore = TabStore()
    @EnvironmentObject var readingPrefs: ReadingPrefs
    @State private var loadError: String?
    @State private var folderTree: FolderNode?
    @State private var expandedFolders: Set<String> = []
    /// Fase 6 — watch da pasta aberta + arquivos soltos (R4.1/R4.3/R4.4).
    @State private var watcher: FileWatcher?
    /// Fase 7 — busca global na pasta (R5.2).
    @State private var showGlobalSearch = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                tree: folderTree,
                expandedFolders: $expandedFolders,
                activeURL: tabStore.activeTab?.document.url,
                onOpenFile: { url in
                    try? tabStore.open(url: url)
                    recordVisitIfNeeded(url)
                    refreshWatchers()
                }
            )
        } detail: {
            VStack(spacing: 0) {
                if let tab = tabStore.activeTab {
                    ReaderTabView(
                        tabID: tab.id,
                        store: tabStore,
                        readingPrefs: readingPrefs,
                        onOpenLink: { target in
                            // R6.2 — link interno abre em nova aba
                            try? tabStore.open(url: target)
                            recordVisitIfNeeded(target)
                            refreshWatchers()
                        },
                        folderRoot: folderTree?.url,
                        onOpenFile: openViaPanel
                    )
                } else if let error = loadError {
                    ContentUnavailableView("Couldn't open file",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    ContentUnavailableView("MacDown",
                                           systemImage: "doc.richtext",
                                           description: Text("Open a .md file or a folder to start reading"))
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            openInitial()
            drainPendingOpenURLs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownCloseActiveTab)) { _ in
            if let id = tabStore.activeTabID { tabStore.close(id: id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownGoBack)) { _ in
            guard let id = tabStore.activeTabID else { return }
            _ = tabStore.goBack(in: id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownGoForward)) { _ in
            guard let id = tabStore.activeTabID else { return }
            _ = tabStore.goForward(in: id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownOpenFolder)) { note in
            if let url = note.object as? URL { loadFolder(url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownOpenFile)) { _ in
            openViaPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownOpenURLs)) { note in
            guard let urls = note.object as? [URL] else { return }
            open(urls)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownOpenFolderPanel)) { _ in
            openFolderViaPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownNextTab)) { _ in
            tabStore.selectNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownPreviousTab)) { _ in
            tabStore.selectPrevious()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownToggleDiff)) { _ in
            // R13.3 — Cmd+D alterna a visão da aba ativa
            if let id = tabStore.activeTabID { tabStore.toggleDiffView(in: id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownFindNext)) { _ in
            if let id = tabStore.activeTabID { tabStore.nextMatch(in: id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownFindPrevious)) { _ in
            if let id = tabStore.activeTabID { tabStore.previousMatch(in: id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownFindGlobal)) { _ in
            showGlobalSearch = true
        }
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView(store: tabStore, isPresented: $showGlobalSearch, allURLs: collectSearchURLs())
        }
    }

    private func openInitial() {
        guard let url = initialURL else { return }
        open([url])
    }

    /// Abre arquivos em abas e pastas na sidebar (Finder, CLI, painéis).
    private func open(_ urls: [URL]) {
        for url in urls {
            if url.hasDirectoryPath {
                loadFolder(url)
                continue
            }
            do {
                try tabStore.open(url: url)
                loadError = nil
                recordVisitIfNeeded(url)
            } catch OpenDocumentError.readFailed {
                loadError = "File not found or unreadable: \(url.path)"
            } catch {
                loadError = error.localizedDescription
            }
        }
        refreshWatchers()
    }

    /// Drena URLs entregues antes de a view instalar o handler de abertura.
    private func drainPendingOpenURLs() {
        guard !PendingOpenURLs.buffer.isEmpty else { return }
        let urls = PendingOpenURLs.buffer
        PendingOpenURLs.buffer = []
        open(urls)
    }

    /// R2.1 — carrega pasta raiz da sidebar.
    private func loadFolder(_ url: URL) {
        folderTree = FolderScanner.scan(root: url)
        // raiz e subpastas de primeiro nível expandidas por padrão
        expandedFolders = [url.path]
        if let tree = folderTree {
            for child in tree.children where !child.files.isEmpty {
                expandedFolders.insert(child.url.path)
            }
        }
        refreshWatchers()
    }

    // MARK: Fase 6 — FileWatcher (R4.x)

    /// Observa a pasta da sidebar e cada arquivo aberto fora dela.
    private func refreshWatchers() {
        watcher?.stop()
        var paths: [URL] = []
        if let root = folderTree?.url { paths.append(root) }
        let rootPath = folderTree?.url.standardizedFileURL.path
        for tab in tabStore.tabs {
            let path = tab.document.url.standardizedFileURL.path
            if let rootPath, path.hasPrefix(rootPath + "/") { continue }
            if !paths.contains(where: { $0.standardizedFileURL == tab.document.url.standardizedFileURL }) {
                paths.append(tab.document.url)
            }
        }
        guard !paths.isEmpty else { return }

        watcher = FileWatcher(paths: paths.map { $0.resolvingSymlinksInPath() }) { events in
            handleWatchEvents(events)
        }
        watcher?.start()
    }

    private func handleWatchEvents(_ events: [WatchEvent]) {
        tabStore.apply(events) // R4.1 re-render + R4.2 indicador + R4.4 rename em abas
        // R4.3 — mudanças estruturais recarregam a árvore da sidebar
        let structural = events.contains { event in
            switch event.kind {
            case .created, .deleted: return true
            case .renamed: return true
            case .modified: return false
            }
        }
        guard structural, let root = folderTree?.url else { return }
        folderTree = FolderScanner.scan(root: root)
    }

    private func openViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .text,
                                      .init(filenameExtension: "markdown") ?? .text,
                                      .init(filenameExtension: "mdown") ?? .text,
                                      .init(filenameExtension: "mkd") ?? .text]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            try? tabStore.open(url: url)
            recordVisitIfNeeded(url)
        }
        refreshWatchers()
    }

    private func recordVisitIfNeeded(_ url: URL) {
        guard let id = tabStore.activeTabID else { return }
        // abrir arquivo existente apenas foca a aba; visita nova entra no histórico
        tabStore.recordVisit(url.path, in: id)
    }

    private func openFolderViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFolder(url)
    }

    /// R5.2 — reúne todos os .md da pasta aberta (recursivo) + abas avulsas.
    private func collectSearchURLs() -> [URL] {
        var urls: [URL] = []
        if let tree = folderTree {
            func walk(_ node: FolderNode) {
                urls.append(contentsOf: node.files)
                node.children.forEach(walk)
            }
            walk(tree)
        }
        let known = urls.map { $0.standardizedFileURL.path }
        for tab in tabStore.tabs {
            let path = tab.document.url.standardizedFileURL.path
            if !known.contains(path) { urls.append(tab.document.url) }
        }
        return urls
    }
}

// MARK: Fase 7 — Busca no documento (R5.1)

/// Barra de busca sobreposta ao leitor; ligada ao estado de busca da aba ativa.
struct SearchBarView: View {
    @ObservedObject var store: TabStore
    var isFocused: FocusState<Bool>.Binding
    var onClose: () -> Void

    private var tab: ReaderTab? { store.activeTab }

    private var binding: Binding<String> {
        Binding(get: { store.activeTab?.search.query ?? "" },
                set: { if let id = store.activeTabID { store.updateSearch(query: $0, in: id) } })
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: binding)
                .focused(isFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    if let id = store.activeTabID { store.nextMatch(in: id) }
                    // Enter não pode derrubar o foco: o re-render da busca órfã
                    // ignora os Enter seguintes. Re-afirma o foco no campo para
                    // permitir a busca cíclica (Chrome-like).
                    isFocused.wrappedValue = false
                    DispatchQueue.main.async { isFocused.wrappedValue = true }
                }
            if let tab, tab.search.isActive {
                let total = tab.search.count
                let pos = total == 0 ? 0 : tab.search.current + 1
                Text("\(pos)/\(total)")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
                    .monospacedDigit()
            }
            Button { if let id = store.activeTabID { store.previousMatch(in: id) } } label: {
                Image(systemName: "chevron.up")
            }.help("Previous (Shift+⌘G)")
            Button { if let id = store.activeTabID { store.nextMatch(in: id) } } label: {
                Image(systemName: "chevron.down")
            }.help("Next (⌘G)")
            Button { onClose() } label: { Image(systemName: "xmark") }.help("Close (Esc)")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onAppear { isFocused.wrappedValue = true }
        .onExitCommand { onClose() }
    }
}

// MARK: Fase 7 — Busca global na pasta (R5.2)

/// Busca em todos os markdown da pasta aberta; clicar num resultado abre o arquivo.
struct GlobalSearchView: View {
    @ObservedObject var store: TabStore
    @Binding var isPresented: Bool
    let allURLs: [URL]

    @State private var query = ""
    @State private var caseSensitive = false
    @State private var wholeWord = false
    @State private var useRegex = false
    @State private var results: [FileSearchResult] = []
    /// R5.2 — query/opções usadas na última busca (par de `results`).
    @State private var lastQuery = ""
    @State private var lastOptions: SearchOptions = []

    private var options: SearchOptions {
        var opts: SearchOptions = []
        if caseSensitive { opts.insert(.caseSensitive) }
        if wholeWord { opts.insert(.wholeWord) }
        if useRegex { opts.insert(.regex) }
        return opts
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search in folder", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(run)
                Toggle("Aa", isOn: $caseSensitive).help("Case sensitive")
                Toggle("Word", isOn: $wholeWord).help("Whole word")
                Toggle(".*", isOn: $useRegex).help("Regular expression")
                Button("Search") { run() }
                Button("Done") { isPresented = false }
            }
            .padding()
            Divider()
            List {
                ForEach(results) { file in
                    Section {
                        ForEach(file.matches) { m in
                            Button { open(file.url, match: m) } label: {
                                Text(Self.highlightedSnippet(m.snippet,
                                                            start: m.snippetMatchStart,
                                                            length: m.range.count))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(DisplayName.file(file.url)).font(.headline)
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
    }

    private func run() {
        guard !query.isEmpty else { results = []; return }
        lastQuery = query
        lastOptions = options
        let inputs = allURLs.compactMap { url -> (URL, CoreDocument)? in
            guard let doc = try? OpenDocument(url: url) else { return nil }
            return (url, doc.document)
        }
        results = SearchEngine.findInFiles(inputs, query: query, options: options)
    }

    /// R5.2 — abre o arquivo e salta a render até a ocorrência clicada.
    private func open(_ url: URL, match: SearchMatch) {
        try? store.open(url: url, revealingMatch: match,
                        query: lastQuery.isEmpty ? query : lastQuery,
                        options: lastOptions)
        isPresented = false
    }

    static func highlightedSnippet(_ snippet: String, start: Int, length: Int) -> AttributedString {
        let ns = snippet as NSString
        let s = max(0, min(start, ns.length))
        let e = max(s, min(start + length, ns.length))
        let before = ns.substring(with: NSRange(location: 0, length: s))
        let mid = ns.substring(with: NSRange(location: s, length: e - s))
        let after = ns.substring(with: NSRange(location: e, length: ns.length - e))
        let a = AttributedString(before)
        var m = AttributedString(mid)
        m.backgroundColor = Color.yellow
        let af = AttributedString(after)
        return a + m + af
    }
}
