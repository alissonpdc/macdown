import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        if DocumentStore.shared.documents.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
