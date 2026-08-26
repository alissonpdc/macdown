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
            // R7.1 — Cmd+W fecha a aba ativa; Cmd+←/→ navegam no histórico da aba
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    NotificationCenter.default.post(name: .macDownOpenFolder, object: url)
                }
                Divider()
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .macDownCloseActiveTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Navigate") {
                Button("Back") {
                    NotificationCenter.default.post(name: .macDownGoBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)
                Button("Forward") {
                    NotificationCenter.default.post(name: .macDownGoForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
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

extension Notification.Name {
    static let macDownCloseActiveTab = Notification.Name("macDownCloseActiveTab")
    static let macDownGoBack = Notification.Name("macDownGoBack")
    static let macDownGoForward = Notification.Name("macDownGoForward")
    static let macDownOpenFolder = Notification.Name("macDownOpenFolder")
}

/// Ativa o app como .regular e aplica a aparência no nível AppKit.
final class AppearanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Light = aqua, Dark = darkAqua, System = nil (segue o macOS).
    func apply(_ theme: ThemeStore) {
        switch theme.current {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }
}
