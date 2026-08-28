import Foundation
import Markdown

/// Classe (não struct) porque o contador de slugs duplicados precisa sobreviver
/// entre chamadas de convertBlock durante a conversão de um mesmo documento.
public final class MarkdownHTMLConverter {
    public init() {}

    private var headingSlugCounts: [String: Int] = [:]

    public func convert(_ document: CoreDocument, frontmatter: Frontmatter? = nil,
                        frontmatterError: String? = nil, baseFileURL: URL? = nil,
                        readingPrefs: ReadingPrefs? = nil) -> String {
        var html = Self.htmlHeader(readingPrefs: readingPrefs)
        if let base = baseFileURL {
            let escaped = Self.escapeHTML(base.absoluteString)
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
        return html
    }

    public func convertRawMarkdown(_ markdown: String, frontmatter: Frontmatter? = nil,
                                   frontmatterError: String? = nil, baseFileURL: URL? = nil,
                                   readingPrefs: ReadingPrefs? = nil) -> String {
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
            return "<\(tag) id=\"\(id)\">\(anchor)\(Self.escapeHTML(h.inlineText))</\(tag)>\n"
        case let p as ParagraphNode:
            return "<p>\(Self.inlineMarkdown(p.rawMarkdown))</p>\n"
        case let c as CodeBlockNode:
            let lang = c.language ?? ""
            let highlighted = SyntaxHighlighter.highlight(c.code, language: lang)
            let lines = Self.lineCount(of: c.code)
            if lines > Self.foldLineThreshold {
                return """
                <div class="code-block folded"><div class="code-header"><span class="lang">\(Self.escapeHTML(lang))</span><span class="header-actions"><button class="fold-btn" onclick="toggleFold(this)" title="Mostrar tudo (\(lines) linhas)" aria-label="Mostrar tudo (\(lines) linhas)">\(Self.chevronDownIcon)</button><button class="copy-btn" onclick="copyCode(this)" title="Copiar" aria-label="Copiar">\(Self.copyIcon)</button></span></div><pre><code class="language-\(lang)">\(highlighted)</code></pre></div>\n
                """
            }
            return """
            <div class="code-block"><div class="code-header"><span class="lang">\(Self.escapeHTML(lang))</span><button class="copy-btn" onclick="copyCode(this)" title="Copiar" aria-label="Copiar">\(Self.copyIcon)</button></div><pre><code class="language-\(lang)">\(highlighted)</code></pre></div>\n
            """
        case let q as QuoteNode:
            return "<blockquote><p>\(Self.escapeHTML(q.plainText))</p></blockquote>\n"
        case let l as ListNode:
            return Self.convertListHTML(l)
        case let t as TaskListItemsNode:
            return Self.convertTaskListHTML(t)
        case let t as TableNode:
            return Self.convertTableHTML(t)
        case is HorizontalRuleNode:
            return "<hr>\n"
        case let g as GenericBlockNode:
            return "<p class=\"generic-block\">\(Self.escapeHTML(g.kindName))</p>\n"
        default:
            return ""
        }
    }

    // MARK: - List

    private static func convertListHTML(_ list: ListNode) -> String {
        let tag = list.isTaskList ? "ul class=\"task-list\"" : "ul"
        var html = "<\(tag)>\n"
        for item in list.items {
            html += "  <li>\(inlineMarkdown(item))</li>\n"
        }
        html += "</ul>\n"
        return html
    }

    private static func convertTaskListHTML(_ taskList: TaskListItemsNode) -> String {
        var html = "<ul class=\"task-list\">\n"
        for item in taskList.items {
            let checked = item.isChecked ? " checked" : ""
            html += "  <li class=\"task-item\"><input type=\"checkbox\"\(checked) disabled>\(inlineMarkdown(item.text))</li>\n"
        }
        html += "</ul>\n"
        return html
    }

    // MARK: - Table

    private static func convertTableHTML(_ table: TableNode) -> String {
        var html = "<div class=\"table-wrapper\"><table>\n<thead>\n<tr>\n"
        for cell in table.headerCells {
            html += "  <th>\(inlineMarkdown(cell))</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"
        for row in table.rows {
            html += "<tr>\n"
            for cell in row {
                html += "  <td>\(inlineMarkdown(cell))</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table></div>\n"
        return html
    }

    // MARK: - Frontmatter

    public static func frontmatterCardHTML(_ fm: Frontmatter) -> String {
        var html = "<div class=\"frontmatter\"><table>"
        for field in fm.orderedFields {
            let value: String
            switch field.value {
            case .string(let s): value = s
            case .list(let items): value = items.joined(separator: ", ")
            }
            html += "<tr><td class=\"fm-key\">\(escapeHTML(field.key))</td><td class=\"fm-value\">\(escapeHTML(value))</td></tr>"
        }
        html += "</table></div>\n"
        return html
    }

    // MARK: - Inline markdown to HTML

    static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)

        // Links: [text](url)
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = linkRegex.stringByReplacingMatches(in: result, options: [], range: range,
                withTemplate: "<a href=\"$2\">$1</a>")
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

        // Strikethrough: ~~text~~
        let strikePattern = #"~~(.+?)~~"#
        if let sRegex = try? NSRegularExpression(pattern: strikePattern, options: []) {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            result = sRegex.stringByReplacingMatches(in: result, options: [], range: range,
                withTemplate: "<del>$1</del>")
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
        margin-right: 8px;
        color: var(--link-color);
        text-decoration: none;
        font-weight: 400;
        user-select: none;
    }
    :is(h1,h2,h3,h4,h5,h6):hover .anchor, .anchor:focus { opacity: 1; }
    p { margin: 0 0 16px; }
    a { color: var(--link-color); text-decoration: none; }
    a:hover { text-decoration: underline; }
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
    .code-block.folded pre {
        max-height: 500px;
        overflow-y: auto;
        overflow-x: auto;
        position: relative;
    }
    .code-block.folded pre::after {
        content: "";
        position: absolute;
        left: 0; right: 0; bottom: 0;
        height: 60px;
        background: linear-gradient(to bottom, transparent, var(--code-bg));
        pointer-events: none;
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
    blockquote {
        margin: 0 0 16px;
        padding: 0 1em;
        color: var(--fg-secondary);
        border-left: 0.25em solid var(--blockquote-border);
    }
    blockquote p:last-child { margin-bottom: 0; }
    ul, ol { margin: 0 0 16px; padding-left: 2em; }
    li { margin: 0.25em 0; }
    li + li { margin-top: 0.25em; }
    .task-list { list-style: none; padding-left: 0; }
    .task-item { display: flex; align-items: center; gap: 8px; }
    .task-item input[type="checkbox"] { margin: 0; }
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
    .search-match { background: rgba(255, 213, 0, 0.4); border-radius: 2px; }
    .search-current { background: rgba(255, 145, 0, 0.5); border-radius: 2px; }
    .diff-added { background: rgba(46, 160, 67, 0.15); border-left: 3px solid #2ea043; padding-left: 12px; }
    .diff-added-strong { background: rgba(46, 160, 67, 0.28); border-left: 3px solid #2ea043; padding-left: 12px; }
    .diff-removed { background: rgba(248, 81, 73, 0.15); border-left: 3px solid #f85149; padding-left: 12px; text-decoration: line-through; color: var(--fg-secondary); padding: 8px 12px; margin: 4px 0; border-radius: 4px; }
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
    }
    </script>
    </body>
    </html>
    """
}
