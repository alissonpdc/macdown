import SwiftUI
import WebKit

struct MarkdownView: NSViewRepresentable {
    let content: String
    let theme: AppTheme

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        loadRendererPage(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingContent = content
        context.coordinator.pendingTheme = resolvedTheme
        if !webView.isLoading {
            context.coordinator.flush()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var resolvedTheme: String {
        switch theme {
        case .light: return "light"
        case .dark: return "dark"
        case .system:
            return NSApp.effectiveAppearance.name == .darkAqua ? "dark" : "light"
        }
    }

    private func loadRendererPage(in webView: WKWebView) {
        guard let url = Bundle.module.url(forResource: "renderer", withExtension: "html",
                                          subdirectory: "Resources") else {
            assertionFailure("renderer.html not found in bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var pendingContent: String?
        var pendingTheme: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            flush()
        }

        func flush() {
            guard let webView,
                  let content = pendingContent,
                  let theme = pendingTheme else { return }
            let jsonData = (try? JSONSerialization.data(withJSONObject: content)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "\"\""
            webView.evaluateJavaScript("render(\(jsonString), '\(theme)')", completionHandler: nil)
        }
    }
}
