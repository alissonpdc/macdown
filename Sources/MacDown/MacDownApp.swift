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
}
