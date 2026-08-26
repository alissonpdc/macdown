import SwiftUI
import MarkdownCore

/// R2.2/R2.3 — sidebar em árvore: subpastas colapsáveis, arquivos .md clicáveis, ativo destacado.
/// Cada linha é deslocada como um bloco inteiro (chevron + ícone + nome) por depth * 14pt.
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
                        folderRows(tree.children, depth: 0)
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

    // MARK: pastas

    private func folderRows(_ folders: [FolderNode], depth: Int) -> AnyView {
        ForEach(folders, id: \.url) { folder in
            self.folderRow(folder, depth: depth)
        }.eraseToAnyView()
    }

    @ViewBuilder
    private func folderRow(_ folder: FolderNode, depth: Int) -> some View {
        let isExpanded = Binding(
            get: { expandedFolders.contains(folder.url.path) },
            set: { if $0 { expandedFolders.insert(folder.url.path) } else { expandedFolders.remove(folder.url.path) } }
        )
        DisclosureGroup(isExpanded: isExpanded) {
            self.folderRows(folder.children, depth: depth + 1)
            self.fileRows(folder.files, depth: depth + 1)
        } label: {
            // o padding é aplicado na linha inteira; o chevron nativo fica à esquerda dele,
            // então compensamos deslocando o conteúdo interno e deixando o chevron acompanhar
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(folder.name)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .padding(.leading, CGFloat(depth) * indentStep)
        }
    }

    // MARK: arquivos

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
            .padding(.leading, CGFloat(depth + 1) * indentStep) // alinha sob o nome da pasta (após chevron)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(file.lastPathComponent)")
    }
}

private extension ForEach where Content: View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
