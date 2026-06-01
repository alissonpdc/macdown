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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Clear session state before quitting
        DocumentStore.shared.clearRecents()
        return .terminateNow
    }

    func presentFolderPickerForWorkspace(onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecione uma pasta para adicionar ao workspace"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                onSelect(url)
            }
        }
    }

    func presentFolderPickerForNewWindow(onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecione uma pasta para abrir em uma nova janela"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                onSelect(url)
            }
        }
    }
}
