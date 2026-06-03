# Busca + Menus nativos + Settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar busca no documento (⌘F) e em todas as abas abertas (⇧⌘F) com barra dedicada, reorganizar os pontos de entrada em menus nativos (`File > Open`, `Edit > Find`), limpar a toolbar customizada e mover o seletor de Tema para Settings (⌘,).

**Architecture:** A busca opera sobre o HTML renderizado em cada `WKWebView` via JS injetado no `renderer.html`. Um `SearchState` (ObservableObject) guarda o estado e delega a lógica de navegação multi-aba a um value type puro e testável (`SearchMatchMap`). Cada `MarkdownView.Coordinator` se registra no `SearchState` como `DocumentSearchController`, e o `ContentView` orquestra a passada de busca assíncrona entre as abas e a troca automática de aba.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, WebKit (`WKWebView`), Swift Testing (`import Testing`), SwiftPM. macOS 13+.

> ⚠️ **Ambiente de build:** este repositório roda num devcontainer **Linux**, mas o app é **macOS-only**. `swift build` e `swift test` precisam ser executados no **macOS** (alvo real). Os passos de "rodar teste / build" abaixo assumem execução no macOS.

---

## File Structure

**Novos arquivos:**
- `Sources/MacDown/Models/SearchMatchMap.swift` — value type puro: mapeia índice global → (aba, local) e navegação com wrap-around.
- `Sources/MacDown/Models/SearchState.swift` — ObservableObject: estado da busca, registro de controllers, navegação.
- `Sources/MacDown/Models/DocumentSearchController.swift` — protocolo da ponte de busca por documento.
- `Sources/MacDown/Views/FindBarView.swift` — barra de busca dedicada.
- `Sources/MacDown/Views/SettingsView.swift` — tela de Settings com seletor de Tema.
- `Tests/MacDownTests/Models/SearchMatchMapTests.swift` — testes do value type puro.
- `Tests/MacDownTests/Models/SearchStateTests.swift` — testes do ObservableObject.

**Arquivos modificados:**
- `Sources/MacDown/Resources/renderer.html` — funções JS de busca + estilos de destaque.
- `Sources/MacDown/Views/MarkdownView.swift` — conformar Coordinator a `DocumentSearchController`, registrar/desregistrar no `SearchState`.
- `Sources/MacDown/Views/ContentView.swift` — hospedar `FindBarView`, orquestrar busca, remover `.toolbar`.
- `Sources/MacDown/MacDownApp.swift` — reorganizar `.commands` (Open/Find), adicionar cena `Settings`, nomes de notificação.

---

## Task 1: SearchMatchMap (lógica pura de navegação)

**Files:**
- Create: `Sources/MacDown/Models/SearchMatchMap.swift`
- Test: `Tests/MacDownTests/Models/SearchMatchMapTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MacDownTests/Models/SearchMatchMapTests.swift`:

```swift
@testable import MacDown
import Testing

@Suite("SearchMatchMap Tests")
struct SearchMatchMapTests {

    @Test("Empty map has no matches")
    func testEmpty() {
        let map = SearchMatchMap(countsPerTab: [])
        #expect(map.total == 0)
        #expect(map.location(forGlobalIndex: 0) == nil)
        #expect(map.nextIndex(after: 0) == nil)
        #expect(map.previousIndex(before: 0) == nil)
    }

    @Test("Single tab maps indices and wraps")
    func testSingleTab() {
        let map = SearchMatchMap(countsPerTab: [3])
        #expect(map.total == 3)
        #expect(map.location(forGlobalIndex: 0)! == (tab: 0, local: 0))
        #expect(map.location(forGlobalIndex: 2)! == (tab: 0, local: 2))
        #expect(map.location(forGlobalIndex: 3) == nil)
        #expect(map.nextIndex(after: 2) == 0)        // wrap to first
        #expect(map.previousIndex(before: 0) == 2)   // wrap to last
    }

    @Test("Multi tab skips empty tabs")
    func testMultiTab() {
        let map = SearchMatchMap(countsPerTab: [3, 0, 5])
        #expect(map.total == 8)
        #expect(map.location(forGlobalIndex: 2)! == (tab: 0, local: 2))
        #expect(map.location(forGlobalIndex: 3)! == (tab: 2, local: 0)) // tab 1 has 0
        #expect(map.location(forGlobalIndex: 7)! == (tab: 2, local: 4))
        #expect(map.nextIndex(after: 7) == 0)
        #expect(map.previousIndex(before: 0) == 7)
    }
}
```

