import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var theme: ThemeState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if store.documents.isEmpty {
                emptyState
            } else {
                TabView(selection: $store.activeIndex) {
                    ForEach(Array(store.documents.enumerated()), id: \.offset) { index, doc in
                        MarkdownView(content: doc.content, theme: theme.current)
                            .tabItem { Text(doc.title) }
                            .tag(index)
                    }
                }
                .tabViewStyle(.automatic)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button("Abrir") { openFile() }
                Button("Salvar") {}
                    .disabled(true)
            }
            ToolbarItem(placement: .automatic) {
                Picker("Tema", selection: $theme.current) {
                    Text("Claro").tag(AppTheme.light)
                    Text("Escuro").tag(AppTheme.dark)
                    Text("Sistema").tag(AppTheme.system)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
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

func presentOpenPanel(store: DocumentStore = DocumentStore.shared) {
    let panel = NSOpenPanel()
    let mdType = UTType(filenameExtension: "md") ?? .plainText
    let markdownType = UTType(filenameExtension: "markdown") ?? .plainText
    panel.allowedContentTypes = [mdType, markdownType]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? store.open(url)
}
