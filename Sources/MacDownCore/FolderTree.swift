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
        let resolved = folder.resolvingSymlinksInPath()

        var mdFiles: [URL] = []
        var childNodes: [FolderNode] = []

        let items: [URL]
        do {
            items = try fm.contentsOfDirectory(
                at: resolved,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            return FolderNode(name: resolved.lastPathComponent, url: resolved, files: [], children: [])
        }

        var subfolders: [URL] = []
        for item in items {
            let itemResolved = item.resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: itemResolved.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    subfolders.append(itemResolved)
                } else if isMarkdown(itemResolved) {
                    mdFiles.append(itemResolved)
                }
            }
        }

        for sub in subfolders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            childNodes.append(scanFolder(sub))
        }

        mdFiles.sort { $0.lastPathComponent < $1.lastPathComponent }

        return FolderNode(
            name: resolved.lastPathComponent,
            url: resolved,
            files: mdFiles,
            children: childNodes
        )
    }

    private static func pruned(_ node: FolderNode) -> FolderNode? {
        guard node.containsMarkdown else { return nil }
        let keptChildren = node.children.compactMap(pruned)
        return FolderNode(name: node.name, url: node.url, files: node.files, children: keptChildren)
    }
}
