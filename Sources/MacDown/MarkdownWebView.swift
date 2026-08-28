import SwiftUI
import WebKit
import MarkdownCore

/// R10.1 — pedido de rolagem até um link quebrado (token crescente evita re-trigger).
struct BrokenLinkNavigateRequest: Equatable {
    let token: Int
    let href: String
}

/// Fase 7 (R5.2) — pedido de salto até uma ocorrência da busca (vinda da busca global).
/// O token crescente garante re-navegação mesmo com a mesma ocorrência atual.
struct SearchNavigateRequest: Equatable {
    let token: Int
    let ordinal: Int
}

/// Wrapper SwiftUI para WKWebView que renderiza markdown convertido para HTML.
struct MarkdownWebView: NSViewRepresentable {
    /// Canal de mensagens JS→Swift para a seção ativa (R3.7 sync inversa).
    static let tocMessageName = "macDownTOC"

    let html: String
    let scrollPosition: CGFloat
    let searchQuery: String
    let searchMatches: Int
    let searchCurrent: Int
    let searchOptions: SearchOptions
    let baseURL: URL?
    /// R3.7 — navegação do TOC: rola até o heading com o slug informado.
    var scrollToHeading: TocNavigateRequest?
    /// R10.1 — navegação do badge de links quebrados: rola até a 1ª ocorrência.
    var scrollToBrokenLink: BrokenLinkNavigateRequest?
    /// Fase 7 (R5.2) — salto até a ocorrência vinda da busca global.
    var scrollToMatch: SearchNavigateRequest?
    /// R3.7 — seção ativa detectada pelo scroll do conteúdo (nil = antes do 1º heading).
    var onActiveHeadingChange: (_ activeSlug: String?) -> Void = { _ in }
    let onOpenLink: (URL) -> Void

    init(html: String,
         scrollPosition: CGFloat = 0,
         searchQuery: String = "",
         searchMatches: Int = 0,
         searchCurrent: Int = 0,
         searchOptions: SearchOptions = [],
         baseURL: URL? = nil,
         scrollToHeading: TocNavigateRequest? = nil,
         scrollToBrokenLink: BrokenLinkNavigateRequest? = nil,
         scrollToMatch: SearchNavigateRequest? = nil,
         onActiveHeadingChange: @escaping (_ activeSlug: String?) -> Void = { _ in },
         onOpenLink: @escaping (URL) -> Void = { _ in }) {
        self.html = html
        self.scrollPosition = scrollPosition
        self.searchQuery = searchQuery
        self.searchMatches = searchMatches
        self.searchCurrent = searchCurrent
        self.searchOptions = searchOptions
        self.baseURL = baseURL
        self.scrollToHeading = scrollToHeading
        self.scrollToBrokenLink = scrollToBrokenLink
        self.scrollToMatch = scrollToMatch
        self.onActiveHeadingChange = onActiveHeadingChange
        self.onOpenLink = onOpenLink
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: Self.tocMessageName)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        let fullHTML = themedHTML(html)
        load(fullHTML, in: webView, coordinator: context.coordinator)

