import SwiftUI

struct FolderTreeItemView: View {
    let node: FolderTreeNode
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if node.isFolder {
                folderRow
            } else {
                fileRow
            }

            if node.isExpanded && !node.children.isEmpty {
                ForEach(node.children, id: \.id) { child in
                    FolderTreeItemView(node: child)
                        .padding(.leading, 12)
                }
            }
        }
    }

    private var folderRow: some View {
        HStack(spacing: 6) {
            // Chevron first (always visible for folders with children)
            if !node.children.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
            } else {
                // Placeholder space for folders without children (for alignment)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.clear)
            }

            // Folder icon second
            Image(systemName: node.isExpanded ? "folder.open" : "folder")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Name
            Text(node.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Path only for root folders
            if isRootFolder {
                Text(node.parentFolderPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            folderManager.toggleFolderExpansion(node.id)
        }
        .padding(.vertical, 2)
    }

    private var isRootFolder: Bool {
        folderManager.folderTrees.contains { $0.id == node.id }
    }

    private var fileRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(node.parentFolderPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            openFile(node.url)
        }
        .onTapGesture(count: 2) {
            openFileInNewTab(node.url)
        }
        .onTapGesture {
            openContextMenu()
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Abrir em nova aba") {
                openFileInNewTab(node.url)
            }
        }
    }

    private func openFile(_ url: URL) {
        try? store.open(url)
    }

    private func openFileInNewTab(_ url: URL) {
        try? store.openInNewTab(url)
    }

    private func openContextMenu() {
        // Context menu is handled by .contextMenu modifier
    }
}
