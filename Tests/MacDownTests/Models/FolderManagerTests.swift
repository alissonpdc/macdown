@testable import MacDown
import Testing
import Foundation

@Suite("FolderManager Tests")
struct FolderManagerTests {

    @Test("Import folder and prevent duplicates")
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
    func testToggleFolderExpansion() async throws {
        let manager = FolderManager()
        let tempURL = URL(fileURLWithPath: "/tmp/test_folder_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importFolder(tempURL)
        let nodeID = manager.folderTrees.first?.id

        if let nodeID = nodeID {
            manager.toggleFolderExpansion(nodeID)
            #expect(manager.folderTrees.first?.isExpanded == true)
        }
    }
}
