import Foundation
import Markdown

public struct InlineLink {
    public let label: String
    public let href: String
}

/// Extrai links inline de um trecho markdown e monta AttributedString com links resolvidos (R6.2).
/// macOS: usa AttributeScopes.AppKitAttributes.
public enum InlineLinkExtractor {
    public static func links(in markdown: String) -> [InlineLink] {
        let doc = Markdown.Document(parsing: markdown, options: [.disableSmartOpts])
        var result: [InlineLink] = []
        walk(node: doc) { link in
            let label = link.children.compactMap { $0 as? Text }.map(\.string).joined()
            if let destination = link.destination {
                result.append(InlineLink(label: label, href: destination))
            }
        }
        return result
    }

    private static func walk(node: Markup, visit: (Markdown.Link) -> Void) {
        for child in node.children {
            if let link = child as? Markdown.Link { visit(link) }
            walk(node: child, visit: visit)
        }
    }

    /// Markdown → AttributedString com .link apontando para o arquivo local resolvido.
    public static func attributed(markdown: String, baseURL sourceFile: URL) -> AttributedString {
        var attributed: AttributedString
        if let parsed = try? AttributedString(markdown: markdown, including: \.appKit) {
            attributed = parsed
        } else {
            attributed = AttributedString(markdown)
        }
        // re-resolve cada link relativo contra o arquivo-fonte
        for run in attributed.runs {
            guard let url = run.link else { continue }
            let href = url.absoluteString
            if url.scheme == nil || (url.isFileURL && FileManager.default.fileExists(atPath: url.path) == false) {
                if let resolved = LinkResolver.resolve(href: href, from: sourceFile) {
                    attributed[run.range].link = URL(fileURLWithPath: resolved.path)
                }
            }
        }
        return attributed
    }
}
