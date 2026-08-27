import Foundation
public struct ParagraphNode: BlockNode, Equatable {
    public let text: String
    /// markdown original do bloco — preserva links/negrito para renderização clicável
    public let rawMarkdown: String

    public init(text: String, rawMarkdown: String) {
        self.text = text
        self.rawMarkdown = rawMarkdown
    }

    public static func == (a: ParagraphNode, b: ParagraphNode) -> Bool { a.text == b.text }
}

public struct CodeBlockNode: BlockNode, Equatable {
    public let language: String?
    public let code: String

    public init(language: String?, code: String) {
        self.language = language
        self.code = code
    }
}

public struct ListNode: BlockNode, Equatable {
    public let items: [String]
    public let isTaskList: Bool

    public init(items: [String], isTaskList: Bool = false) {
        self.items = items
        self.isTaskList = isTaskList
    }
}

public struct QuoteNode: BlockNode, Equatable {
    public let plainText: String

    public init(plainText: String) {
        self.plainText = plainText
    }
}

public struct OutlineEntry {
    public let level: Int
    public let title: String
    public let slug: String
}

public struct DocumentOutline {
    public let entries: [OutlineEntry]

    public init(_ doc: CoreDocument) {
        var counts: [String: Int] = [:]
        entries = doc.blocks.compactMap { block in
            guard let h = block as? HeadingNode else { return nil }
            return OutlineEntry(level: h.level,
                                title: h.inlineText,
                                slug: Self.uniqueSlug(Self.slugify(h.inlineText), counts: &counts))
        }
    }

    /// Atribui slug único a headings repetidos: 1ª ocorrência usa o slug puro,
    /// as seguintes recebem sufixo -1, -2, … Deve ser a MESMA regra usada pelo
    /// MarkdownHTMLConverter ao gerar ids, para que TOC/âncoras apontem certo.
    static func uniqueSlug(_ slug: String, counts: inout [String: Int]) -> String {
        let n = counts[slug] ?? 0
        counts[slug] = n + 1
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
}

public struct TaskSummary {
    public let checked: Int
    public let total: Int

    public init(_ doc: CoreDocument) {
        var c = 0, t = 0
        for case let list as TaskListItemsNode in doc.blocks {
            for item in list.items {
                t += 1
                if item.isChecked { c += 1 }
            }
        }
        checked = c
        total = t
    }
}

public enum PlainTextExtractor {
    public static func extract(from doc: CoreDocument) -> String {
        doc.blocks.map { block -> String in
            switch block {
            case let h as HeadingNode: return h.inlineText
            case let p as ParagraphNode: return p.text
            default: return ""
            }
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
