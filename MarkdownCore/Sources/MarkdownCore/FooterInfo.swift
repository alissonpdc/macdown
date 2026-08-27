import Foundation

/// R8.1 / R3.13 — Informações do rodapé: breadcrumb, contagens e tasks agregadas.
public struct FooterInfo: Equatable {
    public let breadcrumb: String
    public let wordCount: Int
    public let characterCount: Int
    public let taskSummary: String?

    public init(document: OpenDocument, folderRoot: URL? = nil) {
        self.breadcrumb = Self.computeBreadcrumb(url: document.url, root: folderRoot)
        self.wordCount = document.wordCount
        self.characterCount = document.characterCount
        let summary = TaskSummary(document.document)
        self.taskSummary = summary.total > 0 ? "\(summary.checked)/\(summary.total) tasks" : nil
    }

    /// R8.1 — breadcrumb: caminho relativo à pasta raiz, ou apenas o nome do arquivo.
    static func computeBreadcrumb(url: URL, root: URL?) -> String {
        guard let root else { return url.lastPathComponent }
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return url.lastPathComponent }
        let relative = String(filePath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? url.lastPathComponent : relative
    }
}
