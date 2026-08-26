public protocol BlockNode {}

public struct CoreDocument {
    public let blocks: [BlockNode]
    public init(blocks: [BlockNode]) { self.blocks = blocks }
}

public struct HeadingNode: BlockNode {
    public let level: Int
    public let inlineText: String
    public init(level: Int, inlineText: String) { self.level = level; self.inlineText = inlineText }
}

public struct TableNode: BlockNode {
    public let headerCells: [String]
    public let rows: [[String]]
}

public struct TaskItem {
    public let isChecked: Bool
    public let text: String
    public init(isChecked: Bool, text: String) { self.isChecked = isChecked; self.text = text }
}

public struct TaskListItemsNode: BlockNode {
    public let items: [TaskItem]
}

public struct GenericBlockNode: BlockNode {
    public let kindName: String
}
