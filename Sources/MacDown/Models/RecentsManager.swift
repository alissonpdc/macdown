import Foundation
import SwiftUI

@MainActor
final class RecentsManager: ObservableObject {
    struct RecentFile {
        let url: URL
        let title: String
    }

    @Published var recents: [RecentFile] = []

    func addRecent(_ url: URL, title: String) {
        recents.append(RecentFile(url: url, title: title))
    }

    func clear() {
        recents.removeAll()
    }
}
