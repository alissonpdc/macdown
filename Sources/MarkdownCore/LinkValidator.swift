import Foundation
import Markdown

/// R10.1 — link interno quebrado detectado na validação do documento.
public struct BrokenLink: Equatable {
    public enum Reason: Equatable {
        /// O arquivo apontado não existe no disco.
        case fileNotFound
        /// O arquivo existe, mas a âncora (`#slug`) não corresponde a nenhum heading.
        case anchorNotFound
    }

    public let href: String
    public let reason: Reason

    public init(href: String, reason: Reason) {
        self.href = href
        self.reason = reason
    }
}

/// R10.1 — valida links internos do documento aberto (arquivo inexistente, âncora inexistente).
/// Links externos (http, mailto, …) e âncoras em arquivos não-markdown são ignorados.
/// Links repetidos quebrados são deduplicados para o badge do rodapé.
public enum LinkValidator {
    public static func brokenLinks(in doc: OpenDocument) -> [BrokenLink] {
        // valida apenas o corpo markdown (frontmatter não contém links renderizados)
        let body = FrontmatterExtractor.extract(from: doc.rawText).markdown
        let hrefs = extractHrefs(in: Markdown.Document(parsing: body, options: [.disableSmartOpts]))

        var seen = Set<String>()
        var result: [BrokenLink] = []
        let ownSlugs = Set(DocumentOutline(doc.document).entries.map(\.slug))

        for href in hrefs {
            guard let reason = validate(href: href, sourceFile: doc.url, ownSlugs: ownSlugs) else { continue }
            guard seen.insert(href).inserted else { continue }
            result.append(BrokenLink(href: href, reason: reason))
        }
        return result
    }

    /// Retorna o motivo se o link estiver quebrado, nil se válido/ignorado.
    static func validate(href: String, sourceFile: URL, ownSlugs: Set<String>) -> BrokenLink.Reason? {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // separa caminho e fragmento: "dir/doc.md#secao"
        let hashIndex = trimmed.firstIndex(of: "#")
        let path = hashIndex.map { String(trimmed[..<$0]) } ?? trimmed
        let fragment = hashIndex.map { String(trimmed[trimmed.index(after: $0)...]) } ?? ""

        if path.isEmpty {
            // âncora pura no próprio documento
            return ownSlugs.contains(fragment) ? nil : .anchorNotFound
        }
        guard let url = URL(string: trimmed), url.scheme == nil || url.scheme == "file" else { return nil }
        guard let resolved = LinkResolver.resolve(href: path, from: sourceFile) else { return nil }

        // href pode conter %20; resolver exige o caminho decodificado
        let decoded = resolved.path.removingPercentEncoding ?? resolved.path
        guard FileManager.default.fileExists(atPath: decoded) else { return .fileNotFound }

        // âncora em alvo markdown: valida slugs do arquivo de destino
        if !fragment.isEmpty, decoded.hasSuffix(".md") {
            guard let target = try? OpenDocument(url: URL(fileURLWithPath: decoded)) else { return nil }
            let slugs = Set(DocumentOutline(target.document).entries.map(\.slug))
            return slugs.contains(fragment) ? nil : .anchorNotFound
        }
        return nil
    }

    /// Extrai hrefs de links inline `[t](url)` e imagens `![alt](url)`.
    static func extractHrefs(in node: Markup) -> [String] {
        var hrefs: [String] = []
        if let link = node as? Markdown.Link, let dest = link.destination {
            hrefs.append(dest)
        }
        if let image = node as? Markdown.Image, let source = image.source {
            hrefs.append(source)
        }
        for child in node.children {
            hrefs.append(contentsOf: extractHrefs(in: child))
        }
        return hrefs
    }
}
