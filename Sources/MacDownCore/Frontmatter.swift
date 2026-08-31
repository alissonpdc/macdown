public enum YAMLValue: Equatable {
    case string(String)
    case list([String])
}

/// R3.4 — campos do frontmatter preservando a ordem de inserção do YAML.
public struct Frontmatter: Equatable {
    public let orderedFields: [(key: String, value: YAMLValue)]

    public static func == (lhs: Frontmatter, rhs: Frontmatter) -> Bool {
        guard lhs.orderedFields.count == rhs.orderedFields.count else { return false }
        for (a, b) in zip(lhs.orderedFields, rhs.orderedFields) {
            guard a.key == b.key, a.value == b.value else { return false }
        }
        return true
    }

    public subscript(key: String) -> YAMLValue? {
        orderedFields.first(where: { $0.key == key })?.value
    }

    public var isEmpty: Bool {
        orderedFields.isEmpty
    }

    public var count: Int {
        orderedFields.count
    }

    public init(_ fields: [(key: String, value: YAMLValue)]) {
        orderedFields = fields
    }
}

public struct FrontmatterResult {
    public let frontmatter: Frontmatter?
    public let markdown: String // conteúdo sem o bloco frontmatter
    public let error: String?
}

public enum FrontmatterExtractor {
    /// R3.4/R10.2 — separa frontmatter `--- ... ---` do corpo markdown.
    /// YAML mínimo: chaves com valor string ou lista (- item).
    public static func extract(from text: String) -> FrontmatterResult {
        guard text.hasPrefix("---") else {
            return FrontmatterResult(frontmatter: nil, markdown: text, error: nil)
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let close = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return FrontmatterResult(frontmatter: nil, markdown: text, error: "Frontmatter não fechado (--- de abertura sem --- de fechamento)")
        }
        var fields: [(key: String, value: YAMLValue)] = []
        var currentKey: String?
        var listBuffer: [String] = []
        var failed = false

        func commitList() {
            if let key = currentKey, !listBuffer.isEmpty {
                // remove entrada anterior da mesma chave para substituir
                fields.removeAll { $0.key == key }
                fields.append((key: key, value: .list(listBuffer)))
            }
            listBuffer = []
            currentKey = nil
        }

        for rawLine in lines[1 ..< close] {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- ") || line == "-" {
                guard currentKey != nil else { failed = true; break }
                listBuffer.append(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
                continue
            }
            guard let sep = line.firstIndex(of: ":"), sep != line.startIndex else {
                failed = true; break
            }
            commitList()
            let key = String(line[..<sep]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { failed = true; break }
            currentKey = key
            if !value.isEmpty {
                // R10.2 — estruturas YAML fora do subconjunto suportado são sinalizadas, não engolidas
                if value.hasPrefix("[") || value.hasPrefix("{") {
                    if !value.hasSuffix("]"), !value.hasSuffix("}") {
                        failed = true; break
                    }
                    failed = true; break
                }
                fields.removeAll { $0.key == key }
                fields.append((key: key, value: .string(stripYAMLQuotes(value))))
            }
        }
        commitList()

        if failed {
            return FrontmatterResult(frontmatter: nil, markdown: text, error: "YAML malformado no frontmatter")
        }
        let body = lines[(close + 1)...].joined(separator: "\n")
        return FrontmatterResult(frontmatter: Frontmatter(fields), markdown: body, error: nil)
    }

    /// Remove aspas simples/duplas que envolvem um valor YAML.
    private static func stripYAMLQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first!, last = value.last!
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
