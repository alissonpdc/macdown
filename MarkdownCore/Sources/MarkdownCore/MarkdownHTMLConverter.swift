import Foundation
import Markdown

public struct MarkdownHTMLConverter {
    public init() {}

    public func convert(_ document: CoreDocument, frontmatter: Frontmatter? = nil,
                        frontmatterError: String? = nil, baseFileURL: URL? = nil,
                        readingPrefs: ReadingPrefs? = nil) -> String {
        var html = Self.htmlHeader(readingPrefs: readingPrefs)
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
            let id = Self.slugify(h.inlineText)
            return "<\(tag) id=\"\(id)\">\(Self.escapeHTML(h.inlineText))</\(tag)>\n"
        case let p as ParagraphNode:
            return "<p>\(Self.inlineMarkdown(p.rawMarkdown))</p>\n"
        case let c as CodeBlockNode:
            let lang = c.language ?? ""
            let highlighted = Self.syntaxHighlight(Self.escapeHTML(c.code), language: lang)
            return """
            <div class="code-block"><div class="code-header"><span class="lang">\(Self.escapeHTML(lang))</span><button class="copy-btn" onclick="copyCode(this)">Copiar</button></div><pre><code class="language-\(lang)">\(highlighted)</code></pre></div>\n
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

    // MARK: - Syntax highlighting (basic)

    private static func syntaxHighlight(_ code: String, language: String) -> String {
        guard !language.isEmpty else { return code }
        let keywords: [String: [String]] = [
            "swift": ["func", "let", "var", "if", "else", "return", "class", "struct", "enum", "protocol",
                       "import", "public", "private", "static", "override", "init", "self", "true", "false",
                       "for", "while", "switch", "case", "break", "continue", "nil", "guard", "defer",
                       "try", "catch", "throws", "async", "await", "some", "any"],
            "python": ["def", "class", "if", "else", "elif", "return", "import", "from", "as", "with",
                        "try", "except", "finally", "for", "while", "True", "False", "None", "and", "or",
                        "not", "in", "is", "lambda", "yield", "pass", "break", "continue", "raise"],
            "javascript": ["function", "const", "let", "var", "if", "else", "return", "class", "extends",
                            "import", "export", "from", "default", "new", "this", "true", "false", "null",
                            "for", "while", "switch", "case", "break", "continue", "try", "catch", "async",
                            "await", "yield", "typeof", "instanceof"],
            "bash": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac",
                      "function", "return", "exit", "echo", "export", "source", "local", "readonly",
                      "declare", "set", "unset", "shift", "exec", "eval"],
            "sh": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac",
                    "function", "return", "exit", "echo", "export", "source", "local", "readonly"],
            "zsh": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac",
                     "function", "return", "exit", "echo", "export", "source", "local", "readonly"],
            "html": ["html", "head", "body", "div", "span", "p", "a", "h1", "h2", "h3", "h4", "h5", "h6",
                      "ul", "ol", "li", "table", "tr", "td", "th", "pre", "code", "img", "link", "script",
                      "style", "meta", "title"],
            "css": ["color", "background", "margin", "padding", "border", "font", "display", "position",
                     "width", "height", "top", "left", "right", "bottom", "flex", "grid"],
            "rust": ["fn", "let", "mut", "if", "else", "return", "struct", "enum", "impl", "trait",
                      "pub", "use", "mod", "self", "true", "false", "for", "while", "loop", "match",
                      "break", "continue", "move", "ref", "async", "await", "where", "type"],
            "go": ["func", "var", "const", "if", "else", "return", "struct", "interface", "package",
                    "import", "type", "map", "chan", "go", "select", "case", "default", "for", "range",
                    "break", "continue", "defer", "true", "false", "nil"],
            "json": [],
            "yaml": [],
        ]

        let langKeywords = keywords[language.lowercased()] ?? []
        guard !langKeywords.isEmpty else { return code }

        var result = code
        let pattern = "\\b(\(langKeywords.joined(separator: "|")))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return result }
        let ns = result as NSString
        let range = NSRange(location: 0, length: ns.length)
        result = regex.stringByReplacingMatches(in: result, options: [], range: range,
                                                withTemplate: "<span class=\"kw\">$1</span>")

        let commentPattern: String
        switch language.lowercased() {
        case "swift", "rust", "go", "javascript":
            commentPattern = "(//[^\\n]*)"
        case "python", "yaml", "bash", "sh", "zsh":
            commentPattern = "(#[^\\n]*)"
        default:
            commentPattern = ""
        }
        if !commentPattern.isEmpty, let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: []) {
            let ns2 = result as NSString
            let range2 = NSRange(location: 0, length: ns2.length)
            result = commentRegex.stringByReplacingMatches(in: result, options: [], range: range2,
                                                           withTemplate: "<span class=\"cm\">$1</span>")
        }

        let stringPattern = "(\"[^\"]*\")"
        if let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: []) {
            let ns3 = result as NSString
            let range3 = NSRange(location: 0, length: ns3.length)
            result = stringRegex.stringByReplacingMatches(in: result, options: [], range: range3,
                                                          withTemplate: "<span class=\"st\">$1</span>")
        }

        return result
    }

    // MARK: - Helpers

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
        }
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
        font-size: var(--reading-font-size, 16px);
        line-height: 1.6;
        color: var(--fg);
        background: var(--bg);
        padding: 16px 24px;
        word-wrap: break-word;
        overflow-wrap: break-word;
        display: flex;
        flex-direction: column;
        align-items: center;
    }
    body > * {
        max-width: var(--reading-width, 70ch);
        width: 100%;
    }
    h1 { font-size: 2em; font-weight: 600; margin: 0.67em 0 0.43em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
    h2 { font-size: 1.5em; font-weight: 600; margin: 1em 0 0.43em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
    h3 { font-size: 1.25em; font-weight: 600; margin: 1em 0 0.43em; }
    h4 { font-size: 1em; font-weight: 600; margin: 1em 0 0.43em; }
    h5 { font-size: 0.875em; font-weight: 600; margin: 1em 0 0.43em; }
    h6 { font-size: 0.85em; font-weight: 600; margin: 1em 0 0.43em; color: var(--fg-secondary); }
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
    .lang { color: var(--fg-secondary); text-transform: uppercase; font-weight: 500; letter-spacing: 0.5px; }
    .copy-btn {
        background: none;
        border: 1px solid var(--border);
        color: var(--fg-secondary);
        padding: 2px 8px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 12px;
    }
    .copy-btn:hover { color: var(--fg); border-color: var(--fg-secondary); }
    .kw { color: var(--code-keyword); }
    .st { color: var(--code-string); }
    .cm { color: var(--code-comment); font-style: italic; }
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
    function copyCode(btn) {
        var code = btn.closest('.code-block').querySelector('code');
        navigator.clipboard.writeText(code.textContent);
        btn.textContent = 'Copiado!';
        setTimeout(function() { btn.textContent = 'Copiar'; }, 1500);
    }
    </script>
    </body>
    </html>
    """
}
