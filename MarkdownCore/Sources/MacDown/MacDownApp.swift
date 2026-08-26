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
            CommandGroup(after: .windowArrangement) {
                Picker("Aparência", selection: Binding(
                    get: { theme.current },
                    set: { theme.set($0) }
                )) {
                    Text("Sistema").tag(AppearanceMode.system)
                    Text("Claro").tag(AppearanceMode.light)
                    Text("Escuro").tag(AppearanceMode.dark)
                }
                .pickerStyle(.inline)
            }
        }
    }
}
