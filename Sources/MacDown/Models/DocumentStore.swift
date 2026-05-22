import SwiftUI

@MainActor
final class DocumentStore: ObservableObject {
    static let shared = DocumentStore()

    @Published var documents: [OpenDocument] = []
    @Published var activeIndex: Int = 0

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
        documents.append(OpenDocument(url: url, content: content))
        activeIndex = documents.count - 1
    }

    func openInNewTab(_ url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        documents.append(OpenDocument(url: url, content: content))
        activeIndex = documents.count - 1
    }

    func openInNewTabFromSidebar(at index: Int) {
        let doc = documents[index]
        documents.append(OpenDocument(url: doc.url, content: doc.content))
        activeIndex = documents.count - 1
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
    }

    func close(at index: Int) {
        documents.remove(at: index)
        if activeIndex >= documents.count {
            activeIndex = max(0, documents.count - 1)
        }
    }
}
