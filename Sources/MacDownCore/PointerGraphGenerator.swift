import Foundation
import Markdown

/// R14 — Gera um diagrama Mermaid do grafo de apontamentos entre arquivos markdown
/// de uma pasta. Cada nó é um arquivo; cada seta é um link interno.
public enum PointerGraphGenerator {
    /// Resultado da geração do grafo.
    public struct Result: Equatable {
        public let mermaidCode: String
        public let nodeCount: Int
        public let edgeCount: Int
        public let isolatedFiles: [String]

        public init(mermaidCode: String, nodeCount: Int, edgeCount: Int, isolatedFiles: [String]) {
            self.mermaidCode = mermaidCode
            self.nodeCount = nodeCount
            self.edgeCount = edgeCount
            self.isolatedFiles = isolatedFiles
        }
    }

    /// Gera o grafo de apontamentos a partir da pasta raiz.
    public static func generate(root: URL) -> Result {
        let files = scanMarkdownFiles(root: root)
        let links = extractAllLinks(files: files, root: root)

        // Mapeia caminho relativo → nó Mermaid
        var nodeNames: [String: String] = [:]
        var nameIndex = 0
        for file in files {
            let rel = relativePath(of: file, from: root)
            if nodeNames[rel] == nil {
                nodeNames[rel] = "node\(nameIndex)"
                nameIndex += 1
            }
        }

        // Coleta arestas (deduplicadas)
        var edgeSet = Set<String>()
        var edges: [(from: String, to: String)] = []
        for (sourceFile, targets) in links {
            let sourceRel = relativePath(of: sourceFile, from: root)
            guard let sourceNode = nodeNames[sourceRel] else { continue }
            for target in targets {
                let targetRel = normalizeLinkTarget(target, sourceFile: sourceFile, root: root)
                guard let targetNode = nodeNames[targetRel] else { continue }
                let edgeKey = "\(sourceNode)->\(targetNode)"
                if edgeSet.insert(edgeKey).inserted {
                    edges.append((sourceNode, targetNode))
                }
            }
        }

        // Arquivos isolados (sem nem incoming nem outgoing)
        var connectedNodes = Set<String>()
        for edge in edges {
            connectedNodes.insert(edge.from)
            connectedNodes.insert(edge.to)
        }
        let isolated = nodeNames.keys.filter { key in
            guard let node = nodeNames[key] else { return false }
            return !connectedNodes.contains(node)
        }.sorted()

        // Gera código Mermaid
        var mermaid = "graph LR\n"
        for (rel, node) in nodeNames.sorted(by: { $0.key < $1.key }) {
            let label = sanitizeLabel((rel as NSString).lastPathComponent)
            mermaid += "    \(node)[\"\(label)\"]\n"
        }
        for edge in edges {
            mermaid += "    \(edge.from) --> \(edge.to)\n"
        }

        return Result(
            mermaidCode: mermaid,
            nodeCount: nodeNames.count,
            edgeCount: edges.count,
            isolatedFiles: isolated
        )
    }

    // MARK: - File scanning

    /// Escaneia recursivamente todos os arquivos .md da pasta.
    static func scanMarkdownFiles(root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: [.isDirectoryKey],
                                             options: [.skipsHiddenFiles])
        else { return [] }

        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir),
               !isDir.boolValue,
               FolderScanner.isMarkdown(item)
            {
                files.append(item.resolvingSymlinksInPath())
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    // MARK: - Link extraction

    /// Extrai links internos de um arquivo markdown.
    static func extractLinks(from url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return extractLinks(from: text)
    }

    /// Extrai links internos de um texto markdown (regex: [text](url) e ![alt](url)).
    static func extractLinks(from text: String) -> [String] {
        var links: [String] = []
        // Captura [text](url) e ![alt](url)
        let pattern = #"!?\[[^\]]*\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            for match in regex.matches(in: text, options: [], range: range) {
                let href = ns.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespaces)
                // Ignora URLs externas, âncoras puras e mailto
                guard !href.hasPrefix("http://"),
                      !href.hasPrefix("https://"),
                      !href.hasPrefix("mailto:"),
                      !href.hasPrefix("#"),
                      !href.hasPrefix("data:")
                else { continue }
                // Remove fragment do href
                let cleaned = href.components(separatedBy: "#").first ?? href
                if !cleaned.isEmpty {
                    links.append(cleaned)
                }
            }
        }
        return links
    }

    /// Extrai links internos de todos os arquivos e retorna um dicionário arquivo→[links].
    static func extractAllLinks(files: [URL], root _: URL) -> [URL: [String]] {
        var result: [URL: [String]] = [:]
        for file in files {
            let links = extractLinks(from: file)
            if !links.isEmpty {
                result[file] = links
            }
        }
        return result
    }

    // MARK: - Helpers

    /// Caminho relativo do arquivo em relação à raiz (sem extensão para o label).
    static func relativePath(of file: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return file.lastPathComponent }
        let relative = String(filePath.dropFirst(rootPath.count + 1))
        return relative.isEmpty ? file.lastPathComponent : relative
    }

    /// Normaliza um link href para o caminho relativo do arquivo alvo.
    static func normalizeLinkTarget(_ href: String, sourceFile: URL, root: URL) -> String {
        let sourceDir = sourceFile.deletingLastPathComponent()
        // Decodifica %20 e outros percent-encoding
        let decoded = href.removingPercentEncoding ?? href
        let resolved = URL(fileURLWithPath: decoded, relativeTo: sourceDir)
            .standardizedFileURL
        return relativePath(of: resolved, from: root)
    }

    /// Escapa o label para o syntax Mermaid (remove caracteres especiais).
    static func sanitizeLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
    }
}
