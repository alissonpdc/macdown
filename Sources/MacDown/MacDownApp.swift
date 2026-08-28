import SwiftUI
import MacDownCore

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
    @StateObject private var readingPrefs = ReadingPrefs()
    /// R3.7 — estado persistido de visibilidade do TOC
    @StateObject private var uiPrefs = UIPrefs()
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
                .environmentObject(readingPrefs)
                .environmentObject(uiPrefs)
                .onAppear { appDelegate.apply(theme) }
                .onChange(of: theme.current) { appDelegate.apply(theme) }
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
                Divider()
                // R13.3 — alterna visão Nova/Diff
                Button("Toggle Diff View") {
                    NotificationCenter.default.post(name: .macDownToggleDiff, object: nil)
                }
                    .keyboardShortcut("d", modifiers: .command)
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
                Divider()
                // R3.7 — painel TOC lateral direito (Cmd+Shift+T)
                Toggle("Table of Contents", isOn: Binding(
                    get: { uiPrefs.showTOC },
                    set: { uiPrefs.showTOC = $0 }
                ))
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .help("Toggle the table of contents panel")
                Divider()
                // R3.11 — Largura de leitura
                Menu("Reading Width") {
                    Button("Narrower (−)") { readingPrefs.decreaseWidth() }
                        .keyboardShortcut("-", modifiers: [.command, .option])
                    Button("Wider (+)") { readingPrefs.increaseWidth() }
                        .keyboardShortcut("+", modifiers: [.command, .option])
                    Divider()
                    Button("Reset") { readingPrefs.widthCh = ReadingPrefs.defaultWidth }
                }
                // R11.1 — Zoom de texto
                Menu("Text Zoom") {
                    Button("Zoom In") { readingPrefs.zoomIn() }
                        .keyboardShortcut("=", modifiers: .command)
                    Button("Zoom Out") { readingPrefs.zoomOut() }
                        .keyboardShortcut("-", modifiers: .command)
                    Divider()
                    Button("Reset Zoom") { readingPrefs.resetZoom() }
                        .keyboardShortcut("0", modifiers: .command)
                }
            }
            // R5.1 / R5.2 — Busca
            CommandMenu("Find") {
                Button("Find…") {
                    NotificationCenter.default.post(name: .macDownFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") {
                    NotificationCenter.default.post(name: .macDownFindNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") {
                    NotificationCenter.default.post(name: .macDownFindPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Button("Find in Folder…") {
                    NotificationCenter.default.post(name: .macDownFindGlobal, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
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
    static let macDownOpenURLs = Notification.Name("macDownOpenURLs")
    static let macDownOpenFolderPanel = Notification.Name("macDownOpenFolderPanel")
    static let macDownNextTab = Notification.Name("macDownNextTab")
    static let macDownPreviousTab = Notification.Name("macDownPreviousTab")
    static let macDownToggleDiff = Notification.Name("macDownToggleDiff")
    static let macDownFind = Notification.Name("macDownFind")
    static let macDownFindNext = Notification.Name("macDownFindNext")
    static let macDownFindPrevious = Notification.Name("macDownFindPrevious")
    static let macDownFindGlobal = Notification.Name("macDownFindGlobal")
}

/// Buffer de URLs entregues ao app antes de a view instalar o handler.
enum PendingOpenURLs {
    static var buffer: [URL] = []
}

/// Ativa o app como .regular e aplica a aparência no nível AppKit.
final class AppearanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        TabShortcutMonitor.install()
    }

    /// Arquivos/pastas abertos pelo Finder ("Abrir com") ou via `open`.
    /// O evento pode chegar antes da view instalar o handler, então as URLs
    /// ficam em buffer e a view drena em onAppear.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        PendingOpenURLs.buffer.append(contentsOf: urls)
        NotificationCenter.default.post(name: .macDownOpenURLs, object: urls)
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