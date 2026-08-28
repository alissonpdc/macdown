import Foundation
import Markdown

public struct MarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> CoreDocument {
        let parsed = Markdown.Document(parsing: markdown, options: [.parseBlockDirectives, .disableSmartOpts])
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
            let paragraphs = quote.children.compactMap { $0 as? (any PlainTextConvertibleMarkup) }.map(\.plainText)
            return QuoteNode(paragraphs: paragraphs)
        }
        if let list = node as? Markdown.UnorderedList {
            return listNode(from: list.children, ordered: false)
        }
        if let list = node as? Markdown.OrderedList {
            return listNode(from: list.children, ordered: true)
        }
        if node is ThematicBreak {
            return HorizontalRuleNode()
        }
        if let table = node as? Markdown.Table {
            let header: [String] = table.head.cells.map { $0.plainText }
            let rows: [[String]] = table.body.rows.map { row in row.cells.map { $0.plainText } }
            return TableNode(headerCells: header, rows: rows)
        }
        return GenericBlockNode(kindName: String(describing: type(of: node)))
    }

    private func listNode(from children: MarkupChildren, ordered: Bool) -> any BlockNode {
        var tasks: [TaskItem] = []
        var items: [ListNode.Item] = []
        for item in children {
            guard let listItem = item as? ListItem else { continue }
            // Preserva raw markdown (bold, code, etc.) em vez de extrair só Text nodes
            var rawMarkdown = ""
            var childLists: [ListNode] = []
            for child in listItem.children {
                if let para = child as? Paragraph {
                    rawMarkdown += para.format()
                } else if let ul = child as? Markdown.UnorderedList,
                          let nested = listNode(from: ul.children, ordered: false) as? ListNode {
                    childLists.append(nested)
                } else if let ol = child as? Markdown.OrderedList,
                          let nested = listNode(from: ol.children, ordered: true) as? ListNode {
                    childLists.append(nested)
                }
            }
            rawMarkdown = rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            if let checkbox = listItem.checkbox {
                tasks.append(TaskItem(isChecked: checkbox == .checked, text: rawMarkdown))
            } else {
                items.append(ListNode.Item(text: rawMarkdown, children: childLists))
            }
        }
        if !tasks.isEmpty { return TaskListItemsNode(items: tasks) }
        return ListNode(items: items, isOrdered: ordered, isTaskList: false)
    }
}
