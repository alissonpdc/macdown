import SwiftUI

struct FolderTreeItemView: View {
    @ObservedObject var node: FolderTreeNode
    var isRoot: Bool = false
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
            // Solid disclosure triangle first, rotates when expanded.
            // Invisible (but space-reserving) for folders without children.
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 9))
                .foregroundColor(node.children.isEmpty ? .clear : .secondary)
                .rotationEffect(.degrees(node.isExpanded ? 90 : 0))

            // Folder icon second (uses valid SF Symbols for both states)
            Image(systemName: node.isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Name
            Text(node.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Path only for the root folder
            if isRoot {
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

    private var fileRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(node.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openFileInNewTab(node.url)
        }
        .onTapGesture {
            openFile(node.url)
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
}
