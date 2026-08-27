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

    @FocusState private var sidebarFocused: Bool
    @State private var focusedURL: URL?

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
                .focusable()
                .focused($sidebarFocused)
                .onKeyPress(.upArrow) { moveFocusUp() }
                .onKeyPress(.downArrow) { moveFocusDown() }
                .onKeyPress(.rightArrow) { expandOrMoveRight() }
                .onKeyPress(.leftArrow) { collapseOrMoveLeft() }
                .onKeyPress(.return) { openFocusedItem() }
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

    // MARK: - Visible items (flat list for keyboard navigation)

    private func visibleItems() -> [URL] {
        guard let tree = tree else { return [] }
        var items: [URL] = []
        func walk(_ node: FolderNode) {
            for child in node.children {
                items.append(child.url)
                if expandedFolders.contains(child.url.path) {
                    walk(child)
                }
            }
            items.append(contentsOf: node.files)
        }
        walk(tree)
        return items
    }

    // MARK: - Tree helpers

    private func findFolder(_ url: URL) -> FolderNode? {
        guard let tree = tree else { return nil }
        func search(_ node: FolderNode) -> FolderNode? {
            if node.url.path == url.path { return node }
            for child in node.children {
                if let found = search(child) { return found }
            }
            return nil
        }
        return search(tree)
    }

    private func isFolder(_ url: URL) -> Bool {
        findFolder(url) != nil
    }

    private func findParent(of targetURL: URL) -> FolderNode? {
        guard let tree = tree else { return nil }
        func search(_ node: FolderNode) -> FolderNode? {
            for child in node.children {
                if child.url.path == targetURL.path { return node }
                if child.files.contains(where: { $0.path == targetURL.path }) { return child }
                if let found = search(child) { return found }
            }
            return nil
        }
        return search(tree)
    }

    // MARK: - Keyboard navigation (Finder-style)

    private func moveFocusUp() -> KeyPress.Result {
        let items = visibleItems()
        guard !items.isEmpty else { return .ignored }
        if let current = focusedURL, let idx = items.firstIndex(where: { $0.path == current.path }) {
            if idx > 0 { focusedURL = items[idx - 1] }
        } else {
            focusedURL = items.last
        }
        return .handled
    }

    private func moveFocusDown() -> KeyPress.Result {
        let items = visibleItems()
        guard !items.isEmpty else { return .ignored }
        if let current = focusedURL, let idx = items.firstIndex(where: { $0.path == current.path }) {
            if idx < items.count - 1 { focusedURL = items[idx + 1] }
        } else {
            focusedURL = items.first
        }
        return .handled
    }

    /// Right arrow: expand collapsed folder, or move to first child if expanded.
    private func expandOrMoveRight() -> KeyPress.Result {
        guard let url = focusedURL else {
            focusedURL = visibleItems().first
            return .handled
        }
        if isFolder(url) {
            if !expandedFolders.contains(url.path) {
                _ = withAnimation(.easeOut(duration: 0.15)) { expandedFolders.insert(url.path) }
                return .handled
            }
            // Expanded folder → move to first child
            let items = visibleItems()
            if let idx = items.firstIndex(where: { $0.path == url.path }), idx < items.count - 1 {
                focusedURL = items[idx + 1]
                return .handled
            }
        }
        return .ignored
    }

    /// Left arrow: collapse expanded folder, or collapse parent / move to parent.
    private func collapseOrMoveLeft() -> KeyPress.Result {
        guard let url = focusedURL else { return .ignored }
        if isFolder(url) && expandedFolders.contains(url.path) {
            _ = withAnimation(.easeOut(duration: 0.15)) { expandedFolders.remove(url.path) }
            return .handled
        }
        // File or collapsed folder → collapse parent / move to parent
        if let parent = findParent(of: url) {
            if expandedFolders.contains(parent.url.path) {
                _ = withAnimation(.easeOut(duration: 0.15)) { expandedFolders.remove(parent.url.path) }
            }
            focusedURL = parent.url
            return .handled
        }
        return .ignored
    }

    private func openFocusedItem() -> KeyPress.Result {
        guard let url = focusedURL else { return .ignored }
        if isFolder(url) {
            withAnimation(.easeOut(duration: 0.15)) {
                if expandedFolders.contains(url.path) {
                    expandedFolders.remove(url.path)
                } else {
                    expandedFolders.insert(url.path)
                }
            }
        } else {
            onOpenFile(url)
        }
        return .handled
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
                isFocused: focusedURL?.path == folder.url.path,
                onFocus: { focusedURL = $0 },
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
        let isFocused = focusedURL?.path == file.path
        return Button(action: { focusedURL = file; onOpenFile(file) }) {
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
            .padding(.leading, CGFloat(depth + 1) * indentStep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
            )
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
    let isFocused: Bool
    let onFocus: (URL) -> Void
    let content: Content
    @State private var hovering = false

    init(folder: FolderNode, depth: Int, indentStep: CGFloat, isExpanded: Binding<Bool>, isFocused: Bool, onFocus: @escaping (URL) -> Void, @ViewBuilder content: () -> Content) {
        self.folder = folder
        self.depth = depth
        self.indentStep = indentStep
        self._isExpanded = isExpanded
        self.isFocused = isFocused
        self.onFocus = onFocus
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onFocus(folder.url)
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
                .padding(.leading, CGFloat(depth) * indentStep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(hovering ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
                )
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
