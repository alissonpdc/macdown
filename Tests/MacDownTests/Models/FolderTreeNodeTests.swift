@testable import MacDown
import Testing
import Foundation

@Suite("FolderTreeNode Tests")
struct FolderTreeNodeTests {

    @Test("Create file node")
    func testCreateFileNode() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let node = FolderTreeNode(
            name: "test.md",
            url: url,
            isFolder: false,
            parentFolderPath: "/tmp"
        )

        #expect(node.name == "test.md")
        #expect(node.url == url)
        #expect(!node.isFolder)
        #expect(node.children.isEmpty)
        #expect(node.parentFolderPath == "/tmp")
    }

    @Test("Create folder node with children")
    func testCreateFolderNode() {
        let folderURL = URL(fileURLWithPath: "/tmp/docs")
        let fileURL = URL(fileURLWithPath: "/tmp/docs/file.md")

        let fileNode = FolderTreeNode(
            name: "file.md",
            url: fileURL,
            isFolder: false,
            parentFolderPath: "/tmp/docs"
        )

        var folderNode = FolderTreeNode(
            name: "docs",
            url: folderURL,
            isFolder: true,
            parentFolderPath: "/tmp"
        )
        folderNode.children = [fileNode]

        #expect(folderNode.name == "docs")
        #expect(folderNode.isFolder)
        #expect(folderNode.children.count == 1)
        #expect(folderNode.children[0].name == "file.md")
    }

    @Test("Expansion state defaults to false")
    func testDefaultExpansion() {
        let node = FolderTreeNode(
            name: "folder",
            url: URL(fileURLWithPath: "/tmp"),
            isFolder: true,
            parentFolderPath: "/"
        )

        #expect(!node.isExpanded)
    }
}
