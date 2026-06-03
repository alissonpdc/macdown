import SwiftUI

@MainActor
final class DocumentStore: ObservableObject {
    static let shared = DocumentStore()

    @Published var documents: [OpenDocument] = []
    @Published var activeIndex: Int = 0

    let recentsManager = RecentsManager()

    var activeDocument: OpenDocument? {
        guard !documents.isEmpty, activeIndex < documents.count else { return nil }
        return documents[activeIndex]
    }

    func open(_ url: URL) throws {
        if let existing = documents.firstIndex(where: { $0.url == url }) {
            activeIndex = existing
            return
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let doc = OpenDocument(url: url, content: content)
        documents.append(doc)
        activeIndex = documents.count - 1
        recentsManager.addRecent(url, title: doc.title)
    }

    func openInNewTab(_ url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let doc = OpenDocument(url: url, content: content)
        documents.append(doc)
        activeIndex = documents.count - 1
        recentsManager.addRecent(url, title: doc.title)
    }

    func openInNewTabFromSidebar(at index: Int) {
        let doc = documents[index]
        documents.append(OpenDocument(url: doc.url, content: doc.content))
        activeIndex = documents.count - 1
        recentsManager.addRecent(doc.url, title: doc.title)
    }

    func replaceActive(with url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let doc = OpenDocument(url: url, content: content)
        if documents.isEmpty {
            documents.append(doc)
            activeIndex = 0
        } else {
            documents[activeIndex] = doc
        }
        recentsManager.addRecent(url, title: doc.title)
    }

    func close(at index: Int) {
        documents.remove(at: index)
        if activeIndex >= documents.count {
            activeIndex = max(0, documents.count - 1)
        }
    }

    /// Reorders an open document, preserving which document is active.
    /// `destination` is the target slot index in the current array.
    func move(from source: Int, to destination: Int) {
        guard documents.indices.contains(source), source != destination else { return }
        let activeID = activeDocument?.id
        let doc = documents.remove(at: source)
        let insertIndex = min(max(destination, 0), documents.count)
        documents.insert(doc, at: insertIndex)
        if let activeID, let newActive = documents.firstIndex(where: { $0.id == activeID }) {
            activeIndex = newActive
        }
    }

    func clearRecents() {
        recentsManager.clear()
    }
}
