import SwiftUI
import MarkdownCore

/// R2.2/R2.3 — sidebar em árvore com linhas customizadas (sem DisclosureGroup:
/// o chevron nativo fica preso à margem e os insets variam).
/// Cada linha desloca como um bloco: depth * 14pt.
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
                    VStack(alignment: .leading, spacing: 0) {
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
            FolderRowView(
                folder: folder,
                depth: depth,
                indentStep: indentStep,
                isExpanded: Binding(
                    get: { expandedFolders.contains(folder.url.path) },
                    set: { if $0 { expandedFolders.insert(folder.url.path) } else { expandedFolders.remove(folder.url.path) } }
                ),
                content: {
                    self.folderRows(folder.children, depth: depth + 1)
                    self.fileRows(folder.files, depth: depth + 1)
                }
            )
        }.eraseToAnyView()
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
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isActive ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
            .padding(.leading, CGFloat(depth + 1) * indentStep)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(file.lastPathComponent)")
    }
}

/// Linha de pasta com chevron customizado que acompanha a indentação.
private struct FolderRowView<Content: View>: View {
    let folder: FolderNode
    let depth: Int
    let indentStep: CGFloat
    @Binding var isExpanded: Bool
    let content: Content
    @State private var hovering = false

    init(folder: FolderNode, depth: Int, indentStep: CGFloat, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.folder = folder
        self.depth = depth
        self.indentStep = indentStep
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(folder.name)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(
                    hovering ? Color.primary.opacity(0.05) : .clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .padding(.leading, CGFloat(depth) * indentStep)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .accessibilityLabel("Folder \(folder.name)")

            if isExpanded {
                content
            }
        }
    }
}

private extension ForEach where Content: View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