> Note: `(tab:local:)` tuples are compared with `==`; Swift compares same-labeled 2-tuples of `Int` automatically.

- [ ] **Step 2: Run tests to verify they fail**

Run (on macOS): `swift test --filter SearchMatchMapTests`
Expected: FAIL — `cannot find 'SearchMatchMap' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/MacDown/Models/SearchMatchMap.swift`:

```swift
import Foundation

/// Pure value type that maps a flat "global" match index across multiple tabs
/// to a concrete (tab, local) position, and handles wrap-around navigation.
struct SearchMatchMap: Equatable {
    /// Match count per tab, indexed in the same order as the open documents.
    let countsPerTab: [Int]

    init(countsPerTab: [Int] = []) {
        self.countsPerTab = countsPerTab
    }

    var total: Int { countsPerTab.reduce(0, +) }

    /// Maps a global index in `0..<total` to (tab, local). Returns nil if out of range.
    func location(forGlobalIndex global: Int) -> (tab: Int, local: Int)? {
        guard global >= 0, global < total else { return nil }
        var remaining = global
        for (tab, count) in countsPerTab.enumerated() {
            if remaining < count { return (tab, remaining) }
            remaining -= count
        }
        return nil
    }

    /// Next global index with wrap-around. Returns nil when there are no matches.
    func nextIndex(after current: Int) -> Int? {
        guard total > 0 else { return nil }
        return (current + 1) % total
    }

    /// Previous global index with wrap-around. Returns nil when there are no matches.
    func previousIndex(before current: Int) -> Int? {
        guard total > 0 else { return nil }
        return ((current - 1) % total + total) % total
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run (on macOS): `swift test --filter SearchMatchMapTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MacDown/Models/SearchMatchMap.swift Tests/MacDownTests/Models/SearchMatchMapTests.swift
git commit -m "feat: add SearchMatchMap for multi-tab search navigation"
```

---

## Task 2: DocumentSearchController protocol

**Files:**
- Create: `Sources/MacDown/Models/DocumentSearchController.swift`

This is a tiny interface with no behavior — no unit test (nothing to assert). It is consumed by `SearchState` (Task 3) and implemented by `MarkdownView.Coordinator` (Task 5).

- [ ] **Step 1: Write the protocol**

Create `Sources/MacDown/Models/DocumentSearchController.swift`:

```swift
import Foundation

/// Abstraction over a single rendered document (a WebView) that can run
/// text search inside its rendered HTML.
@MainActor
protocol DocumentSearchController: AnyObject {
    /// Highlights all case-insensitive occurrences of `query` and returns the match count.
    func highlight(_ query: String) async -> Int
    /// Marks occurrence `index` as the current one and scrolls it into view.
    func goToMatch(_ index: Int) async
    /// Removes all search highlights.
    func clearSearch() async
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/MacDown/Models/DocumentSearchController.swift
git commit -m "feat: add DocumentSearchController protocol"
```

---

## Task 3: SearchState (estado + navegação)

**Files:**
- Create: `Sources/MacDown/Models/SearchState.swift`
- Test: `Tests/MacDownTests/Models/SearchStateTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MacDownTests/Models/SearchStateTests.swift`:

```swift
@testable import MacDown
import Testing

@Suite("SearchState Tests")
struct SearchStateTests {

    @Test("updateCounts sets total and navigates to first match")
    @MainActor
    func testUpdateCounts() {
        let state = SearchState()
        var navigated: (tab: Int, local: Int)?
        state.onNavigate = { tab, local in navigated = (tab, local) }

        state.updateCounts([2, 0, 3])

        #expect(state.matchMap.total == 5)
        #expect(state.currentGlobalIndex == 0)
        #expect(navigated! == (tab: 0, local: 0))
    }

