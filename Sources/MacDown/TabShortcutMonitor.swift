import AppKit
import Foundation

/// Captura Ctrl+Tab / Ctrl+Shift+Tab no escopo local do app (janela em foco)
/// e notifica para alternar abas ciclicamente. O menu do macOS não suporta
/// esse atalho (é reservado do sistema), por isso o monitor de eventos.
enum TabShortcutMonitor {
    static func install() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let ctrl = event.modifierFlags.contains(.control)
            let cmd = event.modifierFlags.contains(.command)
            guard ctrl, !cmd, event.keyCode == 48 else { return event } // 48 = Tab

            let backwards = event.modifierFlags.contains(.shift)
            NotificationCenter.default.post(
                name: backwards ? .macDownPreviousTab : .macDownNextTab,
                object: nil
            )
            return nil // consumido
        }
    }
}
