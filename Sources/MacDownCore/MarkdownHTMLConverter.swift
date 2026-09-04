import Foundation
import Markdown

/// Classe (não struct) porque o contador de slugs duplicados precisa sobreviver
/// entre chamadas de convertBlock durante a conversão de um mesmo documento.
public final class MarkdownHTMLConverter {
    public init() {}

    private var headingSlugCounts: [String: Int] = [:]

    /// R10.1 — hrefs quebrados (LinkValidator) marcados no HTML com
    /// class="broken-link" + data-broken, para o badge do rodapé rolar até eles.
    public var brokenHrefs: Set<String> = []

    /// R3.3 — `mermaidScriptTag`: tag <script> para mermaid.js (injetado pela App layer).
    public func convert(_ document: CoreDocument, frontmatter: Frontmatter? = nil,
                        frontmatterError: String? = nil, baseFileURL: URL? = nil,
                        readingPrefs: ReadingPrefs? = nil,
                        mermaidScriptTag: String = "") -> String
    {
        var html = Self.htmlHeader(readingPrefs: readingPrefs)
        if let base = baseFileURL {
            let dirURL = base.deletingLastPathComponent()
            let escaped = Self.escapeHTML(dirURL.absoluteString)
            html += "<base href=\"\(escaped)\">\n"
            html += "<script>var BASE_URL = \"\(escaped)\";</script>\n"
        }
        if let fm = frontmatter, !fm.isEmpty {
            html += Self.frontmatterCardHTML(fm)
        } else if let err = frontmatterError {
            html += "<div class=\"frontmatter-error\">\(Self.escapeHTML(err))</div>\n"
        }
        for block in document.blocks {
            html += convertBlock(block, baseFileURL: baseFileURL)
        }
        html += Self.htmlFooter
        // R3.3 — mermaid.js + inicialização (injetado apenas quando disponível)
        if !mermaidScriptTag.isEmpty {
            html += mermaidScriptTag
            html += Self.mermaidInitScript
        }
        return html
    }

    public func convertRawMarkdown(_ markdown: String, frontmatter: Frontmatter? = nil,
                                   frontmatterError: String? = nil, baseFileURL: URL? = nil,
                                   readingPrefs: ReadingPrefs? = nil) -> String
    {
        let result = FrontmatterExtractor.extract(from: markdown)
        let doc = MarkdownParser().parse(result.markdown)
        return convert(doc, frontmatter: result.frontmatter ?? frontmatter,
                       frontmatterError: result.error ?? frontmatterError,
                       baseFileURL: baseFileURL, readingPrefs: readingPrefs)
    }

    // MARK: - Block conversion

    public func convertBlock(_ block: any BlockNode, baseFileURL: URL?) -> String {
        switch block {
        case let h as HeadingNode:
            let tag = "h\(min(h.level, 6))"
            let id = uniqueSlug(Self.slugify(h.inlineText))
            let anchor = "<a class=\"anchor\" href=\"#\(id)\" onclick=\"copyAnchor(event, this)\" title=\"Copiar link para esta seção\" aria-label=\"Copiar link para esta seção\">#</a>"
            return "<\(tag) id=\"\(id)\">\(Self.escapeHTML(h.inlineText))\(anchor)</\(tag)>\n"
        case let p as ParagraphNode:
            return convertParagraph(p, baseFileURL: baseFileURL)
        case let c as CodeBlockNode:
            let lang = c.language ?? ""
            // R3.3 — blocos ```mermaid renderizam como diagramas inline
            if lang.lowercased() == "mermaid" {
                let escapedCode = Self.escapeHTML(c.code)
                    .replacingOccurrences(of: "'", with: "&#39;")
                return """
                <div class="mermaid-container"><div class="code-header"><span class="lang">MERMAID</span><button class="copy-btn" onclick="copyMermaidCode(this)" title="Copiar" aria-label="Copiar">\(Self.copyIcon)</button></div><pre class="mermaid-source" style="display:none">\(escapedCode)</pre><div class="mermaid">\n\(c.code)\n</div><div class="mermaid-error" style="display:none"></div></div>\n
                """
            }
            let highlighted = SyntaxHighlighter.highlight(c.code, language: lang)
            let lines = Self.lineCount(of: c.code)
            if lines > Self.foldLineThreshold {
                return """
                <div class="code-block folded"><div class="code-header"><span class="lang">\(Self.escapeHTML(lang))</span><span class="header-actions"><button class="fold-btn" onclick="toggleFold(this)" title="Mostrar tudo (\(lines) linhas)" aria-label="Mostrar tudo (\(lines) linhas)">\(Self.chevronDownIcon)</button><button class="copy-btn" onclick="copyCode(this)" title="Copiar" aria-label="Copiar">\(Self.copyIcon)</button></span></div><div class="code-scroll"><pre><code class="language-\(lang)">\(highlighted)</code></pre><div class="code-fade"></div></div></div>\n
                """
            }
            return """
            <div class="code-block"><div class="code-header"><span class="lang">\(Self.escapeHTML(lang))</span><button class="copy-btn" onclick="copyCode(this)" title="Copiar" aria-label="Copiar">\(Self.copyIcon)</button></div><pre><code class="language-\(lang)">\(highlighted)</code></pre></div>\n
            """
        case let q as QuoteNode:
            let paras = q.paragraphs.map { "<p>\(Self.escapeHTML($0))</p>" }.joined(separator: "\n")
            return "<blockquote>\(paras)</blockquote>\n"
        case let l as ListNode:
            return convertListHTML(l, baseURL: baseFileURL)
        case let t as TaskListItemsNode:
            return convertTaskListHTML(t, baseURL: baseFileURL)
        case let t as TableNode:
            return convertTableHTML(t, baseURL: baseFileURL)
        case is HorizontalRuleNode:
            return "<hr>\n"
        case let h as HTMLBlockNode:
            return h.rawHTML + "\n"
        case let a as AdmonitionNode:
            return convertAdmonition(a, baseFileURL: baseFileURL)
        case let g as GenericBlockNode:
            return "<p class=\"generic-block\">\(Self.escapeHTML(g.kindName))</p>\n"
        default:
            return ""
        }
    }

