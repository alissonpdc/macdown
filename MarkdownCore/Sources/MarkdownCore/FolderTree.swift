import Foundation

/// Nó da árvore de pastas: subpastas sempre visíveis; apenas família markdown listada (R2.4).
public struct FolderNode {
    public let name: String
    public let url: URL
    public let files: [URL]
    public let children: [FolderNode]

    /// A subárvore contém ao menos um arquivo markdown?
    public var containsMarkdown: Bool {
        !files.isEmpty || children.contains { $0.containsMarkdown }
    }
}

public enum FolderScanner {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    public static func isMarkdown(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    /// Scan recursivo; o próprio root vira o nó raiz.
    /// `pruningEmptyFolders`: descarta pastas sem nenhum .md na subárvore inteira (feedback UX).
    public static func scan(root: URL, pruningEmptyFolders: Bool = true) -> FolderNode {
        let node = scanFolder(root)
        return pruningEmptyFolders ? pruned(node) ?? node : node
    }

    private static func scanFolder(_ folder: URL) -> FolderNode {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [])) ?? []

        var subfolders: [URL] = []
        var mdFiles: [URL] = []
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                subfolders.append(item)
            } else if isMarkdown(item) {
                mdFiles.append(item)
            }
        }
        return FolderNode(
            name: folder.lastPathComponent,
            url: folder,
            files: mdFiles,
            children: subfolders.map(scanFolder)
        )
    }

    private static func pruned(_ node: FolderNode) -> FolderNode? {
        guard node.containsMarkdown else { return nil }
        let keptChildren = node.children.compactMap(pruned)
        return FolderNode(name: node.name, url: node.url, files: node.files, children: keptChildren)
    }
}
