@testable import MacDown
import Testing
import Foundation

@Suite("FolderManager Tests")
struct FolderManagerTests {

    @Test("Import folder and prevent duplicates")
    @MainActor
    func testImportFolderNoDuplicates() async throws {
        let manager = FolderManager()
        let tempURL = URL(fileURLWithPath: "/tmp/test_folder_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importFolder(tempURL)
        #expect(manager.importedFolders.count == 1)

        try manager.importFolder(tempURL)
        #expect(manager.importedFolders.count == 1)
    }

    @Test("Remove folder")
    @MainActor
    func testRemoveFolder() async throws {
        let manager = FolderManager()
        let tempURL = URL(fileURLWithPath: "/tmp/test_folder_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importFolder(tempURL)
        #expect(manager.importedFolders.count == 1)

        manager.removeFolder(tempURL)
        #expect(manager.importedFolders.isEmpty)
    }

    @Test("Clear all folders")
    @MainActor
    func testClear() async throws {
        let manager = FolderManager()
        let tempURL = URL(fileURLWithPath: "/tmp/test_folder_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importFolder(tempURL)
        manager.clear()

        #expect(manager.importedFolders.isEmpty)
        #expect(manager.folderTrees.isEmpty)
    }

    @Test("Toggle folder expansion")
    @MainActor
    func testToggleFolderExpansion() async throws {
        let manager = FolderManager()
        let tempURL = URL(fileURLWithPath: "/tmp/test_folder_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importFolder(tempURL)
        let nodeID = manager.folderTrees.first?.id

        if let nodeID = nodeID {
            // After import, isExpanded is true
            #expect(manager.folderTrees.first?.isExpanded == true)

            // Toggle once - should be false
            manager.toggleFolderExpansion(nodeID)
            #expect(manager.folderTrees.first?.isExpanded == false)

            // Toggle again - should be true
            manager.toggleFolderExpansion(nodeID)
            #expect(manager.folderTrees.first?.isExpanded == true)
        }
    }
}