    @Test("goToNext moves and wraps across tabs")
    @MainActor
    func testGoToNextWraps() {
        let state = SearchState()
        var navigated: (tab: Int, local: Int)?
        state.onNavigate = { tab, local in navigated = (tab, local) }
        state.updateCounts([1, 2])   // total 3

        state.goToNext() // global 1 -> tab 1 local 0
        #expect(state.currentGlobalIndex == 1)
        #expect(navigated! == (tab: 1, local: 0))

        state.goToNext() // global 2 -> tab 1 local 1
        state.goToNext() // wrap to global 0 -> tab 0 local 0
        #expect(state.currentGlobalIndex == 0)
        #expect(navigated! == (tab: 0, local: 0))
    }

    @Test("goToPrevious wraps to last match")
    @MainActor
    func testGoToPreviousWraps() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        state.updateCounts([2, 1]) // total 3

        state.goToPrevious() // from 0 wraps to 2
        #expect(state.currentGlobalIndex == 2)
    }

    @Test("counterText formats human-friendly position")
    @MainActor
    func testCounterText() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        #expect(state.counterText == "0 de 0")
        state.updateCounts([3])
        #expect(state.counterText == "1 de 3")
        state.goToNext()
        #expect(state.counterText == "2 de 3")
    }

    @Test("close resets state")
    @MainActor
    func testClose() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        state.query = "hello"
        state.isVisible = true
        state.updateCounts([4])

        state.close()

        #expect(state.isVisible == false)
        #expect(state.query == "")
        #expect(state.matchMap.total == 0)
        #expect(state.currentGlobalIndex == 0)
    }

    @Test("activate sets mode and visibility")
    @MainActor
    func testActivate() {
        let state = SearchState()
        state.activate(mode: .allTabs)
        #expect(state.isVisible == true)
        #expect(state.mode == .allTabs)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (on macOS): `swift test --filter SearchStateTests`
Expected: FAIL — `cannot find 'SearchState' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/MacDown/Models/SearchState.swift`:

```swift
import SwiftUI

@MainActor
final class SearchState: ObservableObject {
    enum Mode: Equatable { case currentFile, allTabs }

    @Published var query: String = ""
    @Published var mode: Mode = .currentFile
    @Published var isVisible: Bool = false
    @Published private(set) var matchMap = SearchMatchMap()
    @Published private(set) var currentGlobalIndex: Int = 0

    /// Per-document search controllers (the rendered WebViews), keyed by `OpenDocument.id`.
    /// Populated by `MarkdownView` as tabs mount/unmount.
    private(set) var controllers: [UUID: DocumentSearchController] = [:]

    /// Wired by the view layer: switch to `tab` and scroll its WebView to occurrence `local`.
    var onNavigate: ((_ tab: Int, _ local: Int) -> Void)?

    func register(_ controller: DocumentSearchController, for id: UUID) {
        controllers[id] = controller
    }

    func unregister(for id: UUID) {
        controllers[id] = nil
    }

    func activate(mode: Mode) {
        self.mode = mode
        isVisible = true
    }

    func close() {
        isVisible = false
        query = ""
        matchMap = SearchMatchMap()
        currentGlobalIndex = 0
    }

    /// Replaces match counts (in document order) and navigates to the first match.
    func updateCounts(_ counts: [Int]) {
        matchMap = SearchMatchMap(countsPerTab: counts)
        currentGlobalIndex = 0
        navigateToCurrent()
    }

    func goToNext() {
        guard let next = matchMap.nextIndex(after: currentGlobalIndex) else { return }
        currentGlobalIndex = next
        navigateToCurrent()
    }

    func goToPrevious() {
        guard let prev = matchMap.previousIndex(before: currentGlobalIndex) else { return }
        currentGlobalIndex = prev
        navigateToCurrent()
    }

    /// Human-friendly counter: "X de Y" (1-based). "0 de 0" when empty.
    var counterText: String {
        guard matchMap.total > 0 else { return "0 de 0" }
        return "\(currentGlobalIndex + 1) de \(matchMap.total)"
    }

    private func navigateToCurrent() {
        guard let loc = matchMap.location(forGlobalIndex: currentGlobalIndex) else { return }
        onNavigate?(loc.tab, loc.local)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run (on macOS): `swift test --filter SearchStateTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MacDown/Models/SearchState.swift Tests/MacDownTests/Models/SearchStateTests.swift
git commit -m "feat: add SearchState with multi-tab navigation"
```

---

## Task 4: JS search bridge no renderer.html

**Files:**
- Modify: `Sources/MacDown/Resources/renderer.html`

Não há unit test (JS na WebView) — verificação manual no app. Adicione as funções de busca e os estilos de destaque.

- [ ] **Step 1: Add highlight styles**

Em `Sources/MacDown/Resources/renderer.html`, dentro do bloco `<style>` (após a regra `#content`), adicione:

```css
  mark.md-search {
    background: #ffe58f;
    color: inherit;
    border-radius: 2px;
    padding: 0 1px;
  }
  mark.md-search.current {
    background: #ff9d00;
  }
```

- [ ] **Step 2: Add the search JS functions**

No `<script>` que contém `render(...)`, adicione (dentro do mesmo `<script>`, após a função `render`):

```javascript
  var __searchMatches = [];
  var __currentMatch = -1;

  function clearSearch() {
    __searchMatches = [];
    __currentMatch = -1;
    var marks = document.querySelectorAll('mark.md-search');
    for (var i = 0; i < marks.length; i++) {
      var m = marks[i];
      var parent = m.parentNode;
      if (!parent) continue;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize();
    }
  }

  function searchHighlight(query) {
    clearSearch();
    if (!query) { return 0; }
    var content = document.getElementById('content');
    var needle = query.toLowerCase();
    var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
    var textNodes = [];
    var node;
    while ((node = walker.nextNode())) {
      var p = node.parentNode;
      if (p && p.nodeName !== 'SCRIPT' && p.nodeName !== 'STYLE' && p.nodeName !== 'MARK') {
        textNodes.push(node);
      }
    }
    for (var i = 0; i < textNodes.length; i++) {
      var tn = textNodes[i];
      var text = tn.nodeValue;
      var lower = text.toLowerCase();
      var idx = lower.indexOf(needle);
      if (idx === -1) { continue; }
      var frag = document.createDocumentFragment();
      var pos = 0;
      while (idx !== -1) {
        if (idx > pos) {
          frag.appendChild(document.createTextNode(text.slice(pos, idx)));
        }
        var mark = document.createElement('mark');
        mark.className = 'md-search';
        mark.textContent = text.slice(idx, idx + needle.length);
        frag.appendChild(mark);
        __searchMatches.push(mark);
        pos = idx + needle.length;
        idx = lower.indexOf(needle, pos);
      }
      if (pos < text.length) {
        frag.appendChild(document.createTextNode(text.slice(pos)));
      }
      if (tn.parentNode) {
        tn.parentNode.replaceChild(frag, tn);
      }
    }
    return __searchMatches.length;
  }

  function goToMatch(index) {
    if (index < 0 || index >= __searchMatches.length) { return; }
    if (__currentMatch >= 0 && __currentMatch < __searchMatches.length) {
      __searchMatches[__currentMatch].classList.remove('current');
    }
    __currentMatch = index;
    var el = __searchMatches[index];
    el.classList.add('current');
    el.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }
```

> Note: `render()` already replaces `#content.innerHTML` on every content update, which naturally drops old `mark` elements; the Swift side re-runs the search after content changes.

- [ ] **Step 3: Commit**

```bash
git add Sources/MacDown/Resources/renderer.html
git commit -m "feat: add JS search highlight bridge to renderer"
```

---

## Task 5: MarkdownView conforma a DocumentSearchController

**Files:**
- Modify: `Sources/MacDown/Views/MarkdownView.swift`

Verificação manual (WebView). O `MarkdownView` recebe o `id` do documento e o `SearchState` do ambiente, registra o Coordinator e expõe as chamadas JS.

- [ ] **Step 1: Add the document id + searchState to MarkdownView**

Em `Sources/MacDown/Views/MarkdownView.swift`, troque o topo da struct:

```swift
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
        context.coordinator.documentID = documentID
        context.coordinator.searchState = searchState
        searchState.register(context.coordinator, for: documentID)
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
```

> Keep the existing `makeCoordinator()`, `resolvedTheme`, and `loadRendererPage(in:)` unchanged.

- [ ] **Step 2: Extend the Coordinator with search support**

Replace the `Coordinator` class in `MarkdownView.swift` with:

```swift
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
                    continuation.resume(returning: (result as? Int) ?? 0)
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
```

- [ ] **Step 3: Build to verify it compiles**

Run (on macOS): `swift build`
Expected: builds without errors. (`ContentView` will be updated in Task 6 to pass `documentID:` and inject `searchState`; if building before Task 6, expect a missing-argument error at the `MarkdownView(...)` call site — that is fixed in Task 6.)

- [ ] **Step 4: Commit**

```bash
git add Sources/MacDown/Views/MarkdownView.swift
git commit -m "feat: make MarkdownView Coordinator a DocumentSearchController"
```

---

## Task 6: FindBarView

**Files:**
- Create: `Sources/MacDown/Views/FindBarView.swift`

Verificação manual. Barra com campo focado, contador, setas, indicador de modo, fechar; Enter = próxima, Shift+Enter = anterior, Escape = fecha.

- [ ] **Step 1: Write the view**

Create `Sources/MacDown/Views/FindBarView.swift`:

```swift
import SwiftUI

struct FindBarView: View {
    @EnvironmentObject var searchState: SearchState
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar", text: $searchState.query)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit { searchState.goToNext() }
                .frame(minWidth: 160)

            Text(searchState.counterText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Button { searchState.goToPrevious() } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(searchState.matchMap.total == 0)
            .help("Anterior")

            Button { searchState.goToNext() } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(searchState.matchMap.total == 0)
            .help("Próxima")

            Text(searchState.mode == .allTabs ? "Todas as abas" : "Arquivo")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            Button { searchState.close() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Fechar")

            // Hidden hotkey: Shift+Enter navigates to the previous match.
            Button("") { searchState.goToPrevious() }
                .keyboardShortcut(.return, modifiers: .shift)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onExitCommand { searchState.close() }
        .onAppear { fieldFocused = true }
        .onChange(of: searchState.isVisible) { visible in
            if visible { fieldFocused = true }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/MacDown/Views/FindBarView.swift
git commit -m "feat: add FindBarView search bar"
```

---

## Task 7: ContentView — hospedar a barra, orquestrar busca, limpar toolbar

**Files:**
- Modify: `Sources/MacDown/Views/ContentView.swift`

Verificação manual. Adiciona `SearchState`, hospeda `FindBarView`, orquestra a passada de busca assíncrona, troca de aba na navegação, e remove o `.toolbar`.

- [ ] **Step 1: Replace ContentView body and add orchestration**

Em `Sources/MacDown/Views/ContentView.swift`, substitua a struct `ContentView` (até antes de `func openFile()`/`presentOpenPanel`) por:

```swift
struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var theme: ThemeState

    @StateObject private var folderManager = FolderManager()
    @StateObject private var searchState = SearchState()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(store.recentsManager)
                .environmentObject(folderManager)
        } detail: {
            VStack(spacing: 0) {
                if searchState.isVisible {
                    FindBarView()
                        .environmentObject(searchState)
                    Divider()
                }

                if store.documents.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $store.activeIndex) {
                        ForEach(Array(store.documents.enumerated()), id: \.offset) { index, doc in
                            MarkdownView(content: doc.content, theme: theme.current, documentID: doc.id)
                                .environmentObject(searchState)
                                .tabItem { Text(doc.title) }
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.automatic)
                }
            }
        }
        .onAppear {
            searchState.onNavigate = { tab, local in
                if store.activeIndex != tab { store.activeIndex = tab }
                guard store.documents.indices.contains(tab) else { return }
                let id = store.documents[tab].id
                if let controller = searchState.controllers[id] {
                    Task { await controller.goToMatch(local) }
                }
            }
        }
        .onChange(of: searchState.query) { _ in runSearchPass() }
        .onChange(of: searchState.mode) { _ in runSearchPass() }
        .onChange(of: store.activeIndex) { _ in
            if searchState.isVisible && searchState.mode == .currentFile {
                runSearchPass()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateFindCurrentFile)) { _ in
            searchState.activate(mode: .currentFile)
            runSearchPass()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateFindAllTabs)) { _ in
            searchState.activate(mode: .allTabs)
            runSearchPass()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportFolderToWorkspace"))) { notification in
            if let url = notification.userInfo?["folderURL"] as? URL {
                try? folderManager.importFolder(url)
            }
        }
    }

    private func runSearchPass() {
        Task { await performSearch() }
    }

    @MainActor
    private func performSearch() async {
        let docs = store.documents
        let query = searchState.query
        let activeIndex = store.activeIndex
        var counts = [Int](repeating: 0, count: docs.count)

        for (i, doc) in docs.enumerated() {
            guard let controller = searchState.controllers[doc.id] else { continue }
            if query.isEmpty {
                await controller.clearSearch()
            } else if searchState.mode == .allTabs || i == activeIndex {
                counts[i] = await controller.highlight(query)
            } else {
                await controller.clearSearch()
            }
        }
        searchState.updateCounts(counts)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Nenhum arquivo aberto")
                .foregroundColor(.secondary)
            Button("Abrir arquivo…") { openFile() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func openFile() {
        presentOpenPanel(store: store)
    }
}
```

> The `.toolbar { ... }` block (Abrir / Salvar / Tema picker) is **removed entirely** — those moved to menus (Task 8) and Settings (Task 9). The `presentOpenPanel(store:)` free function below `ContentView` stays unchanged.

- [ ] **Step 2: Build to verify it compiles**

Run (on macOS): `swift build`
Expected: fails only on `.activateFindCurrentFile` / `.activateFindAllTabs` (defined in Task 8). Define those first or build after Task 8. To unblock building this task in isolation, you may temporarily define the notification names; otherwise proceed to Task 8 and build together.

- [ ] **Step 3: Commit**

```bash
git add Sources/MacDown/Views/ContentView.swift
git commit -m "feat: host find bar and orchestrate search in ContentView"
```

---

## Task 8: Menus nativos (File > Open, Edit > Find) + notification names

**Files:**
- Modify: `Sources/MacDown/MacDownApp.swift`

Verificação manual. Reorganiza `.commands` em submenus agrupadores com ícone; define os nomes de notificação da busca.

- [ ] **Step 1: Add notification names**

Em `Sources/MacDown/MacDownApp.swift`, no topo do arquivo (após os `import`), adicione:

```swift
extension Notification.Name {
    static let activateFindCurrentFile = Notification.Name("ActivateFindCurrentFile")
    static let activateFindAllTabs = Notification.Name("ActivateFindAllTabs")
}
```

- [ ] **Step 2: Replace the `.commands` block**

Substitua todo o `.commands { ... }` em `MacDownApp` por:

```swift
        .commands {
            CommandGroup(replacing: .newItem) {
                Menu {
                    Button("Abrir arquivo…") {
                        presentOpenPanel()
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button("Adicionar pasta ao Workspace") {
                        addFolderToWorkspace()
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])

                    Button("Abrir pasta") {
                        openNewWindowWithFolder()
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                } label: {
                    Label("Open", systemImage: "folder")
                }
            }

            CommandGroup(after: .textEditing) {
                Menu {
                    Button("Buscar no arquivo") {
                        NotificationCenter.default.post(name: .activateFindCurrentFile, object: nil)
                    }
                    .keyboardShortcut("f", modifiers: .command)

                    Button("Buscar em todas as abas") {
                        NotificationCenter.default.post(name: .activateFindAllTabs, object: nil)
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
            }
        }
```

- [ ] **Step 3: Build and verify menus**

Run (on macOS): `swift build` then launch the app.
Expected: `File` menu shows a **Open ▸** submenu with the three items and their shortcuts (greyed/muted on the right); `Edit` menu shows a **Find ▸** submenu with the two search items. ⌘F / ⇧⌘F open the find bar.

> If the submenu icon ("folder" / "magnifyingglass") does NOT appear on the `Open`/`Find` group items in the native menu bar, add a post-launch fixup in `AppDelegate.applicationDidFinishLaunching`: walk `NSApp.mainMenu`, find the submenu items by title ("Open", "Find") and set `item.image = NSImage(systemSymbolName: ..., accessibilityDescription: nil)`. Leaf items get no image.

- [ ] **Step 4: Commit**

```bash
git add Sources/MacDown/MacDownApp.swift
git commit -m "feat: group Open/Find actions into native menu submenus"
```

---

## Task 9: Settings (⌘,) com seletor de Tema

**Files:**
- Create: `Sources/MacDown/Views/SettingsView.swift`
- Modify: `Sources/MacDown/MacDownApp.swift`

Verificação manual.

- [ ] **Step 1: Write the SettingsView**

Create `Sources/MacDown/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeState

    var body: some View {
        Form {
            Picker("Tema", selection: $theme.current) {
                Text("Claro").tag(AppTheme.light)
                Text("Escuro").tag(AppTheme.dark)
                Text("Sistema").tag(AppTheme.system)
            }
            .pickerStyle(.inline)
        }
        .padding(20)
        .frame(width: 360)
    }
}
```

- [ ] **Step 2: Add the Settings scene**

Em `Sources/MacDown/MacDownApp.swift`, dentro de `var body: some Scene`, **após** o `WindowGroup { ... }` (e antes do/depois do `.commands` — como cena irmã do `WindowGroup`), adicione:

```swift
        Settings {
            SettingsView()
                .environmentObject(ThemeState.shared)
        }
```

> The `Settings` scene is a sibling of `WindowGroup` inside the `@SceneBuilder` body. macOS automatically adds the **MacDown > Settings…** menu item with the **⌘,** shortcut.

- [ ] **Step 3: Build and verify**

Run (on macOS): `swift build`, launch, press ⌘, (or MacDown > Settings…).
Expected: a Settings window opens with the Tema picker (Claro/Escuro/Sistema); changing it updates the rendered preview's theme, and the choice persists across relaunch (via `ThemeState`'s `UserDefaults`).

