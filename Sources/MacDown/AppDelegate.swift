import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        if DocumentStore.shared.documents.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                presentOpenPanel()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            try? DocumentStore.shared.open(url)
        }
    }
}
