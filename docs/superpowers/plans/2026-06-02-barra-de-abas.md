# Barra de Abas Dedicada — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o `TabView` nativo (que quebrou ao remover a toolbar) por uma barra de abas customizada estilo navegador, com trocar/fechar/nova/reordenar abas e atalho Cmd+W.

**Architecture:** Uma `TabBarView` (SwiftUI) dirige `DocumentStore.activeIndex`. O conteúdo deixa de ser um `TabView` e passa a ser um `ZStack` com TODAS as `MarkdownView` montadas (apenas a ativa visível), preservando o registro das webviews no `SearchState` — do qual a busca multi-aba (⇧⌘F) depende. A reordenação por drag chama um novo `DocumentStore.move(from:to:)` que preserva o documento ativo.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, WebKit, SwiftPM, Swift Testing. macOS 13.

> ⚠️ **Ambiente de build:** devcontainer **Linux**, app **macOS-only**. `swift build`/`swift test` rodam no **macOS**. Os passos de build/teste abaixo assumem execução no Mac.

---

## File Structure

**Novos arquivos:**
- `Sources/MacDown/Views/TabBarView.swift` — barra de abas + item de aba + shape de canto arredondado + drop delegate de reordenação (tudo coeso num arquivo).
- `Tests/MacDownTests/DocumentStoreMoveTests.swift` — testes do `move(from:to:)`.

**Arquivos modificados:**
- `Sources/MacDown/Models/DocumentStore.swift` — adicionar `move(from:to:)`.
- `Sources/MacDown/Views/ContentView.swift` — trocar `TabView` por `TabBarView` + `ZStack`; atalho Cmd+W.

---

## Task 1: DocumentStore.move(from:to:)

**Files:**
- Modify: `Sources/MacDown/Models/DocumentStore.swift`
- Test: `Tests/MacDownTests/DocumentStoreMoveTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MacDownTests/DocumentStoreMoveTests.swift`:

