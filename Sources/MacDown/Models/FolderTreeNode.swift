import Foundation
import Observation

@MainActor
final class FolderTreeNode: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let isFolder: Bool
    var children: [FolderTreeNode] = []
    @Published var isExpanded: Bool = false
    let parentFolderPath: String

    init(
        name: String,
        url: URL,
        isFolder: Bool,
        parentFolderPath: String
    ) {
        self.name = name
        self.url = url
        self.isFolder = isFolder
        self.parentFolderPath = parentFolderPath
    }
}
