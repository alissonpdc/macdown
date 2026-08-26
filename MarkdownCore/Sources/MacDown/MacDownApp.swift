import SwiftUI
import MarkdownCore

@main
struct MacDownApp: App {
    @State private var initialURL: URL?
    @StateObject private var theme = ThemeStore()
    @NSApplicationDelegateAdaptor(AppearanceAppDelegate.self) private var appDelegate

    init() {
        _initialURL = State(initialValue: LaunchArgs.fileURL())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialURL: initialURL)
                .environmentObject(theme)
                .onAppear { appDelegate.apply(theme) }
                .onChange(of: theme.current) { _ in appDelegate.apply(theme) }
        }
        .commands {
            // R9.1 — View menu (PRD: "Seleção via menu nativo (View/Aparência)")
            CommandGroup(after: .toolbar) {
                Picker("Appearance", selection: Binding(
                    get: { theme.current },
                    set: { theme.set($0) }
                )) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.inline)
            }
        }
    }
}

/// Aplica a aparência no nível AppKit (janelas inteiras), cobrindo o caso
/// System após um modo explícito — que o SwiftUI não desfaz sozinho.
final class AppearanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Chamado pelo App com o tema corrente (via onChange e na inicialização).
    func apply(_ theme: ThemeStore) {
        switch theme.current {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }
}
