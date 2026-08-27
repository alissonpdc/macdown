import SwiftUI
import WebKit

/// Wrapper SwiftUI para WKWebView que renderiza markdown convertido para HTML.
struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let scrollPosition: CGFloat
    let searchQuery: String
    let searchMatches: Int
    let searchCurrent: Int
    let baseURL: URL?
    /// R3.7 — navegação do TOC: rola até o heading com o slug informado.
    var scrollToHeading: TocNavigateRequest?
    let onOpenLink: (URL) -> Void

    init(html: String,
         scrollPosition: CGFloat = 0,
         searchQuery: String = "",
         searchMatches: Int = 0,
         searchCurrent: Int = 0,
         baseURL: URL? = nil,
         scrollToHeading: TocNavigateRequest? = nil,
         onOpenLink: @escaping (URL) -> Void = { _ in }) {
        self.html = html
        self.scrollPosition = scrollPosition
        self.searchQuery = searchQuery
        self.searchMatches = searchMatches
        self.searchCurrent = searchCurrent
        self.baseURL = baseURL
        self.scrollToHeading = scrollToHeading
        self.onOpenLink = onOpenLink
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        let fullHTML = themedHTML(html)
        webView.loadHTMLString(fullHTML, baseURL: baseURL)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            let fullHTML = themedHTML(html)
            webView.loadHTMLString(fullHTML, baseURL: baseURL)
            return
        }

        if context.coordinator.pendingScroll != scrollPosition {
            context.coordinator.pendingScroll = scrollPosition
            let js = "window.scrollTo(0, \(scrollPosition));"
            webView.evaluateJavaScript(js)
        }

        if let request = scrollToHeading,
           context.coordinator.lastTOCToken != request.token {
            context.coordinator.lastTOCToken = request.token
            scroll(to: request.slug, in: webView)
        }

        if context.coordinator.lastSearchQuery != searchQuery ||
            context.coordinator.lastSearchCurrent != searchCurrent {
            context.coordinator.lastSearchQuery = searchQuery
            context.coordinator.lastSearchCurrent = searchCurrent
            highlightSearch(in: webView)
        }
    }

    private func themedHTML(_ html: String) -> String {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let css = isDark ? "dark" : "light"
        return html.replacingOccurrences(of: "</head>",
            with: "<script>document.documentElement.setAttribute('data-theme', '\(css)');</script></head>")
    }

    /// R3.7 — rola até o heading com id = slug (gerado pelo MarkdownHTMLConverter).
    /// Slugs já são url/texto seguros, mas o escape evita quebra do JS.
    private func scroll(to slug: String, in webView: WKWebView) {
        let escaped = slug.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("""
        (function(){
            var el = document.getElementById('\(escaped)');
            if (!el) return;
            el.scrollIntoView({behavior:'smooth', block:'start'});
            if (el.scrollIntoViewIfNeeded) el.scrollIntoViewIfNeeded(true);
        })();
        """)
    }

    private func highlightSearch(in webView: WKWebView) {
        guard !searchQuery.isEmpty else {
            webView.evaluateJavaScript("""
            document.querySelectorAll('.search-match,.search-current').forEach(function(e){
                var t = document.createTextNode(e.textContent);
                e.parentNode.replaceChild(t, e);
            });
            """)
            return
        }

        let escaped = searchQuery.replacingOccurrences(of: "\\", with: "\\\\")
                                  .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function(){
            document.querySelectorAll('.search-match,.search-current').forEach(function(el){
                var t = document.createTextNode(el.textContent);
                el.parentNode.replaceChild(t, el);
            });
            var q = '\(escaped)';
            var body = document.body;
            if (!body) return;
            var walk = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, null, false);
            var nodes = [];
            while(walk.nextNode()) nodes.push(walk.currentNode);
            var idx = 0;
            var current = \(searchCurrent);
            var escapedQ = q.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
            var re = new RegExp(escapedQ, 'gi');
            nodes.forEach(function(node){
                var text = node.nodeValue;
                re.lastIndex = 0;
                var match;
                var html = '';
                var last = 0;
                while((match = re.exec(text)) !== null){
                    html += text.substring(last, match.index);
                    var cls = idx === current ? 'search-current' : 'search-match';
                    html += '<span class="' + cls + '">' + text.substring(match.index, match.index + match[0].length) + '</span>';
                    last = match.index + match[0].length;
                    idx++;
                }
                if (html) {
                    html += text.substring(last);
                    var span = document.createElement('span');
                    span.innerHTML = html;
                    node.parentNode.replaceChild(span, node);
                }
            });
            var cur = document.querySelector('.search-current');
            if (cur) cur.scrollIntoView({behavior:'smooth', block:'center'});
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        var lastHTML: String = ""
        var pendingScroll: CGFloat = -1
        var lastSearchQuery: String = ""
        var lastSearchCurrent: Int = 0
        var lastTOCToken: Int = 0

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                // Anchor links (#section) — WebKit handles in-page scroll
                if url.fragment != nil && url.host == nil && url.scheme == nil {
                    decisionHandler(.allow)
                    return
                }
                if url.scheme == "file" || url.host == nil {
                    parent.onOpenLink(url)
                    decisionHandler(.cancel)
                } else {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if parent.scrollPosition > 0 {
                let js = "window.scrollTo(0, \(parent.scrollPosition));"
                webView.evaluateJavaScript(js)
            }
            // R3.7 — re-aplica o último salto do TOC após recarga do HTML
            if let request = parent.scrollToHeading {
                parent.scroll(to: request.slug, in: webView)
            }
            if !parent.searchQuery.isEmpty {
                parent.highlightSearch(in: webView)
            }
        }
    }
}
