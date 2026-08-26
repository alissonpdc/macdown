public protocol BlockNode: Equatable {}

public struct CoreDocument: Equatable {
    public let blocks: [BlockNode]
    public init(blocks: [BlockNode]) { self.blocks = blocks }
    public static func == (a: CoreDocument, b: CoreDocument) -> Bool { a.blocks.count == b.blocks.count }
}

public struct HeadingNode: BlockNode, Equatable {
    public let level: Int
    public let inlineText: String
    public init(level: Int, inlineText: String) { self.level = level; self.inlineText = inlineText }
}

public struct TableNode: BlockNode, Equatable {
    public let headerCells: [String]
    public let rows: [[String]]
}

public struct TaskItem: Equatable {
    public let isChecked: Bool
    public let text: String
    public init(isChecked: Bool, text: String) { self.isChecked = isChecked; self.text = text }
}

public struct TaskListItemsNode: BlockNode, Equatable {
    public let items: [TaskItem]
}

public struct GenericBlockNode: BlockNode, Equatable {
    public let kindName: String
}