- [ ] **Step 4: Commit**

```bash
git add Sources/MacDown/Views/SettingsView.swift Sources/MacDown/MacDownApp.swift
git commit -m "feat: move theme picker into Settings scene (Cmd+,)"
```

---

## Task 10: Verificação manual ponta-a-ponta

**Files:** none (verificação)

- [ ] **Step 1: Build the full app**

Run (on macOS): `swift build`
Expected: builds clean.

- [ ] **Step 2: Run the full test suite**

Run (on macOS): `swift test`
Expected: all tests pass (SearchMatchMap + SearchState + existing suites).

- [ ] **Step 3: Manual checklist (no app em execução)**

- [ ] Toolbar não tem mais Abrir / Salvar / Tema.
- [ ] `File > Open ▸` com 3 itens e atalhos muted; ícone no agrupador.
- [ ] `Edit > Find ▸` com 2 itens e atalhos muted; ícone no agrupador.
- [ ] ⌘, abre Settings com seletor de Tema; muda tema e persiste após relaunch.
- [ ] ⌘F abre a barra; foco no campo; busca em tempo real destaca matches no arquivo ativo; contador "X de Y"; ↑/↓ e Enter/Shift+Enter navegam; ocorrência atual realçada e scroll até ela; Escape fecha e limpa.
- [ ] Com 2+ abas abertas, ⇧⌘F destaca em todas; navegação cruza abas trocando a aba ativa automaticamente; contador global "X de Y · NomeDoArquivo"; wrap-around da última para a primeira.
- [ ] Tema escuro: destaques de busca legíveis.

- [ ] **Step 4: Final commit (se houve ajustes manuais)**

```bash
git add -A
git commit -m "chore: verify search + menus + settings end-to-end"
```
