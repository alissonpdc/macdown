import Foundation

/// R3.3 — carrega mermaid.js do bundle do app para um diretório temporário,
/// retornando a URL absoluta para ser injetada como <script src="..."> no HTML.
enum MermaidLoader {
    private static var cachedURL: URL?

    /// URL absoluta do mermaid.min.js pronto para uso no WKWebView.
    static var scriptURL: URL? {
        if let cached = cachedURL, FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDownRender", isDirectory: true)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let target = dest.appendingPathComponent("mermaid.min.js")

        // Tenta copiar do bundle do app (.app/Contents/Resources/)
        if let bundleURL = Bundle.main.url(forResource: "mermaid", withExtension: "min.js") {
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.copyItem(at: bundleURL, to: target)) != nil {
                cachedURL = target
                return target
            }
        }

        // Fallback: copia do diretório Resources/ ao lado do executável (dev / swift run)
        let devPath = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/mermaid.min.js")
        if FileManager.default.fileExists(atPath: devPath.path) {
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.copyItem(at: devPath, to: target)) != nil {
                cachedURL = target
                return target
            }
        }

        // Último recurso: caminho absoluto do Resources/ no diretório de trabalho
        let cwdPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/mermaid.min.js")
        if FileManager.default.fileExists(atPath: cwdPath.path) {
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.copyItem(at: cwdPath, to: target)) != nil {
                cachedURL = target
                return target
            }
        }

        return nil
    }

    /// Tag <script> para incluir mermaid.js, ou string vazia se indisponível.
    static var scriptTag: String {
        guard let url = scriptURL else { return "" }
        return "<script src=\"\(url.absoluteString)\"></script>\n"
    }
}
