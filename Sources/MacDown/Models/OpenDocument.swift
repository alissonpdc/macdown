import Foundation

struct OpenDocument: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var content: String

    var title: String { url.deletingPathExtension().lastPathComponent }

    init(url: URL, content: String) {
        self.id = UUID()
        self.url = url
        self.content = content
    }
}
