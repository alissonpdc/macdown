import SwiftUI
import CoreServices

@main
struct MacDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasAskedDefaultApp") private var hasAskedDefaultApp = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DocumentStore.shared)
                .environmentObject(ThemeState.shared)
                .onAppear {
                    if !hasAskedDefaultApp {
                        hasAskedDefaultApp = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            askToSetAsDefaultApp()
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir arquivo…") {
                    presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Adicionar pasta ao Workspace") {
                    addFolderToWorkspace()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Abrir pasta") {
                    openNewWindowWithFolder()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    private func askToSetAsDefaultApp() {
        let alert = NSAlert()
        alert.messageText = "Definir MacDown como app padrão para .md?"
        alert.informativeText = "Arquivos .md e .markdown abrirão no MacDown automaticamente."
        alert.addButton(withTitle: "Sim")
        alert.addButton(withTitle: "Agora não")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultRoleHandlerForContentType(
            "net.daringfireball.markdown" as CFString,
            .all,
            bundleID as CFString
        )
    }

    private func addFolderToWorkspace() {
        appDelegate.presentFolderPickerForWorkspace { url in
            NotificationCenter.default.post(
                name: NSNotification.Name("ImportFolderToWorkspace"),
                object: nil,
                userInfo: ["folderURL": url]
            )
        }
    }

    private func openNewWindowWithFolder() {
        appDelegate.presentFolderPickerForNewWindow { url in
            DispatchQueue.main.async {
                let newStore = DocumentStore()
                let newTheme = ThemeState.shared

                let newView = ContentView()
                    .environmentObject(newStore)
                    .environmentObject(newTheme)

                let newWindow = NSWindow(
                    contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )

                newWindow.contentView = NSHostingView(rootView: newView)
                newWindow.title = url.lastPathComponent
                newWindow.makeKeyAndOrderFront(nil)

                // Import the folder after window is created
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportFolderToWorkspace"),
                    object: nil,
                    userInfo: ["folderURL": url]
                )
            }
        }
    }
}
