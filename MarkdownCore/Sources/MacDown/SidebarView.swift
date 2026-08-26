import SwiftUI
import MarkdownCore

/// R2.2/R2.3 — sidebar em árvore: subpastas colapsáveis, arquivos .md clicáveis, ativo destacado.
struct SidebarView: View {
    let tree: FolderNode?
    @Binding var expandedFolders: Set<String>
    let activeURL: URL?
    let onOpenFile: (URL) -> Void

    var body: some View {
        Group {
            if let tree = tree {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        folderChildren(tree, depth: 0)
                        fileRows(tree.files, indent: false)
                    }
                    .padding(8)
                }
            } else {
                Text("No folder open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(minWidth: 200)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Subpastas colapsáveis de um nó, com indentação por profundidade. AnyView quebra a recursão.
    private func folderChildren(_ node: FolderNode, depth: Int) -> AnyView {
        ForEach(node.children, id: \.url) { child in
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedFolders.contains(child.url.path) },
                    set: { if $0 { expandedFolders.insert(child.url.path) } else { expandedFolders.remove(child.url.path) } }
                )
            ) {
                VStack(alignment: .leading, spacing: 1) {
                    folderChildren(child, depth: depth + 1)
                    fileRows(child.files, indent: true)
                }
            } label: {
                folderLabel(child, depth: depth)
            }
        }.eraseToAnyView()
    }

    private func folderLabel(_ node: FolderNode, depth: Int) -> some View {
        Label(node.name, systemImage: "folder")
            .font(.system(size: 12))
            .padding(.leading, CGFloat(depth) * 14)
    }

    @ViewBuilder
    private func fileRows(_ files: [URL], indent: Bool) -> some View {
        ForEach(files, id: \.self) { file in
            fileRow(file, indent: indent)
        }
    }

    private func fileRow(_ file: URL, indent: Bool) -> some View {
        let isActive = file.standardizedFileURL == activeURL?.standardizedFileURL
        return Button(action: { onOpenFile(file) }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                Text(file.deletingPathExtension().lastPathComponent)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.leading, indent ? 20 : 4)
            .background(isActive ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(file.lastPathComponent)")
    }
}

private extension ForEach where Content: View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
