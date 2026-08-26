import SwiftUI
import MarkdownCore

/// Canal de comandos de aba do menu para a view (o menu não enxerga o TabStore).
final class TabCommandBus: ObservableObject {
    enum Command { case next, previous, cycle }
    let send: (Command) -> Void

    init(send: @escaping (Command) -> Void) {
        self.send = send
    }
}

@main
struct MacDownApp: App {
    @State private var initialURL: URL?
    @StateObject private var theme = ThemeStore()
    @StateObject private var tabBus: TabCommandBus
    @NSApplicationDelegateAdaptor(AppearanceAppDelegate.self) private var appDelegate

    init() {
        _initialURL = State(initialValue: LaunchArgs.fileURL())
        // criado antes do body; a view registra os handlers via notification center
        _tabBus = StateObject(wrappedValue: TabCommandBus { command in
            NotificationCenter.default.post(
                name: command == .previous ? .macDownPreviousTab : .macDownNextTab,
                object: nil
            )
        })
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialURL: initialURL)
                .environmentObject(theme)
                .onAppear { appDelegate.apply(theme) }
                .onChange(of: theme.current) { _ in appDelegate.apply(theme) }
        }
        .commands {
            // R7.1 — Cmd+W fecha aba; Cmd+←/→ mudam de aba
            // R7.1 — Cmd+O abre arquivo, Cmd+Shift+O abre pasta; Cmd+W fecha aba
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .macDownOpenFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder…") {
                    NotificationCenter.default.post(name: .macDownOpenFolderPanel, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .macDownCloseActiveTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Tabs") {
                Button("Show Previous Tab") { tabBus.send(.previous) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Show Next Tab") { tabBus.send(.next) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
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
            // R9.1 — View menu
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
    static let macDownOpenFile = Notification.Name("macDownOpenFile")
    static let macDownOpenFolderPanel = Notification.Name("macDownOpenFolderPanel")
    static let macDownNextTab = Notification.Name("macDownNextTab")
    static let macDownPreviousTab = Notification.Name("macDownPreviousTab")
}

/// Ativa o app como .regular e aplica a aparência no nível AppKit.
final class AppearanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        TabShortcutMonitor.install()
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