import SwiftUI
import MarkdownCore

@main
struct MacDownApp: App {
    @State private var initialURL: URL?

    init() {
        _initialURL = State(initialValue: LaunchArgs.fileURL())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialURL: initialURL)
        }
    }
}
