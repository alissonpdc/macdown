import SwiftUI
import MarkdownCore

struct ContentView: View {
    let initialURL: URL?
    @StateObject private var tabStore = TabStore()
    @State private var loadError: String?
    @State private var folderTree: FolderNode?
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        NavigationSplitView {
            SidebarView(
                tree: folderTree,
                expandedFolders: $expandedFolders,
                activeURL: tabStore.activeTab?.document.url,
                onOpenFile: { url in
                    try? tabStore.open(url: url)
                    recordVisitIfNeeded(url)
                }
            )
        } detail: {
            VStack(spacing: 0) {
                if let tab = tabStore.activeTab {
                    TabBarView(store: tabStore, onOpenFile: openViaPanel, recordVisit: recordVisitIfNeeded)
                    ReaderTabView(
                        tabID: tab.id,
                        store: tabStore,
                        onOpenLink: { target in
                            // R6.2 — link interno abre em nova aba
                            try? tabStore.open(url: target)
                            recordVisitIfNeeded(target)
                        }
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
        .onAppear(perform: openInitial)
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
        .onReceive(NotificationCenter.default.publisher(for: .macDownOpenFolderPanel)) { _ in
            openFolderViaPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownNextTab)) { _ in
            tabStore.selectNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macDownPreviousTab)) { _ in
            tabStore.selectPrevious()
        }
    }

    private func openInitial() {
        guard let url = initialURL else { return }
        if url.hasDirectoryPath {
            loadFolder(url)
        } else {
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
}