```swift
@testable import MacDown
import Testing
import Foundation

@Suite("DocumentStore move Tests")
struct DocumentStoreMoveTests {

    @MainActor
    private func makeStore() -> DocumentStore {
        let store = DocumentStore()
        store.documents = [
            OpenDocument(url: URL(fileURLWithPath: "/tmp/a.md"), content: "A"),
            OpenDocument(url: URL(fileURLWithPath: "/tmp/b.md"), content: "B"),
            OpenDocument(url: URL(fileURLWithPath: "/tmp/c.md"), content: "C")
        ]
        return store
    }

    @Test("Move forward reorders documents")
    @MainActor
    func testMoveForward() {
        let store = makeStore()
        store.move(from: 0, to: 2)
        #expect(store.documents.map(\.title) == ["b", "c", "a"])
    }

    @Test("Move backward reorders documents")
    @MainActor
    func testMoveBackward() {
        let store = makeStore()
        store.move(from: 2, to: 0)
        #expect(store.documents.map(\.title) == ["c", "a", "b"])
    }

    @Test("Move preserves the active document (active was moved)")
    @MainActor
    func testMovePreservesActive() {
        let store = makeStore()
        store.activeIndex = 0 // active = "a"
        store.move(from: 0, to: 2)
        #expect(store.documents[store.activeIndex].title == "a")
    }

    @Test("Move keeps active pointing at an untouched doc")
    @MainActor
    func testMoveKeepsOtherActive() {
        let store = makeStore()
        store.activeIndex = 1 // active = "b"
        store.move(from: 0, to: 2) // -> [b, c, a]; b now at 0
        #expect(store.documents[store.activeIndex].title == "b")
    }

    @Test("Move with equal indices is a no-op")
    @MainActor
    func testMoveNoOp() {
        let store = makeStore()
        store.move(from: 1, to: 1)
        #expect(store.documents.map(\.title) == ["a", "b", "c"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (on macOS): `swift test --filter DocumentStoreMoveTests`
Expected: FAIL — `value of type 'DocumentStore' has no member 'move'`.

- [ ] **Step 3: Add the `move` method**

In `Sources/MacDown/Models/DocumentStore.swift`, add this method inside the `DocumentStore` class (e.g. immediately after the existing `close(at:)` method):

```swift
    /// Reorders an open document, preserving which document is active.
    /// `destination` is the target slot index in the current array.
    func move(from source: Int, to destination: Int) {
        guard documents.indices.contains(source), source != destination else { return }
        let activeID = activeDocument?.id
        let doc = documents.remove(at: source)
        let insertIndex = min(max(destination, 0), documents.count)
        documents.insert(doc, at: insertIndex)
        if let activeID, let newActive = documents.firstIndex(where: { $0.id == activeID }) {
            activeIndex = newActive
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run (on macOS): `swift test --filter DocumentStoreMoveTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MacDown/Models/DocumentStore.swift Tests/MacDownTests/DocumentStoreMoveTests.swift
git commit -m "feat: add DocumentStore.move preserving active document"
```

---

## Task 2: TabBarView

**Files:**
- Create: `Sources/MacDown/Views/TabBarView.swift`

Verificação manual (UI). Cria a barra de abas completa: a barra, o item de aba, um shape de canto superior arredondado (macOS 13-safe) e o drop delegate de reordenação.

- [ ] **Step 1: Write the file**

Create `Sources/MacDown/Views/TabBarView.swift` with EXACTLY:

```swift
import SwiftUI
import UniformTypeIdentifiers

/// Chrome-style horizontal tab bar for the open documents.
struct TabBarView: View {
    @EnvironmentObject var store: DocumentStore
    @State private var draggingID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(store.documents.enumerated()), id: \.element.id) { index, doc in
                    TabItemView(
                        title: doc.title,
                        isActive: index == store.activeIndex,
                        onSelect: { store.activeIndex = index },
                        onClose: { store.close(at: index) }
                    )
                    .onDrag {
                        draggingID = doc.id
                        return NSItemProvider(object: doc.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: TabDropDelegate(targetID: doc.id, store: store, draggingID: $draggingID)
                    )
                }

                Button {
                    presentOpenPanel(store: store)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderless)
                .help("Abrir arquivo")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .background(.bar)
    }
}

private struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 200)
        .background(
            TopRoundedRectangle(radius: 8)
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
    }
}

/// A rectangle with only its top corners rounded. macOS 13-safe (avoids
/// `UnevenRoundedRectangle`, which is macOS 14+).
private struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Live-reorders tabs as one is dragged over another.
private struct TabDropDelegate: DropDelegate {
    let targetID: UUID
    let store: DocumentStore
    @Binding var draggingID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID,
              let from = store.documents.firstIndex(where: { $0.id == draggingID }),
              let to = store.documents.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.move(from: from, to: to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
```

> Note: `TabDropDelegate` touches `@MainActor` `store` from `DropDelegate` callbacks. Under SwiftPM 5.9 default (non-strict) concurrency this compiles; the callbacks run on the main thread. If a future strict-concurrency build flags it, that is a separate concern.

- [ ] **Step 2: Commit**

```bash
git add Sources/MacDown/Views/TabBarView.swift
git commit -m "feat: add Chrome-style TabBarView with close/new/reorder"
```

---

## Task 3: ContentView — usar a barra de abas, ZStack e Cmd+W

**Files:**
- Modify: `Sources/MacDown/Views/ContentView.swift`

Verificação manual. Substitui o `TabView` por `TabBarView` + `ZStack` (todas as webviews montadas, só a ativa visível) e adiciona o atalho Cmd+W para fechar a aba ativa.

- [ ] **Step 1: Replace the `detail:` content and add `closeActiveTab()`**

In `Sources/MacDown/Views/ContentView.swift`, the `NavigationSplitView`'s `detail:` closure currently contains a `VStack` with `FindBarView`, the empty-state, and a `TabView`. Replace that entire `detail: { ... }` closure body with:

```swift
        } detail: {
            VStack(spacing: 0) {
                if !store.documents.isEmpty {
                    TabBarView()
                    Divider()
                }

                if searchState.isVisible {
                    FindBarView()
                        .environmentObject(searchState)
                    Divider()
                }

                if store.documents.isEmpty {
                    emptyState
                } else {
                    ZStack {
                        ForEach(Array(store.documents.enumerated()), id: \.element.id) { index, doc in
                            MarkdownView(content: doc.content, theme: theme.current, documentID: doc.id)
                                .environmentObject(searchState)
                                .opacity(index == store.activeIndex ? 1 : 0)
                                .allowsHitTesting(index == store.activeIndex)
                                .zIndex(index == store.activeIndex ? 1 : 0)
                        }
                    }
                }
            }
            .background(
                Group {
                    if !store.documents.isEmpty {
                        Button("") { closeActiveTab() }
                            .keyboardShortcut("w", modifiers: .command)
                            .hidden()
                    }
                }
            )
        }
```

Notes:
- `TabBarView` reads `DocumentStore` from the environment (already injected by the app / new-window path), so no explicit `.environmentObject` is needed.
- The `ForEach` id changes from `\.offset` to `\.element.id` so each document keeps a stable view identity (its WebView is preserved across reorder/close).
- The Cmd+W override is only attached while documents are open; with no docs, Cmd+W reverts to the default window-close behavior.

Then add this method to `ContentView` (e.g. right after `runSearchPass()`):

```swift
    private func closeActiveTab() {
        guard !store.documents.isEmpty else { return }
        store.close(at: store.activeIndex)
    }
```

Leave everything else in `ContentView` (the `.onAppear`, the `.onChange`/`.onReceive` modifiers, `performSearch`, `emptyState`, `openFile`, and the `presentOpenPanel` free function) UNCHANGED.

- [ ] **Step 2: Build to verify it compiles**

Run (on macOS): `swift build`
Expected: builds without errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/MacDown/Views/ContentView.swift
git commit -m "feat: replace TabView with custom tab bar and ZStack content"
```

---

## Task 4: Verificação manual ponta-a-ponta

**Files:** none.

- [ ] **Step 1: Build + test**

Run (on macOS): `swift build && swift test`
Expected: builds clean; all tests pass (incl. `DocumentStoreMoveTests`).

- [ ] **Step 2: Manual checklist (app rodando, com 2+ arquivos abertos)**

- [ ] Barra de abas aparece no topo do conteúdo, estilo navegador; aba ativa destacada e "conectada" ao conteúdo.
- [ ] Clicar numa aba troca o documento exibido.
- [ ] × fecha a aba (aparece no hover); fechar a última aba volta ao estado vazio e a janela permanece.
- [ ] [+] abre o seletor de arquivos.
- [ ] Arrastar uma aba reordena (com animação) e a aba ativa continua a mesma.
- [ ] Cmd+W fecha a aba ativa; sem abas, Cmd+W fecha a janela (padrão).
- [ ] Muitas abas → scroll horizontal na barra.
- [ ] **Regressão da busca:** ⇧⌘F ainda encontra e conta matches em abas inativas e troca de aba ao navegar (confirma que todas as webviews seguem montadas/registradas).
- [ ] ⌘F e destaque/scroll continuam funcionando (não regrediram).

- [ ] **Step 3: Final commit (se houve ajustes manuais)**

```bash
git add -A
git commit -m "chore: verify tab bar end-to-end"
```
