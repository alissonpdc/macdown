import Foundation
import Markdown

public struct MarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> CoreDocument {
        let parsed = Markdown.Document(parsing: markdown, options: [.parseBlockDirectives])
        var blocks: [any BlockNode] = []
        for child in parsed.blockChildren {
            blocks.append(blockNode(from: child))
        }
        return CoreDocument(blocks: blocks)
    }

    private func blockNode(from node: any Markup) -> any BlockNode {
        if let heading = node as? Markdown.Heading {
            return HeadingNode(level: heading.level, inlineText: heading.plainText)
        }
        if let paragraph = node as? Paragraph {
            return ParagraphNode(text: paragraph.plainText, rawMarkdown: node.format())
        }
        if let code = node as? CodeBlock {
            return CodeBlockNode(language: code.language, code: code.code)
        }
        if let quote = node as? BlockQuote {
            return QuoteNode(plainText: quote.children.compactMap { $0 as? (any PlainTextConvertibleMarkup) }.map(\.plainText).joined(separator: " "))
        }
        if let list = node as? Markdown.UnorderedList {
            return listNode(from: list.children)
        }
        if let list = node as? Markdown.OrderedList {
            return listNode(from: list.children)
        }
        if let table = node as? Markdown.Table {
            let header: [String] = table.head.cells.map { $0.plainText }
            let rows: [[String]] = table.body.rows.map { row in row.cells.map { $0.plainText } }
            return TableNode(headerCells: header, rows: rows)
        }
        return GenericBlockNode(kindName: String(describing: type(of: node)))
    }

    private func listNode(from children: MarkupChildren) -> any BlockNode {
        var tasks: [TaskItem] = []
        var texts: [String] = []
        for item in children {
            guard let listItem = item as? ListItem else { continue }
            // R3.13 — texto do item sem o marcador de checkbox
            let text = listItem.children.compactMap { child -> String? in
                guard let para = child as? Paragraph else { return nil }
                return para.inlineChildren.compactMap { $0 as? Text }.map(\.string).joined()
            }.joined()
            if let checkbox = listItem.checkbox {
                tasks.append(TaskItem(isChecked: checkbox == .checked, text: text))
            } else {
                texts.append(text)
            }
        }
        if !tasks.isEmpty { return TaskListItemsNode(items: tasks) }
        return ListNode(items: texts, isTaskList: false)
    }
}
