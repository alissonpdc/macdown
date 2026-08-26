import Foundation
public struct ParagraphNode: BlockNode, Equatable {
    public let text: String
}

public struct CodeBlockNode: BlockNode, Equatable {
    public let language: String?
    public let code: String
}

public struct ListNode: BlockNode, Equatable {
    public let items: [String]
    public let isTaskList: Bool
}

public struct QuoteNode: BlockNode, Equatable {
    public let plainText: String
}

public struct OutlineEntry {
    public let level: Int
    public let title: String
    public let slug: String
}

public struct DocumentOutline {
    public let entries: [OutlineEntry]

    public init(_ doc: CoreDocument) {
        var seen: [String: Int] = [:]
        entries = doc.blocks.compactMap { block in
            guard let h = block as? HeadingNode else { return nil }
            var slug = Self.slugify(h.inlineText)
            if let n = seen[slug] {
                slug += "-\(n + 1)"
                seen[h.inlineText.lowercased()] = n + 1
            } else {
                seen[slug] = 0
            }
            return OutlineEntry(level: h.level, title: h.inlineText, slug: slug)
        }
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
