import SwiftUI
import WebKit

struct MarkdownView: NSViewRepresentable {
    let content: String
    let theme: AppTheme
    let documentID: UUID

    @EnvironmentObject var searchState: SearchState

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.documentID = documentID
        context.coordinator.searchState = searchState
        searchState.register(context.coordinator, for: documentID)
        loadRendererPage(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.documentID != documentID {
            context.coordinator.documentID = documentID
            context.coordinator.searchState = searchState
            searchState.register(context.coordinator, for: documentID)
        }
        context.coordinator.pendingContent = content
        context.coordinator.pendingTheme = resolvedTheme
        if !webView.isLoading {
            context.coordinator.flush()
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        if let id = coordinator.documentID {
            coordinator.searchState?.unregister(for: id)
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
        guard let url = Bundle.main.url(forResource: "renderer", withExtension: "html") else {
            assertionFailure("renderer.html not found in bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    final class Coordinator: NSObject, WKNavigationDelegate, DocumentSearchController {
        weak var webView: WKWebView?
        weak var searchState: SearchState?
        var documentID: UUID?
        var pendingContent: String?
        var pendingTheme: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            flush()
        }

        func flush() {
            guard let webView,
                  let content = pendingContent,
                  let theme = pendingTheme else { return }
            let jsonData = (try? JSONEncoder().encode(content)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "\"\""
            webView.evaluateJavaScript("render(\(jsonString), '\(theme)')", completionHandler: nil)
            pendingContent = nil
            pendingTheme = nil
        }

        // MARK: - DocumentSearchController

        private func encodeJS(_ string: String) -> String {
            let data = (try? JSONEncoder().encode(string)) ?? Data()
            return String(data: data, encoding: .utf8) ?? "\"\""
        }

        func highlight(_ query: String) async -> Int {
            guard let webView else { return 0 }
            let js = "searchHighlight(\(encodeJS(query)))"
            return await withCheckedContinuation { continuation in
                webView.evaluateJavaScript(js) { result, _ in
                    // WKWebView bridges JS numbers to NSNumber (double-backed),
                    // so cast through NSNumber rather than directly to Int.
                    let count = (result as? NSNumber)?.intValue ?? 0
                    continuation.resume(returning: count)
                }
            }
        }

        func goToMatch(_ index: Int) async {
            guard let webView else { return }
            await withCheckedContinuation { continuation in
                webView.evaluateJavaScript("goToMatch(\(index))") { _, _ in
                    continuation.resume()
                }
            }
        }

        func clearSearch() async {
            guard let webView else { return }
            await withCheckedContinuation { continuation in
                webView.evaluateJavaScript("clearSearch()") { _, _ in
                    continuation.resume()
                }
            }
        }
    }
}