    // MARK: - List

    private func convertListHTML(_ list: ListNode, baseURL: URL?) -> String {
        let tag = list.isOrdered ? "ol" : (list.isTaskList ? "ul class=\"task-list\"" : "ul")
        var html = "<\(tag)>\n"
        for item in list.items {
            html += "  <li>\(Self.inlineMarkdown(item.text, baseURL: baseURL, brokenHrefs: brokenHrefs))"
            for child in item.children {
                html += convertListHTML(child, baseURL: baseURL).trimmingCharacters(in: .newlines)
            }
            html += "</li>\n"
        }
        html += "</\(list.isOrdered ? "ol" : "ul")>\n"
        return html
    }

    private func convertTaskListHTML(_ taskList: TaskListItemsNode, baseURL: URL?) -> String {
        var html = "<ul class=\"task-list\">\n"
        for item in taskList.items {
            let checked = item.isChecked ? " checked" : ""
            html += "  <li class=\"task-item\"><input type=\"checkbox\"\(checked) disabled><span class=\"task-text\">\(Self.inlineMarkdown(item.text, baseURL: baseURL, brokenHrefs: brokenHrefs))</span></li>\n"
        }
        html += "</ul>\n"
        return html
    }

    // MARK: - Table

    private func convertTableHTML(_ table: TableNode, baseURL: URL?) -> String {
        var html = "<div class=\"table-wrapper\"><table>\n<thead>\n<tr>\n"
        for cell in table.headerCells {
            html += "  <th>\(Self.inlineMarkdown(cell, baseURL: baseURL, brokenHrefs: brokenHrefs))</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"
        for row in table.rows {
            html += "<tr>\n"
            for cell in row {
                html += "  <td>\(Self.inlineMarkdown(cell, baseURL: baseURL, brokenHrefs: brokenHrefs))</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table></div>\n"
        return html
    }

    // MARK: - Paragraph with inline HTML

    private func convertParagraph(_ p: ParagraphNode, baseFileURL: URL?) -> String {
        let doc = Markdown.Document(parsing: p.rawMarkdown, options: [.disableSmartOpts])
        for child in doc.children {
            if let para = child as? Paragraph {
                if containsInlineHTML(para.inlineChildren) {
                    return "<p>\(renderInlineNodes(para.inlineChildren, baseURL: baseFileURL))</p>\n"
                }
                break
            }
        }
        return "<p>\(Self.inlineMarkdown(p.rawMarkdown, baseURL: baseFileURL, brokenHrefs: brokenHrefs))</p>\n"
    }

    private func containsInlineHTML(_ children: some Sequence<InlineMarkup>) -> Bool {
        for child in children {
            if child is InlineHTML {
                return true
            }
            if containsInlineHTMLInNode(child) {
                return true
            }
        }
        return false
    }

    private func containsInlineHTMLInNode(_ node: (any Markup)?) -> Bool {
        guard let node else { return false }
        for child in node.children {
            if child is InlineHTML {
                return true
            }
            if containsInlineHTMLInNode(child) {
                return true
            }
        }
        return false
    }

    private func escapeInlineText(_ children: some Sequence<InlineMarkup>) -> String {
        var text = ""
        for child in children {
            if let t = child as? Markdown.Text {
                text += t.string
            } else if let code = child as? Markdown.InlineCode {
                text += code.code
            } else {
                text += child.plainText
            }
        }
        return Self.escapeHTML(text)
    }

    private func renderInlineNodes(_ children: some Sequence<InlineMarkup>, baseURL: URL?) -> String {
        var html = ""
        for child in children {
            switch child {
            case let text as Markdown.Text:
                html += Self.inlineMarkdown(text.format(), baseURL: baseURL, brokenHrefs: brokenHrefs)
            case let inlineHTML as InlineHTML:
                html += inlineHTML.format()
            case let strong as Markdown.Strong:
                html += "<strong>\(renderInlineNodes(strong.inlineChildren, baseURL: baseURL))</strong>"
            case let emphasis as Markdown.Emphasis:
                html += "<em>\(renderInlineNodes(emphasis.inlineChildren, baseURL: baseURL))</em>"
            case let link as Markdown.Link:
                let href = link.destination ?? ""
                let broken = brokenHrefs.contains(href) ? Self.brokenAttr(href) : ""
                html += "<a href=\"\(href)\"\(broken)>\(renderInlineNodes(link.inlineChildren, baseURL: baseURL))</a>"
            case let code as Markdown.InlineCode:
                html += "<code>\(Self.escapeHTML(code.code))</code>"
            case let strikethrough as Markdown.Strikethrough:
                html += "<del>\(renderInlineNodes(strikethrough.inlineChildren, baseURL: baseURL))</del>"
            case let image as Markdown.Image:
                let href = image.source ?? ""
                let alt = escapeInlineText(image.inlineChildren)
                let src = Self.imageURLSource(href, baseURL: baseURL)
                let broken = brokenHrefs.contains(href) ? Self.brokenAttr(href) : ""
                html += "<img src=\"\(src)\" alt=\"\(alt)\"\(broken)>"
            default:
                html += Self.escapeHTML(child.format())
            }
        }
        return html
    }

    // MARK: - Admonition

    private static let admonitionIcons: [String: String] = [
        "note": """
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/><path d="M8 5v3.5M8 10.5v.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
        """,
        "tip": """
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M8 1.5a5 5 0 0 0-2 9.58V12a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-.92A5 5 0 0 0 8 1.5Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M6 14.5h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
        """,
        "important": """
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M8 1.5l6.5 13H1.5L8 1.5Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M8 6v3.5M8 11.5v.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
        """,
        "warning": """
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M8 1.5l6.5 13H1.5L8 1.5Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M8 6v3.5M8 11.5v.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
        """,
        "caution": """
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/><path d="M8 4.5v4M8 10.5v.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
        """,
    ]

    private func convertAdmonition(_ a: AdmonitionNode, baseFileURL: URL?) -> String {
        let icon = Self.admonitionIcons[a.type] ?? Self.admonitionIcons["note"]!
        let title = a.type.prefix(1).uppercased() + a.type.dropFirst()
        let bodyDoc = MarkdownParser().parse(a.body)
        var bodyHTML = ""
        for block in bodyDoc.blocks {
            bodyHTML += convertBlock(block, baseFileURL: baseFileURL)
        }
        if bodyHTML.isEmpty {
            bodyHTML = "<p>\(Self.escapeHTML(a.body))</p>\n"
        }
        return """
        <div class="admonition admonition-\(a.type)">\n\
        <div class="admonition-header">\(icon)<span class="admonition-title">\(Self.escapeHTML(title))</span></div>\n\
        <div class="admonition-body">\(bodyHTML)</div>\n\
        </div>\n
        """
    }

    // MARK: - Image src (R3.12)

    /// Resolve caminho de imagem: mantém URLs com scheme (http/data/file);
    /// resolve caminhos relativos contra a pasta do documento quando base presente.
    static func imageURLSource(_ href: String, baseURL: URL?) -> String {
        if let url = URL(string: href), url.scheme != nil {
            return href
        }
        guard let base = baseURL else { return href }
        return URL(fileURLWithPath: href, relativeTo: base.deletingLastPathComponent())
            .standardizedFileURL
            .absoluteString
    }

    // MARK: - Frontmatter

    public static func frontmatterCardHTML(_ fm: Frontmatter) -> String {
        var html = "<div class=\"frontmatter\"><table>"
        for field in fm.orderedFields {
            let value: String = switch field.value {
            case let .string(s): s
            case let .list(items): items.joined(separator: ", ")
            }
            html += "<tr><td class=\"fm-key\">\(escapeHTML(field.key))</td><td class=\"fm-value\">\(escapeHTML(value))</td></tr>"
        }
        html += "</table></div>\n"
        return html
    }

    // MARK: - Inline markdown to HTML

    /// R10.1 — atributos de marcação de link quebrado (data-broken decodifica
    /// para o href bruto, casando com LinkValidator.BrokenLink.href).
    private static func brokenAttr(_ rawHref: String) -> String {
        " class=\"broken-link\" data-broken=\"\(escapeHTML(rawHref))\""
    }

    /// Inverso mínimo de escapeHTML (&amp; &lt; &gt;) para comparar hrefs.
    static func unescapeBasic(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    static func inlineMarkdown(_ text: String, baseURL: URL? = nil, brokenHrefs: Set<String> = []) -> String {
        var result = escapeHTML(text)

        // Imagens: ![alt](url) — antes de links, senão o link engole o `!`
        let imagePattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
        if let imageRegex = try? NSRegularExpression(pattern: imagePattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = imageRegex.matches(in: result, options: [], range: range).reversed()
            for m in matches {
                let alt = ns.substring(with: m.range(at: 1))
                let href = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                let src = imageURLSource(href, baseURL: baseURL)
                let broken = brokenHrefs.contains(href) ? brokenAttr(href) : ""
                let replacement = "<img src=\"\(src)\" alt=\"\(alt)\"\(broken)>"
                result = (result as NSString).replacingCharacters(in: m.range, with: replacement)
            }
        }

        // Links: [text](url)
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = linkRegex.matches(in: result, options: [], range: range).reversed()
            for m in matches {
                let label = ns.substring(with: m.range(at: 1))
                let hrefEscaped = ns.substring(with: m.range(at: 2))
                // href no texto escapado (& vira &amp;): desescapa para casar com o href bruto
                let raw = Self.unescapeBasic(hrefEscaped).trimmingCharacters(in: .whitespaces)
                let broken = brokenHrefs.contains(raw) ? brokenAttr(raw) : ""
                let replacement = "<a href=\"\(hrefEscaped)\"\(broken)>\(label)</a>"
                result = (result as NSString).replacingCharacters(in: m.range, with: replacement)
            }
        }

        // Inline code: `code`
        let codePattern = #"`([^`]+)`"#
        if let codeRegex = try? NSRegularExpression(pattern: codePattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = codeRegex.stringByReplacingMatches(in: result, options: [], range: range,
                                                        withTemplate: "<code>$1</code>")
        }

        // Bold+Italic: ***text*** or ___text___
        let boldItalicPattern = #"(\*\*\*|___)(.+?)\1"#
        if let biRegex = try? NSRegularExpression(pattern: boldItalicPattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = biRegex.stringByReplacingMatches(in: result, options: [], range: range,
                                                      withTemplate: "<strong><em>$2</em></strong>")
        }

        // Bold: **text** or __text__
        let boldPattern = #"(\*\*|__)(.+?)\1"#
        if let bRegex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = bRegex.stringByReplacingMatches(in: result, options: [], range: range,
                                                     withTemplate: "<strong>$2</strong>")
        }

        // Italic: *text* or _text_
        let italicPattern = #"(\*|_)(.+?)\1"#
        if let iRegex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = iRegex.stringByReplacingMatches(in: result, options: [], range: range,
                                                     withTemplate: "<em>$2</em>")
        }

        // Strikethrough: ~~text~~ ou ~text~ (GFM aceita ambos)
        let strikePattern = #"(~{1,2})(.+?)\1"#
        if let sRegex = try? NSRegularExpression(pattern: strikePattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = sRegex.stringByReplacingMatches(in: result, options: [], range: range,
                                                     withTemplate: "<del>$2</del>")
        }

        return result
    }

    // MARK: - Syntax highlighting (delegado ao SyntaxHighlighter — R3.2)

    // MARK: - Code fold (R3.10)

    static let foldLineThreshold = 30

    static let copyIcon = """
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><rect x="5.5" y="5.5" width="8" height="8" rx="1.5" stroke="currentColor" stroke-width="1.5"/><path d="M10.5 3.5v-1A1.5 1.5 0 0 0 9 1H3A1.5 1.5 0 0 0 1.5 2.5v6A1.5 1.5 0 0 0 3 10h1.5" stroke="currentColor" stroke-width="1.5"/></svg>
    """

    static let checkIcon = """
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M3 8.5l3.5 3.5L13 4.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
    """

    static let chevronDownIcon = """
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M4 6l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
    """

    static let chevronUpIcon = """
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M4 10l4-4 4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
    """

    static func lineCount(of code: String) -> Int {
        var lines = code.components(separatedBy: "\n")
        if lines.count > 1, lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return max(lines.count, 1)
    }

    // MARK: - Helpers

    /// Mesma regra de dedup de DocumentOutline — ids do HTML precisam casar
    /// com os slugs do outline (TOC R3.7 e âncoras R3.8).
    private func uniqueSlug(_ slug: String) -> String {
        let n = headingSlugCounts[slug] ?? 0
        headingSlugCounts[slug] = n + 1
        return n == 0 ? slug : "\(slug)-\(n)"
    }

    static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        var out = ""
        var lastWasDash = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastWasDash = false
            } else if !lastWasDash {
                out.append("-")
                lastWasDash = true
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - HTML skeleton

    public static func htmlHeader(readingPrefs: ReadingPrefs? = nil) -> String {
        let fontSize = readingPrefs?.fontSize ?? ReadingPrefs.defaultFontSize
        let widthCh = readingPrefs?.widthCh ?? ReadingPrefs.defaultWidth
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        :root {
            --bg: #ffffff;
            --fg: #1f2328;
            --fg-secondary: #656d76;
            --border: #d1d9e0;
            --code-bg: #f6f8fa;
            --blockquote-border: #d1d9e0;
            --table-border: #d1d9e0;
            --table-header-bg: #f6f8fa;
            --link-color: #0969da;
            --broken-color: #b45309;
            --broken-flash-bg: rgba(234, 164, 57, .35);
            --code-keyword: #cf222e;
            --code-string: #0a3069;
            --code-comment: #6e7781;
            --code-number: #0550ae;
            --code-operator: #0550ae;
            --code-function: #8250df;
            --code-type: #953800;
            --reading-font-size: \(fontSize)px;
            --reading-width: \(widthCh)ch;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #0d1117;
                --fg: #e6edf3;
                --fg-secondary: #8b949e;
                --border: #30363d;
                --code-bg: #161b22;
                --blockquote-border: #30363d;
                --table-border: #30363d;
                --table-header-bg: #161b22;
                --link-color: #58a6ff;
                --broken-color: #e3b341;
                --broken-flash-bg: rgba(227, 179, 65, .30);
                --code-keyword: #ff7b72;
                --code-string: #a5d6ff;
                --code-comment: #8b949e;
                --code-number: #79c0ff;
                --code-operator: #79c0ff;
                --code-function: #d2a8ff;
                --code-type: #ffa657;
            }
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: var(--fg);
            background: var(--bg);
            padding: 16px 24px;
            word-wrap: break-word;
            overflow-wrap: break-word;
            max-width: var(--reading-width, 70ch);
            margin: 0 auto;
        }
        body > * {
            font-size: var(--reading-font-size, 16px);
        }
        h1 { font-size: 2em; font-weight: 600; margin: 0.67em 0 0.43em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
        h2 { font-size: 1.5em; font-weight: 600; margin: 1em 0 0.43em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
        h3 { font-size: 1.25em; font-weight: 600; margin: 1em 0 0.43em; }
        h4 { font-size: 1em; font-weight: 600; margin: 1em 0 0.43em; }
        h5 { font-size: 0.875em; font-weight: 600; margin: 1em 0 0.43em; }
        h6 { font-size: 0.85em; font-weight: 600; margin: 1em 0 0.43em; color: var(--fg-secondary); }
        .anchor {
            opacity: 0;
            margin-left: 8px;
            color: var(--link-color);
            text-decoration: none;
            font-weight: 400;
            user-select: none;
        }
        :is(h1,h2,h3,h4,h5,h6):hover .anchor, .anchor:focus { opacity: 1; }
        p { margin: 0 0 16px; }
        a { color: var(--link-color); text-decoration: none; }
        a:hover { text-decoration: underline; }
        a.broken-link { color: var(--broken-color); text-decoration: underline wavy; text-underline-offset: 3px; }
        img.broken-link { outline: 2px dashed var(--broken-color); outline-offset: 2px; border-radius: 2px; opacity: .75; }
        @keyframes brokenFlash { 0%,60% { background-color: var(--broken-flash-bg); } 100% { background-color: transparent; } }
        .broken-flash { animation: brokenFlash 1.6s ease; }
        strong { font-weight: 600; }
        del { text-decoration: line-through; color: var(--fg-secondary); }
        code {
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 85%;
            background: var(--code-bg);
            padding: 0.2em 0.4em;
            border-radius: 6px;
        }
        pre {
            margin: 0 0 16px;
            padding: 16px;
            overflow: auto;
            background: var(--code-bg);
            border-radius: 6px;
            line-height: 1.45;
        }
        pre code {
            background: none;
            padding: 0;
            font-size: 100%;
        }
        .code-block { margin: 0 0 16px; }
        .code-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 16px;
            background: var(--code-bg);
            border: 1px solid var(--border);
            border-bottom: none;
            border-radius: 6px 6px 0 0;
            font-size: 12px;
        }
        .code-header + pre { margin-top: 0; border-radius: 0 0 6px 6px; }
        .header-actions { display: flex; gap: 8px; }
        .code-scroll { position: relative; border-radius: 0 0 6px 6px; }
        .code-header + .code-scroll { margin-top: 0; border-radius: 0 0 6px 6px; }
        .code-block.folded pre {
            max-height: 500px;
            overflow-y: auto;
            overflow-x: auto;
        }
        .code-header + .code-scroll pre { margin-top: 0; margin-bottom: 0; border-radius: 0 0 6px 6px; }
        .code-block.folded .code-fade {
            position: absolute;
            left: 0; right: 0; bottom: 0;
            height: 60px;
            background: linear-gradient(to bottom, transparent, var(--code-bg));
            pointer-events: none;
            opacity: var(--fold-gradient, 1);
            transition: opacity 0.15s;
            border-radius: 0 0 6px 6px;
        }
        .fold-btn {
            background: none;
            border: none;
            color: var(--fg-secondary);
            padding: 2px 4px;
            border-radius: 4px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            line-height: 0;
        }
        .fold-btn:hover { color: var(--fg); background: rgba(128, 128, 128, 0.15); }
        .lang { color: var(--fg-secondary); text-transform: uppercase; font-weight: 500; letter-spacing: 0.5px; }
        .copy-btn {
            background: none;
            border: none;
            color: var(--fg-secondary);
            padding: 2px 4px;
            border-radius: 4px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            line-height: 0;
        }
        .copy-btn:hover { color: var(--fg); background: rgba(128, 128, 128, 0.15); }
        .kw { color: var(--code-keyword); }
        .st { color: var(--code-string); }
        .cm { color: var(--code-comment); font-style: italic; }
        .num { color: var(--code-number); }
        .op { color: var(--code-operator); }
        .fn { color: var(--code-function); }
        .ty { color: var(--code-type); }
        img { max-width: 100%; height: auto; border-radius: 6px; }
        img + h1 { margin-top: 0; }
        blockquote {
            margin: 0 0 16px;
            padding: 0 1em;
            color: var(--fg-secondary);
            border-left: 0.25em solid var(--blockquote-border);
        }
        blockquote p:last-child { margin-bottom: 0; }
        ul, ol { margin: 0 0 16px; padding-left: 2em; }
        li > ul, li > ol { margin-bottom: 0; }
        li { margin: 0.25em 0; }
        li + li { margin-top: 0.25em; }
        .task-list { list-style: none; padding-left: 0; }
        .task-item { display: flex; align-items: flex-start; gap: 8px; }
        .task-item input[type="checkbox"] { margin: 0.4em 0 0; flex-shrink: 0; }
        .task-text { flex: 1; min-width: 0; }
        hr {
            height: 0.25em;
            padding: 0;
            margin: 1em 0;
            background-color: var(--border);
            border: 0;
            border-radius: 2px;
        }
        .table-wrapper { overflow-x: auto; margin: 0 0 16px; }
        table {
            border-collapse: collapse;
            border-spacing: 0;
            display: block;
            width: max-content;
            max-width: 100%;
            overflow: auto;
        }
        th, td {
            padding: 6px 13px;
            border: 1px solid var(--table-border);
        }
        th { font-weight: 600; background: var(--table-header-bg); }
        tr { background: var(--bg); border-top: 1px solid var(--table-border); }
        tr:nth-child(2n) { background: var(--code-bg); }
        .frontmatter {
            margin: 0 0 24px;
            padding: 16px;
            background: var(--code-bg);
            border: 1px solid var(--border);
            border-radius: 6px;
        }
        .frontmatter table { border-collapse: collapse; }
        .frontmatter td { padding: 4px 12px 4px 0; border: none; vertical-align: top; }
        .fm-key { font-weight: 600; white-space: nowrap; color: var(--fg-secondary); }
        .fm-value { color: var(--fg); }
        .frontmatter-error {
            margin: 0 0 16px;
            padding: 12px 16px;
            background: #fff3cd;
            color: #664d03;
            border: 1px solid #ffecb5;
            border-radius: 6px;
        }
        @media (prefers-color-scheme: dark) {
            .frontmatter-error { background: #3b2e00; color: #f0c000; border-color: #5a4500; }
        }
        .generic-block {
            padding: 8px 12px;
            background: var(--code-bg);
            border: 1px dashed var(--border);
            border-radius: 4px;
            color: var(--fg-secondary);
            font-size: 0.9em;
        }
        .admonition {
            margin: 0 0 16px;
            padding: 12px 16px;
            border-radius: 6px;
            border-left: 4px solid var(--border);
            background: var(--code-bg);
        }
        .admonition-header {
            display: flex;
            align-items: center;
            gap: 6px;
            margin-bottom: 8px;
            color: var(--fg);
        }
        .admonition-title {
            font-weight: 600;
            font-size: 0.95em;
        }
        .admonition-body p:last-child { margin-bottom: 0; }
        .admonition-note { border-left-color: #0969da; }
        .admonition-tip { border-left-color: #1a7f37; }
        .admonition-important { border-left-color: #8250df; }
        .admonition-warning { border-left-color: #bf8700; }
        .admonition-caution { border-left-color: #cf222e; }
        @media (prefers-color-scheme: dark) {
            .admonition-note { border-left-color: #58a6ff; }
            .admonition-tip { border-left-color: #3fb950; }
            .admonition-important { border-left-color: #d2a8ff; }
            .admonition-warning { border-left-color: #d29922; }
            .admonition-caution { border-left-color: #f85149; }
        }
        .search-match { background: rgba(255, 213, 0, 0.4); border-radius: 2px; }
        .search-current { background: rgba(255, 145, 0, 0.5); border-radius: 2px; }
        .diff-added { background: rgba(46, 160, 67, 0.15); border-left: 3px solid #2ea043; padding-left: 12px; }
        .diff-added-strong { background: rgba(46, 160, 67, 0.28); border-left: 3px solid #2ea043; padding-left: 12px; }
        .diff-removed { background: rgba(248, 81, 73, 0.15); border-left: 3px solid #f85149; padding-left: 12px; text-decoration: line-through; color: var(--fg-secondary); padding: 8px 12px; margin: 4px 0; border-radius: 4px; }
        /* R3.3 — Mermaid diagram containers */
        .mermaid-container { margin: 0 0 16px; border: 1px solid var(--border); border-radius: 6px; overflow: hidden; }
        .mermaid-container .mermaid { padding: 16px; text-align: center; overflow-x: auto; }
        .mermaid-container .mermaid svg { max-width: 100%; height: auto; }
        .mermaid-source { display: none; }
        /* R10.1 — Mermaid error state */
        .mermaid-error {
            padding: 12px 16px;
            background: #fff3cd;
            color: #664d03;
            border-top: 1px solid #ffecb5;
            font-size: 0.9em;
            white-space: pre-wrap;
        }
        @media (prefers-color-scheme: dark) {
            .mermaid-error { background: #3b2e00; color: #f0c000; border-color: #5a4500; }
        }
        .mermaid-error::before { content: "⚠ "; }
        </style>
        </head>
        <body>
        """
    }

    public static let htmlFooter = """
    <script>
    var COPY_ICON = '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><rect x="5.5" y="5.5" width="8" height="8" rx="1.5" stroke="currentColor" stroke-width="1.5"/><path d="M10.5 3.5v-1A1.5 1.5 0 0 0 9 1H3A1.5 1.5 0 0 0 1.5 2.5v6A1.5 1.5 0 0 0 3 10h1.5" stroke="currentColor" stroke-width="1.5"/></svg>';
    var CHECK_ICON = '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M3 8.5l3.5 3.5L13 4.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    var CHEVRON_DOWN = '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M4 6l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    var CHEVRON_UP = '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M4 10l4-4 4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    function copyCode(btn) {
        var code = btn.closest('.code-block').querySelector('code');
        navigator.clipboard.writeText(code.textContent);
        btn.innerHTML = CHECK_ICON;
        btn.setAttribute('aria-label', 'Copiado!');
        setTimeout(function() {
            btn.innerHTML = COPY_ICON;
            btn.setAttribute('aria-label', 'Copiar');
        }, 1500);
    }
    function copyAnchor(event, el) {
        var id = el.parentNode.id;
        var url = (typeof BASE_URL !== 'undefined' && BASE_URL) ? BASE_URL + '#' + id : '#' + id;
        navigator.clipboard.writeText(url);
        var original = el.textContent;
        el.textContent = '✓';
        setTimeout(function() { el.textContent = original; }, 1200);
    }
    function toggleFold(btn) {
        var block = btn.closest('.code-block');
        var folded = block.classList.toggle('folded');
        btn.innerHTML = folded ? CHEVRON_DOWN : CHEVRON_UP;
        btn.setAttribute('aria-label', folded ? 'Mostrar tudo' : 'Recolher');
        btn.setAttribute('title', folded ? 'Mostrar tudo' : 'Recolher');
        if (folded) {
            checkCodeBlockScroll(block.querySelector('pre'));
        }
    }
    function checkCodeBlockScroll(pre) {
        var atBottom = pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 2;
        var block = pre.closest('.code-block');
        if (block) block.style.setProperty('--fold-gradient', atBottom ? '0' : '1');
    }
    function initCodeBlockScroll() {
        document.querySelectorAll('.code-block.folded pre').forEach(function(pre) {
            pre.addEventListener('scroll', function() {
                checkCodeBlockScroll(pre);
            });
            pre.addEventListener('wheel', function() {
                requestAnimationFrame(function() { checkCodeBlockScroll(pre); });
            });
            requestAnimationFrame(function() { checkCodeBlockScroll(pre); });
        });
    }
    initCodeBlockScroll();
    </script>
    </body>
    </html>
    """

    /// R3.3 — script de inicialização do mermaid (injetado quando mermaid.js disponível)
    public static let mermaidInitScript = """
    <script>
    document.addEventListener('DOMContentLoaded', function() {
        if (typeof mermaid === 'undefined') return;
        mermaid.initialize({
            startOnLoad: false,
            theme: document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'default',
            securityLevel: 'loose',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
        });
        var containers = document.querySelectorAll('.mermaid-container');
        var errorCount = 0;
        containers.forEach(function(container, idx) {
            var div = container.querySelector('.mermaid');
            var errorDiv = container.querySelector('.mermaid-error');
            if (!div) return;
            try {
                var id = 'mermaid-' + idx;
                mermaid.render(id, div.textContent.trim()).then(function(result) {
                    div.innerHTML = result.svg;
                }).catch(function(err) {
                    div.style.display = 'none';
                    errorCount++;
                    if (errorDiv) {
                        errorDiv.textContent = 'Mermaid syntax error: ' + (err.message || err.str || String(err));
                        errorDiv.style.display = 'block';
                    }
                    try { window.webkit.messageHandlers.macDownMermaidError.postMessage(errorCount); } catch(e) {}
                });
            } catch(e) {
                div.style.display = 'none';
                errorCount++;
                if (errorDiv) {
                    errorDiv.textContent = 'Mermaid syntax error: ' + (e.message || String(e));
                    errorDiv.style.display = 'block';
                }
                try { window.webkit.messageHandlers.macDownMermaidError.postMessage(errorCount); } catch(e2) {}
            }
        });
    });
    function copyMermaidCode(btn) {
        var container = btn.closest('.mermaid-container');
        var source = container.querySelector('.mermaid-source');
        if (source) {
            navigator.clipboard.writeText(source.textContent);
        } else {
            var div = container.querySelector('.mermaid');
            if (div) navigator.clipboard.writeText(div.textContent);
        }
        btn.innerHTML = CHECK_ICON;
        btn.setAttribute('aria-label', 'Copiado!');
        setTimeout(function() {
            btn.innerHTML = COPY_ICON;
            btn.setAttribute('aria-label', 'Copiar');
        }, 1500);
    }
    </script>
    """
}
