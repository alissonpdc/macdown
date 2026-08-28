import Foundation

/// R3.2 — tokenizer de uma passada para syntax highlighting.
/// Regras por linguagem, avaliadas ancoradas na posição corrente: a primeira
/// que casa consome o token; texto restante é consumido caractere a caractere
/// (já escapado). Nunca destaca dentro de strings ou comentários.
public enum SyntaxHighlighter {
    struct Language {
        var keywords: Set<String> = []
        var keywordsCaseInsensitive = false
        var lineComment: String?
        var blockComment: (open: String, close: String)?
        var strings: [String] = []
        var multilineStrings: Set<String> = [] // python: """/'''
        var capitalizedTypes = false
        var variablePrefix = false             // bash: $VAR
        var extraRules: [Rule] = []
    }

    struct Rule {
        let regex: NSRegularExpression
        let cls: String
    }

    static func rule(_ pattern: String, _ cls: String,
                     _ options: NSRegularExpression.Options = []) -> Rule? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        return Rule(regex: regex, cls: cls)
    }

    // MARK: - Definições de linguagem

    static let languages: [String: Language] = {
        var langs: [String: Language] = [:]

        func cLike(_ kw: [String]) -> Language {
            var l = Language()
            l.keywords = Set(kw)
            l.lineComment = "//"
            l.blockComment = ("/*", "*/")
            l.strings = ["\"", "'"]
            l.capitalizedTypes = true
            return l
        }

        langs["swift"] = cLike(["func", "let", "var", "if", "else", "return", "class", "struct",
            "enum", "protocol", "extension", "import", "public", "private", "internal", "fileprivate",
            "static", "override", "init", "deinit", "self", "super", "true", "false", "nil", "for",
            "while", "repeat", "switch", "case", "default", "break", "continue", "guard", "defer",
            "try", "catch", "throw", "throws", "rethrows", "async", "await", "some", "any", "where",
            "in", "inout", "mutating", "lazy", "weak", "unowned", "operator", "typealias",
            "associatedtype", "indirect", "final", "required", "convenience", "didSet", "willSet",
            "get", "set"])

        langs["c"] = cLike(["int", "char", "float", "double", "void", "long", "short", "unsigned",
            "signed", "const", "static", "struct", "enum", "union", "typedef", "sizeof", "return",
            "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
            "goto", "extern", "inline", "volatile", "register", "auto"])
        langs["cpp"] = langs["c"]!
        for extra in ["class", "namespace", "template", "typename", "public", "private", "protected",
                      "virtual", "new", "delete", "try", "catch", "throw", "using", "bool", "true",
                      "false", "this", "operator", "override", "final", "auto", "nullptr"] {
            langs["cpp"]!.keywords.insert(extra)
        }
        langs["objc"] = langs["c"]!
        for extra in ["@interface", "@implementation", "@property", "@end", "@class", "@protocol",
                      "id", "nil", "YES", "NO", "self", "super"] {
            langs["objc"]!.keywords.insert(extra)
        }

        langs["java"] = cLike(["public", "private", "protected", "class", "interface", "extends",
            "implements", "static", "final", "void", "int", "long", "double", "float", "boolean",
            "char", "byte", "short", "new", "return", "if", "else", "for", "while", "do", "switch",
            "case", "default", "break", "continue", "try", "catch", "finally", "throw", "throws",
            "import", "package", "this", "super", "null", "true", "false", "instanceof", "abstract",
            "synchronized", "volatile", "transient", "enum", "record", "var"])

        langs["kotlin"] = cLike(["fun", "val", "var", "if", "else", "return", "class", "object",
            "interface", "when", "for", "while", "break", "continue", "null", "true", "false", "is",
            "in", "as", "import", "package", "private", "public", "internal", "protected", "override",
            "open", "data", "sealed", "suspend", "companion", "init", "this", "super", "try", "catch",
            "finally", "throw", "lateinit", "by", "typealias"])

        langs["csharp"] = cLike(["using", "namespace", "class", "struct", "interface", "enum",
            "public", "private", "protected", "internal", "static", "void", "int", "long", "double",
            "float", "bool", "string", "char", "var", "new", "return", "if", "else", "for", "foreach",
            "while", "do", "switch", "case", "default", "break", "continue", "try", "catch", "finally",
            "throw", "this", "base", "null", "true", "false", "override", "virtual", "abstract",
            "sealed", "async", "await", "readonly", "const", "out", "ref", "in", "is", "as"])

        langs["javascript"] = cLike(["function", "const", "let", "var", "if", "else", "return",
            "class", "extends", "import", "export", "from", "default", "new", "this", "true", "false",
            "null", "undefined", "for", "of", "in", "while", "do", "switch", "case", "default",
            "break", "continue", "try", "catch", "finally", "throw", "async", "await", "yield",
            "typeof", "instanceof", "delete", "void", "static", "get", "set"])
        langs["typescript"] = langs["javascript"]!
        for extra in ["type", "interface", "enum", "namespace", "declare", "implements", "readonly",
                      "abstract", "public", "private", "protected", "as", "satisfies", "keyof", "infer"] {
            langs["typescript"]!.keywords.insert(extra)
        }

        langs["rust"] = cLike(["fn", "let", "mut", "const", "if", "else", "return", "struct", "enum",
            "impl", "trait", "pub", "use", "mod", "self", "super", "true", "false", "for", "in",
            "while", "loop", "match", "break", "continue", "move", "ref", "async", "await", "where",
            "type", "unsafe", "dyn", "crate", "as", "static", "extern", "box", "union"])
        langs["rust"]!.strings.append("`")

        langs["go"] = cLike(["func", "var", "const", "if", "else", "return", "struct", "interface",
            "package", "import", "type", "map", "chan", "go", "select", "case", "default", "for",
            "range", "break", "continue", "defer", "true", "false", "nil", "switch", "fallthrough",
            "goto"])
        langs["go"]!.strings.append("`")

        langs["php"] = cLike(["function", "return", "if", "else", "elseif", "foreach", "for", "while",
            "do", "switch", "case", "default", "break", "continue", "class", "interface", "extends",
            "implements", "public", "private", "protected", "static", "const", "new", "this", "null",
            "true", "false", "try", "catch", "finally", "throw", "use", "namespace", "echo", "print",
            "require", "include", "require_once", "include_once", "instanceof", "clone", "yield"])
        langs["php"]!.capitalizedTypes = false
        langs["php"]!.variablePrefix = true

        var python = Language()
        python.keywords = Set(["def", "class", "if", "elif", "else", "return", "import", "from",
            "as", "with", "try", "except", "finally", "for", "while", "True", "False", "None", "and",
            "or", "not", "in", "is", "lambda", "yield", "pass", "break", "continue", "raise",
            "global", "nonlocal", "del", "assert", "async", "await", "match", "case"])
        python.lineComment = "#"
        python.strings = ["\"", "'"]
        python.multilineStrings = ["\"\"\"", "'''"]
        langs["python"] = python

        var ruby = python
        ruby.keywords = Set(["def", "end", "class", "module", "if", "elsif", "else", "unless",
            "return", "require", "require_relative", "include", "do", "while", "until", "for", "in",
            "case", "when", "then", "break", "next", "redo", "retry", "begin", "rescue", "ensure",
            "raise", "yield", "self", "nil", "true", "false", "and", "or", "not", "attr_accessor",
            "attr_reader", "attr_writer", "puts", "lambda", "proc", "super", "new"])
        langs["ruby"] = ruby

        var bash = Language()
        bash.keywords = Set(["if", "then", "elif", "else", "fi", "for", "in", "do", "done", "while",
            "until", "case", "esac", "function", "return", "exit", "echo", "export", "source",
            "local", "readonly", "declare", "set", "unset", "shift", "exec", "eval", "trap", "cd",
            "alias", "printf", "read", "test"])
        bash.lineComment = "#"
        bash.strings = ["\"", "'"]
        bash.variablePrefix = true
        langs["bash"] = bash
        langs["sh"] = bash
        langs["zsh"] = bash
        langs["shell"] = bash

        var sql = Language()
        sql.keywords = Set(["select", "from", "where", "insert", "into", "values", "update", "set",
            "delete", "create", "table", "drop", "alter", "add", "join", "left", "right", "inner",
            "outer", "full", "cross", "on", "as", "and", "or", "not", "null", "is", "in", "between",
            "like", "primary", "key", "foreign", "references", "unique", "index", "view", "order",
            "by", "group", "having", "limit", "offset", "distinct", "union", "all", "case", "when",
            "then", "else", "end", "count", "sum", "avg", "min", "max", "asc", "desc", "with",
            "default", "constraint", "exists", "begin", "commit", "rollback"])
        sql.keywordsCaseInsensitive = true
        sql.lineComment = "--"
        sql.blockComment = ("/*", "*/")
        sql.strings = ["'"]
        langs["sql"] = sql

        var json = Language()
        json.keywords = Set(["true", "false", "null"])
        json.strings = ["\""]
        langs["json"] = json

        var yaml = Language()
        yaml.keywords = Set(["true", "false", "null", "yes", "no", "on", "off"])
        yaml.keywordsCaseInsensitive = true
        yaml.lineComment = "#"
        yaml.strings = ["\"", "'"]
        yaml.extraRules = [rule(#"^[\t ]*(?:- )?[A-Za-z_][\w.-]*(?=:)"#, "fn", .anchorsMatchLines)].compactMap { $0 }
        langs["yaml"] = yaml

        var toml = yaml
        toml.keywords = Set(["true", "false"])
        toml.extraRules = []
        langs["toml"] = toml

        var html = Language()
        html.extraRules = [
            rule(#"<!--(?s:.*?)-->"#, "cm"),
            rule(#"(?i)<!DOCTYPE[^>]*>"#, "kw"),
            rule(#"</?[A-Za-z][\w:-]*"#, "kw"),
            rule(#"[A-Za-z_][\w:-]*(?=\s*=)"#, "fn"),
            rule(#"&[#\w]+;"#, "num"),
        ].compactMap { $0 }
        html.strings = ["\"", "'"]
        langs["html"] = html
        langs["xml"] = html
        langs["svg"] = html

        var css = Language()
        css.blockComment = ("/*", "*/")
        css.strings = ["\"", "'"]
        css.extraRules = [
            rule(#"@[\w-]+"#, "kw"),
            rule(#"[A-Za-z-][\w-]*(?=\s*:)"#, "fn"),
            rule(#"#[0-9a-fA-F]{3,8}\b|\b\d+(?:\.\d+)?(?:px|em|rem|vh|vw|vmin|vmax|pt|ch|ex|fr|s|ms|deg|%)?"#, "num"),
        ].compactMap { $0 }
        langs["css"] = css

        var diff = Language()
        diff.extraRules = [
            rule(#"^\+\+\+.*|^\+.*"#, "st", .anchorsMatchLines),
            rule(#"^---.*|^-.*"#, "cm", .anchorsMatchLines),
            rule(#"^@@.*"#, "num", .anchorsMatchLines),
        ].compactMap { $0 }
        langs["diff"] = diff

        return langs
    }()

    // MARK: - Aliases

    static func language(named name: String) -> Language? {
        switch name.lowercased() {
        case "js": return languages["javascript"]
        case "ts": return languages["typescript"]
        case "py": return languages["python"]
        case "rb": return languages["ruby"]
        case "golang": return languages["go"]
        case "c++", "cxx": return languages["cpp"]
        case "c#", "cs": return languages["csharp"]
        case "objectivec", "obj-c": return languages["objc"]
        default: return languages[name.lowercased()]
        }
    }

    // MARK: - Lexer

    public static func highlight(_ code: String, language: String) -> String {
        guard let lang = Self.language(named: language) else {
            return Self.escape(code)
        }

        var allRules: [Rule] = []
        let blockOpen = lang.blockComment?.open
        let blockClose = lang.blockComment?.close
        if let open = blockOpen, let close = blockClose {
            if let r = rule("\(NSRegularExpression.escapedPattern(for: open))(?s:.*?)\(NSRegularExpression.escapedPattern(for: close))", "cm") {
                allRules.append(r)
            }
        }
        if let prefix = lang.lineComment,
           let r = rule("\(NSRegularExpression.escapedPattern(for: prefix))[^\n]*", "cm") {
            allRules.append(r)
        }
        let delims = (lang.multilineStrings + lang.strings).sorted { $0.count > $1.count }
        for delim in delims {
            let open = NSRegularExpression.escapedPattern(for: delim)
            let body = lang.multilineStrings.contains(delim) ? #"(?:\\.|[^\\])*?"# : #"(?:\\.|[^\n\\])*?"#
            if let r = rule("\(open)\(body)\(open)", "st", [.dotMatchesLineSeparators]) {
                allRules.append(r)
            }
        }
        allRules.append(contentsOf: lang.extraRules)
        if let r = rule(#"\b(?:0[xXoObB][0-9a-fA-F_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?)"#, "num") {
            allRules.append(r)
        }
        if lang.variablePrefix, let r = rule(#"\$\{[^}\n]*\}|\$[\w?@*\-]+"#, "fn") {
            allRules.append(r)
        }
        if let r = rule(#"[A-Za-z_@][\w@]*"#, "") {
            allRules.append(r)
        }
        if let r = rule(#"[\+\-\*/%=<>!&|\^~?:]+"#, "op") {
            allRules.append(r)
        }

        let ns = code as NSString
        var out = ""
        var location = 0
        while location < ns.length {
            let rest = NSRange(location: location, length: ns.length - location)
            var matched = false
            for r in allRules {
                guard let m = r.regex.firstMatch(in: code, options: .anchored, range: rest),
                      m.range.location == location, m.range.length > 0 else { continue }
                let token = ns.substring(with: m.range)
                let cls = r.cls.isEmpty
                    ? classifyIdentifier(token, lang, remaining: ns.substring(from: m.range.location + m.range.length))
                    : r.cls
                let escaped = Self.escape(token)
                out += cls.isEmpty ? escaped : "<span class=\"\(cls)\">\(escaped)</span>"
                location += m.range.length
                matched = true
                break
            }
            if !matched {
                out += Self.escape(ns.substring(with: NSRange(location: location, length: 1)))
                location += 1
            }
        }
        return out
    }

    static func classifyIdentifier(_ id: String, _ lang: Language, remaining: String) -> String {
        if lang.keywordsCaseInsensitive, lang.keywords.contains(id.lowercased()) { return "kw" }
        if lang.keywords.contains(id) { return "kw" }
        if lang.capitalizedTypes, let first = id.first, first.isUppercase { return "ty" }
        if remaining.hasPrefix("(") { return "fn" }
        return ""
    }

    /// Texto de código: `"` é legal fora de atributos; escapar só & < >.
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
