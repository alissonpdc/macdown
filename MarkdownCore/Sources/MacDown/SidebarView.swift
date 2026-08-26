import SwiftUI
import MarkdownCore

/// R2.2/R2.3 — sidebar em árvore: subpastas colapsáveis, arquivos .md clicáveis, ativo destacado.
/// Indentação: cada linha recebe exatamente um padding = depth * 14pt (sem acúmulo).
struct SidebarView: View {
    let tree: FolderNode?
    @Binding var expandedFolders: Set<String>
    let activeURL: URL?
    let onOpenFile: (URL) -> Void

    private let indentStep: CGFloat = 14

    var body: some View {
        Group {
            if let tree = tree {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        folderChildren(tree, depth: 0)
                        fileRows(tree.files, depth: 0)
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

    /// Subpastas colapsáveis. AnyView quebra a inferência recursiva de tipo.
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
                    fileRows(child.files, depth: depth + 1)
                }
            } label: {
                // padding no HStack interno: chevron (do DisclosureGroup) + ícone + nome deslocam juntos
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(node.name)
                }
                .font(.system(size: 12))
                .padding(.leading, CGFloat(depth) * indentStep)
            }
        }.eraseToAnyView()
    }

    @ViewBuilder
    private func fileRows(_ files: [URL], depth: Int) -> some View {
        ForEach(files, id: \.self) { file in
            fileRow(file, depth: depth)
        }
    }

    private func fileRow(_ file: URL, depth: Int) -> some View {
        let isActive = file.standardizedFileURL == activeURL?.standardizedFileURL
        return Button(action: { onOpenFile(file) }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                Text(DisplayName.file(file))
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .background(isActive ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
            .padding(.leading, CGFloat(depth) * indentStep)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(file.lastPathComponent)")
    }
}

private extension ForEach where Content: View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
