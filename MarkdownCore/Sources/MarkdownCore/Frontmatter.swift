public enum YAMLValue: Equatable {
    case string(String)
    case list([String])
}

public struct Frontmatter {
    public let fields: [String: YAMLValue]
}

public struct FrontmatterResult {
    public let frontmatter: Frontmatter?
    public let markdown: String   // conteúdo sem o bloco frontmatter
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
        var fields: [String: YAMLValue] = [:]
        var currentKey: String?
        var listBuffer: [String] = []
        var failed = false

        func commitList() {
            if let key = currentKey, !listBuffer.isEmpty {
                fields[key] = .list(listBuffer)
            }
            listBuffer = []
            currentKey = nil
        }

        for rawLine in lines[1..<close] {
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
                    if !value.hasSuffix("]") && !value.hasSuffix("}") {
                        failed = true; break
                    }
                    failed = true; break
                }
                fields[key] = .string(value)
            }
        }
        commitList()

        if failed {
            return FrontmatterResult(frontmatter: nil, markdown: text, error: "YAML malformado no frontmatter")
        }
        let body = lines[(close + 1)...].joined(separator: "\n")
        return FrontmatterResult(frontmatter: Frontmatter(fields: fields), markdown: body, error: nil)
    }
}
