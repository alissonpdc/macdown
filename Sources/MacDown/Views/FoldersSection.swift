import SwiftUI

struct FoldersSection: View {
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var store: DocumentStore

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            controlsBar
            treeView
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("Buscar arquivos...", text: $folderManager.filterText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))

            if !folderManager.filterText.isEmpty {
                Button(action: { folderManager.filterText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var controlsBar: some View {
        HStack(spacing: 8) {
            Button(action: { folderManager.expandAll() }) {
                Text("Expandir tudo")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .help("Expandir todas as pastas")

            Button(action: { folderManager.collapseAll() }) {
                Text("Contrair tudo")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .help("Contrair todas as pastas")

            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var treeView: some View {
        ScrollView {
            if folderManager.folderTrees.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folderManager.folderTrees, id: \.id) { root in
                        FolderTreeItemView(node: root)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Nenhuma pasta adicionada")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Use o menu para adicionar uma pasta ao workspace")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
}
