import Foundation

/// Nó da árvore de pastas: subpastas sempre visíveis; apenas família markdown listada (R2.4).
public struct FolderNode {
    public let name: String
    public let url: URL
    public let files: [URL]
    public let children: [FolderNode]
}

public enum FolderScanner {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    public static func isMarkdown(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    /// Scan recursivo; o próprio root vira o nó raiz.
    public static func scan(root: URL) -> FolderNode {
        scanFolder(root)
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
}
