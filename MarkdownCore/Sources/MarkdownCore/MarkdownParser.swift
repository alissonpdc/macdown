import Foundation
import Markdown

public struct MarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> CoreDocument {
        let parsed = Markdown.Document(parsing: markdown, options: [.parseBlockDirectives])
        var blocks: [BlockNode] = []
        for child in parsed.blockChildren {
            blocks.append(blockNode(from: child))
        }
        return CoreDocument(blocks: blocks)
    }

    private func blockNode(from node: any Markup) -> BlockNode {
        if let heading = node as? Markdown.Heading {
            return HeadingNode(level: heading.level, inlineText: heading.plainText)
        }
        if let table = node as? Markdown.Table {
            let header: [String] = table.head.cells.map { $0.plainText }
            let rows: [[String]] = table.body.rows.map { row in row.cells.map { $0.plainText } }
            return TableNode(headerCells: header, rows: rows)
        }
        if let list = node as? Markdown.UnorderedList {
            let items: [TaskItem] = list.children.compactMap { (item: any Markup) -> TaskItem? in
                guard let listItem = item as? ListItem, let checkbox = listItem.checkbox else { return nil }
                return TaskItem(isChecked: checkbox == .checked, text: listItem.children.compactMap { child -> String? in
                    guard let para = child as? Paragraph else { return nil }
                    return para.inlineChildren.compactMap { $0 as? Text }.map(\.string).joined()
                }.joined())
            }
            if !items.isEmpty { return TaskListItemsNode(items: items) }
        }
        return GenericBlockNode(kindName: String(describing: type(of: node)))
    }
}