        return webView
    }

    /// R3.12 — imagens locais: `loadHTMLString` bloqueia subrecursos `file://`.
    /// Escreve o HTML em arquivo temporário e carrega com `loadFileURL`,
    /// concedendo acesso de leitura à pasta do documento.
    private func load(_ fullHTML: String, in webView: WKWebView, coordinator: Coordinator) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDownRender", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("render-\(UUID().uuidString).html")
        try? fullHTML.write(to: fileURL, atomically: true, encoding: .utf8)
        if let previous = coordinator.currentRenderFile {
            try? FileManager.default.removeItem(at: previous)
        }
        coordinator.currentRenderFile = fileURL
        // O arquivo temporário está em /tmp, fora da pasta do documento — o
        // WebKit exige que o HTML carregado esteja DENTRO da access root,
        // senão a navegação inteira falha (tela em branco). App sem sandbox:
        // raiz "/" cobre render + doc + imagens fora da pasta do doc.
        webView.loadFileURL(fileURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        if let file = coordinator.currentRenderFile {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // SwiftUI NÃO atualiza coordinator.parent: sem esta linha, didFinish lia
        // o struct da criação (query vazia, scroll 0) e perdia re-destaque/scroll.
        context.coordinator.parent = self

        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            // Mudança de busca na mesma atualização da recarga seria engolida
            // pelo return; didFinish executa via flag.
            context.coordinator.lastSearchQuery = searchQuery
            context.coordinator.lastSearchCurrent = searchCurrent
            context.coordinator.pendingSearchUpdate = !searchQuery.isEmpty
            let fullHTML = themedHTML(html)
            load(fullHTML, in: webView, coordinator: context.coordinator)
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
            // R3.7 — pausa o tracking do scroll durante a animação programática,
            // para não destacar seções intermediárias cruzadas no caminho.
            context.coordinator.beginProgrammaticScroll()
            if webView.isLoading {
                // Requisição chegou durante recarga: guarda p/ executar no didFinish,
                // senão o JS roda antes do documento existir e é perdido.
                context.coordinator.pendingTOCSlug = request.slug
            } else {
                scroll(to: request.slug, in: webView)
            }
        }

        if let request = scrollToBrokenLink,
           context.coordinator.lastBrokenLinkToken != request.token {
            context.coordinator.lastBrokenLinkToken = request.token
            if webView.isLoading {
                context.coordinator.pendingBrokenHref = request.href
            } else {
                jumpToBrokenLink(href: request.href, in: webView)
            }
        }

        // Fase 7 (R5.2) — salto até a ocorrência vinda da busca global. O token
        // força re-destaque/scroll mesmo sem mudança de query/current.
        if let request = scrollToMatch,
           context.coordinator.lastSearchToken != request.token {
            context.coordinator.lastSearchToken = request.token
            context.coordinator.lastSearchQuery = searchQuery
            context.coordinator.lastSearchCurrent = searchCurrent
            if webView.isLoading {
                context.coordinator.pendingSearchUpdate = true
            } else {
                highlightSearch(in: webView)
            }
        }

        if context.coordinator.lastSearchQuery != searchQuery ||
            context.coordinator.lastSearchCurrent != searchCurrent {
            context.coordinator.lastSearchQuery = searchQuery
            context.coordinator.lastSearchCurrent = searchCurrent
            if webView.isLoading {
                // Requisição chegou durante recarga: guarda p/ executar no
                // didFinish, senão o JS rola num documento incompleto.
                context.coordinator.pendingSearchUpdate = true
            } else {
                highlightSearch(in: webView)
            }
        }
    }

    private func themedHTML(_ html: String) -> String {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let css = isDark ? "dark" : "light"
        let themeScript = "<script>document.documentElement.setAttribute('data-theme', '\(css)');</script>"
        return html.replacingOccurrences(of: "</head>",
            with: themeScript + Self.activeHeadingTrackerJS + "</head>")
    }

    /// R3.7 (sync inversa) — escuta o scroll e reporta o último h1..h6 com id cujo
    /// top ficou acima do topo da viewport (+ tolerância). Throttle ~120ms e envia
    /// SOMENTE quando o id muda. O load event cobre reposicionamento pós-imagens.
    static let activeHeadingTrackerJS = """
    <script>
    (function(){
        if (window.__macDownTocTracking) return;
        window.__macDownTocTracking = true;
        var TOLERANCE = 40;
        var THROTTLE_MS = 120;
        var lastSentId = null, lastReportAt = 0, pendingTimer = null;
        function computeActive(){
            var headings = document.querySelectorAll('h1[id],h2[id],h3[id],h4[id],h5[id],h6[id]');
            var active = '';
            for (var i = 0; i < headings.length; i++){
                if (headings[i].getBoundingClientRect().top <= TOLERANCE){
                    active = headings[i].id;
                } else { break; }
            }
            return active;
        }
        function report(){
            pendingTimer = null;
            lastReportAt = Date.now();
            var id = computeActive();
            if (id !== lastSentId){
                lastSentId = id;
                try { window.webkit.messageHandlers.macDownTOC.postMessage(id); } catch(e) {}
            }
        }
        function schedule(){
            if (pendingTimer) return;
            var wait = Math.max(0, THROTTLE_MS - (Date.now() - lastReportAt));
            pendingTimer = setTimeout(report, wait);
        }
        window.addEventListener('scroll', schedule, {passive:true});
        window.addEventListener('load', schedule);
    })();
    </script>
    """

    /// R3.7 — rola até o heading com id = slug (gerado pelo MarkdownHTMLConverter).
    /// Caminho ÚNICO: posiciona o topo do heading com scroll suave (sem
    /// scrollIntoViewIfNeeded, que cancelava a animação e causava "pulo").
    /// Se a página ainda está carregando recursos, espera o evento `load`
    /// para que as posições dos headings estejam finais na 1ª tentativa.
    private func scroll(to slug: String, in webView: WKWebView) {
        let escaped = slug.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("""
        (function(){
            var slug = '\(escaped)';
            function jump(){
                var el = document.getElementById(slug);
                if (!el) return;
                requestAnimationFrame(function(){
                    requestAnimationFrame(function(){
                        el.scrollIntoView({behavior:'smooth', block:'start'});
                    });
                });
            }
            if (document.readyState === 'complete') {
                jump();
            } else {
                window.addEventListener('load', function(){ jump(); }, {once:true});
            }
        })();
        """)
    }

    /// R10.1 — rola até a 1ª ocorrência do link quebrado (a[data-broken] ou img[data-broken]),
    /// com flash de destaque para identificação rápida.
    private func jumpToBrokenLink(href: String, in webView: WKWebView) {
        let escaped = href.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("""
        (function(){
            var href = '\(escaped)';
            var els = document.querySelectorAll('[data-broken]');
            for (var i = 0; i < els.length; i++){
                if (els[i].getAttribute('data-broken') === href){
                    els[i].scrollIntoView({behavior:'smooth', block:'center'});
                    els[i].classList.remove('broken-flash');
                    void els[i].offsetWidth; // reinicia a animação
                    els[i].classList.add('broken-flash');
                    setTimeout(function(el){ el.classList.remove('broken-flash'); }.bind(null, els[i]), 1700);
                    return;
                }
            }
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

        // Fonte do padrão regex construída no Swift (fonte única com o SearchEngine):
        // modo normal escapa metacaracteres; modo regex usa o termo como está.
        var pattern = searchOptions.contains(.regex)
            ? searchQuery
            : Self.regexEscaped(searchQuery)
        if searchOptions.contains(.wholeWord) {
            pattern = "\\b" + pattern + "\\b"
        }
        let flags = searchOptions.contains(.caseSensitive) ? "g" : "gi"
        // O contador (SearchEngine) casa sobre o texto contíguo do AST, mas o
        // render quebra o texto em vários text nodes (syntax highlight, strong,
        // em, links, code). Casar por text node deixava matches invisíveis e o
        // salto nunca acontecia. Aqui o texto é concatenado na ordem do DOM e
        // o match pode atravessar nós — a ocorrência é então envolvida em
        // spans por segmento. Se o total do DOM divergir do do Swift, o índice
        // corrente é reencaixado (mod) para que Enter sempre mova o destaque.
        let js = """
        (function(){
            function escapeHTML(s){
                return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
            }
            document.querySelectorAll('.search-match,.search-current').forEach(function(el){
                var t = document.createTextNode(el.textContent);
                el.parentNode.replaceChild(t, el);
            });
            var body = document.body;
            if (!body) return 0;
            body.normalize();
            var re;
            try { re = new RegExp('\(Self.jsStringLiteral(pattern))', '\(flags)'); }
            catch (e) { return 0; }
            var walk = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {
                acceptNode: function(n){
                    var p = n.parentNode && n.parentNode.nodeName;
                    return (p === 'SCRIPT' || p === 'STYLE') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
                }
            });
            var nodes = [], starts = [], combined = '';
            while (walk.nextNode()){
                starts.push(combined.length);
                combined += walk.currentNode.nodeValue;
                nodes.push(walk.currentNode);
            }
            var matches = [];
            re.lastIndex = 0;
            var m;
            while ((m = re.exec(combined)) !== null){
                if (m[0].length === 0) { re.lastIndex++; continue; }
                matches.push({s: m.index, e: m.index + m[0].length, cur: matches.length === \(searchCurrent)});
            }
            nodes.forEach(function(node, i){
                var start = starts[i], end = start + node.nodeValue.length;
                var segs = [];
                for (var k = 0; k < matches.length; k++){
                    var s = Math.max(matches[k].s, start), e = Math.min(matches[k].e, end);
                    if (s < e) segs.push({s: s - start, e: e - start, cur: matches[k].cur});
                }
                if (!segs.length) return;
                var text = node.nodeValue, html = '', last = 0;
                segs.forEach(function(seg){
                    html += escapeHTML(text.substring(last, seg.s));
                    html += '<span class="' + (seg.cur ? 'search-current' : 'search-match') + '">' + escapeHTML(text.substring(seg.s, seg.e)) + '</span>';
                    last = seg.e;
                });
                html += escapeHTML(text.substring(last));
                var span = document.createElement('span');
                span.innerHTML = html;
                node.parentNode.replaceChild(span, node);
            });
            var cur = document.querySelector('.search-current');
            if (!cur && matches.length){
                var all = document.querySelectorAll('.search-match');
                cur = all[\(searchCurrent) % all.length];
                if (cur) cur.className = 'search-current';
            }
            if (cur) cur.scrollIntoView({behavior:'smooth', block:'center'});
            return matches.length;
        })();
        """
        webView.evaluateJavaScript(js)
    }

    /// Escapa metacaracteres de RegExp para busca literal.
    static func regexEscaped(_ s: String) -> String {
        var out = ""
        for ch in s {
            if "\\^$.|?*+()[]{}".contains(ch) { out += "\\" }
            out += String(ch)
        }
        return out
    }

    /// Escapa uma string para ser embutida como literal JS com aspas simples.
    static func jsStringLiteral(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "\\": out += "\\\\"
            case "'": out += "\\'"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out += String(ch)
            }
        }
        return out
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        var lastHTML: String = ""
        var pendingScroll: CGFloat = -1
        var lastSearchQuery: String = ""
        var lastSearchCurrent: Int = 0
        var lastSearchToken: Int = 0
        /// Fase 7 — destaque/scroll aguardando o fim da navegação p/ executar.
        var pendingSearchUpdate = false
        var lastTOCToken: Int = 0
        var lastBrokenLinkToken: Int = 0
        /// R10.1 — href aguardando o fim da navegação para executar o salto.
        var pendingBrokenHref: String?
        /// R3.7 — slug aguardando o fim da navegação para executar o scroll.
        var pendingTOCSlug: String?
        /// R3.7 — tracking do scroll suspenso durante a animação TOC→conteúdo.
        private(set) var suppressTOCFeedback = false
        private var lastSuppressedActiveSlug: String?
        /// R3.12 — arquivo HTML temporário em uso, removido na próxima recarga.
        var currentRenderFile: URL?

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        /// Pausa o destaque por ~650ms (duração da animação suave), evitando que
        /// seções intermediárias pisquem no TOC. O último id reportado durante a
        /// pausa é aplicado ao retomar.
        func beginProgrammaticScroll() {
            suppressTOCFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self else { return }
                self.suppressTOCFeedback = false
                if let id = self.lastSuppressedActiveSlug {
                    self.lastSuppressedActiveSlug = nil
                    self.parent.onActiveHeadingChange(id.isEmpty ? nil : id)
                }
            }
        }

        // MARK: WKScriptMessageHandler (JS → Swift)

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == MarkdownWebView.tocMessageName,
                  let id = message.body as? String else { return }
            if suppressTOCFeedback {
                lastSuppressedActiveSlug = id
                return
            }
            parent.onActiveHeadingChange(id.isEmpty ? nil : id)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                // Anchor links (#section) — WebKit handles in-page scroll.
                // R3.12: com loadFileURL a âncora in-page carrega scheme file +
                // mesmo path do render temporário; link para outro arquivo tem
                // path diferente e cai no onOpenLink abaixo.
                if url.fragment != nil, url.path == webView.url?.path {
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
            // R3.7 — executa salto do TOC que chegou durante o carregamento
            if let slug = pendingTOCSlug {
                pendingTOCSlug = nil
                parent.scroll(to: slug, in: webView)
            }
            // R10.1 — salto para link quebrado que chegou durante o carregamento
            if let href = pendingBrokenHref {
                pendingBrokenHref = nil
                parent.jumpToBrokenLink(href: href, in: webView)
            }
            // Fase 7 — destaque da busca (veio em fila durante a recarga, ou
            // termo já ativo numa recarga disparada pelo watcher).
            if pendingSearchUpdate || !parent.searchQuery.isEmpty {
                pendingSearchUpdate = false
                parent.highlightSearch(in: webView)
            }
        }
    }
}
