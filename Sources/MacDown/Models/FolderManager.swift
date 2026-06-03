import Foundation
import SwiftUI

@MainActor
final class FolderManager: ObservableObject {
    @Published var importedFolders: [URL] = []
    @Published var folderTrees: [FolderTreeNode] = []
    @Published var filterText: String = ""

    private var expandedNodeIDs: Set<UUID> = []
    private var previousExpandedState: Set<UUID> = []

    func importFolder(_ url: URL) throws {
        // Check for duplicates
        if importedFolders.contains(url) {
            return
        }

        importedFolders.append(url)

        // Build tree
        let tree = try buildFolderTree(url: url, isRoot: true)
        tree.isExpanded = true
        folderTrees.append(tree)

        // Expand first level
        expandFirstLevel(tree)
    }

    func removeFolder(_ url: URL) {
        importedFolders.removeAll { $0 == url }
        folderTrees.removeAll { $0.url == url }
    }

    func clear() {
        importedFolders.removeAll()
        folderTrees.removeAll()
        expandedNodeIDs.removeAll()
        filterText = ""
    }

    func toggleFolderExpansion(_ nodeID: UUID) {
        if let node = findNode(nodeID, in: folderTrees) {
            node.isExpanded.toggle()
            expandedNodeIDs.insert(nodeID)
        }
    }

    func expandAll() {
        for tree in folderTrees {
            expandAllNodes(tree)
        }
    }

    func collapseAll() {
        for tree in folderTrees {
            collapseAllNodes(tree)
        }
    }

    func setFilter(_ text: String) {
        previousExpandedState = expandedNodeIDs
        filterText = text

        if text.isEmpty {
            // Restore previous state
            expandedNodeIDs = previousExpandedState
            updateNodeExpansionFromState()
        } else {
            // Auto-expand parents of matching files
            expandParentsOfMatches()
        }
    }

    // MARK: - Private Helpers

    private func buildFolderTree(url: URL, isRoot: Bool) throws -> FolderTreeNode {
        let fileManager = FileManager.default
        let name = url.lastPathComponent
        let parentPath = url.deletingLastPathComponent().path

        let node = FolderTreeNode(
            name: name,
            url: url,
            isFolder: true,
            parentFolderPath: parentPath
        )

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                let childNode = try buildFolderTree(url: item, isRoot: false)
                // Skip folders that contain no .md files anywhere in their subtree
                if hasMarkdownDescendant(childNode) {
                    node.children.append(childNode)
                }
            } else if item.pathExtension == "md" || item.pathExtension == "markdown" {
                let fileName = item.lastPathComponent
                let filePath = item.deletingLastPathComponent().path
                let fileNode = FolderTreeNode(
                    name: fileName,
                    url: item,
                    isFolder: false,
                    parentFolderPath: filePath
                )
                node.children.append(fileNode)
            }
        }

        return node
    }

    private func hasMarkdownDescendant(_ node: FolderTreeNode) -> Bool {
        for child in node.children {
            if !child.isFolder {
                return true
            }
            if hasMarkdownDescendant(child) {
                return true
            }
        }
        return false
    }

    private func expandFirstLevel(_ node: FolderTreeNode) {
        node.isExpanded = true
        // Don't expand children, just the root
    }

    private func expandAllNodes(_ node: FolderTreeNode) {
        node.isExpanded = true
        for child in node.children where child.isFolder {
            expandAllNodes(child)
        }
    }

    private func collapseAllNodes(_ node: FolderTreeNode) {
        node.isExpanded = false
        for child in node.children {
            collapseAllNodes(child)
        }
    }

    private func findNode(_ id: UUID, in nodes: [FolderTreeNode]) -> FolderTreeNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findNode(id, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func expandParentsOfMatches() {
        for tree in folderTrees {
            expandParentsOfMatching(tree)
        }
    }

    private func expandParentsOfMatching(_ node: FolderTreeNode) {
        let hasMatchingChild = node.children.contains { child in
            if !child.isFolder && child.name.lowercased().contains(filterText.lowercased()) {
                return true
            }
            if child.isFolder {
                return hasAnyMatchingDescendant(child)
            }
            return false
        }

        if hasMatchingChild {
            node.isExpanded = true
            expandedNodeIDs.insert(node.id)
        }

        for child in node.children where child.isFolder {
            expandParentsOfMatching(child)
        }
    }

    private func hasAnyMatchingDescendant(_ node: FolderTreeNode) -> Bool {
        for child in node.children {
            if !child.isFolder && child.name.lowercased().contains(filterText.lowercased()) {
                return true
            }
            if child.isFolder && hasAnyMatchingDescendant(child) {
                return true
            }
        }
        return false
    }

    private func updateNodeExpansionFromState() {
        for tree in folderTrees {
            updateExpansionState(tree)
        }
    }

    private func updateExpansionState(_ node: FolderTreeNode) {
        node.isExpanded = expandedNodeIDs.contains(node.id)
        for child in node.children {
            updateExpansionState(child)
        }
    }
}
