import SwiftUI
import MarkdownCore

@main
struct MacDownApp: App {
    @State private var initialURL: URL?
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        _initialURL = State(initialValue: LaunchArgs.fileURL())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialURL: initialURL)
        }
        .defaultSize(width: 900, height: 640)
    }
}

/// Executável SPM não tem bundle .app: sem isso o macOS mantém o processo
/// como agente de fundo (sem Dock, sem trazer a janela à frente).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
