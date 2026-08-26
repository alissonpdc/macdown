import SwiftUI
import MarkdownCore

@main
struct MacDownApp: App {
    @State private var initialURL: URL?
    @StateObject private var theme = ThemeStore()

    init() {
        _initialURL = State(initialValue: LaunchArgs.fileURL())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialURL: initialURL)
                .environmentObject(theme)
                .preferredColorScheme(theme.current.colorScheme)
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
