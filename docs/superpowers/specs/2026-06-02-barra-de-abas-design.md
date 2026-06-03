# Design: Barra de abas dedicada

**Data:** 2026-06-02
**Contexto:** Follow-up da remoção da toolbar customizada (branch `feat/busca-e-menus-nativos`).

---

## Problema

Ao remover a toolbar customizada, o `TabView(.automatic)` usado no painel de detalhe
do `ContentView` ficou com layout quebrado. Além disso, as abas nativas `.automatic`
não oferecem botão de fechar, então hoje **não há como fechar uma aba pela UI** (apesar
de `DocumentStore.close(at:)` já existir).

A solução é substituir o `TabView` por uma **barra de abas customizada** com gestão
completa (trocar, fechar, nova, reordenar) e atalho Cmd+W.

---

## Comportamento (UX)

- **Barra de abas** no topo da área de conteúdo, visível apenas quando há documentos
  abertos. Estilo navegador (Chrome): abas com topo arredondado; a aba ativa é
  destacada e "conecta" visualmente ao conteúdo abaixo.
- Cada aba mostra o **título do documento** e um botão **×** (visível no hover).
- **Clique** numa aba a torna ativa.
- **Arrastar** uma aba a reordena.
- **[+]** no fim da barra abre o seletor de arquivos (mesmo fluxo do "Abrir arquivo…").
- **Cmd+W** fecha a aba ativa.
- Fechar a **última** aba → volta ao **estado vazio** ("Nenhum arquivo aberto"); a
  janela permanece aberta.
- Com muitas abas, a barra faz **scroll horizontal**.
- **Ordem vertical** da área de detalhe: barra de abas → barra de busca (se visível) →
  conteúdo (ou estado vazio).

---

## Arquitetura técnica

### Ponto crítico: manter todas as WebViews montadas

A busca em todas as abas (⇧⌘F) depende de **todas** as `MarkdownView` estarem
instanciadas e registradas no `SearchState` (cada `Coordinator` se registra em
`makeNSView`). O `TabView` atual instancia o conteúdo de todas as abas, o que satisfaz
isso por acaso.

Ao trocar para uma barra customizada, **não** se pode renderizar apenas a aba ativa —
isso desregistraria as webviews inativas e quebraria a busca multi-aba.

**Solução:** substituir o `TabView` por um **`ZStack`** contendo **uma `MarkdownView`
por documento, todas montadas**; exibir apenas a ativa via `opacity` (1 para a ativa, 0
para as demais) e `allowsHitTesting(false)` nas ocultas. Vantagens:
- Todas as webviews permanecem vivas e registradas → busca multi-aba intacta.
- Cada aba preserva seu scroll/estado.
- Elimina o `TabView` nativo bugado.

### Componentes

**`TabBarView`** (novo, `Sources/MacDown/Views/TabBarView.swift`)
- Renderiza as abas a partir de `store.documents`; aba ativa = `store.activeIndex`.
- Layout: `ScrollView(.horizontal)` com `HStack` de `TabItemView`, seguido do botão
  `[+]`.
- `[+]` chama `presentOpenPanel(store:)`.
- Reordenação por **drag** (gesto de arrastar que chama `store.move(from:to:)`).
- Estilo navegador: topo arredondado, ativa com fundo do conteúdo e leve elevação.

**`TabItemView`** (no mesmo arquivo ou separado)
- Um item de aba: título (truncado) + botão **×** (aparece no hover) que chama
  `store.close(at: index)`.
- Clique no corpo da aba define `store.activeIndex = index`.

**`DocumentStore`** (modificar `Sources/MacDown/Models/DocumentStore.swift`)
- Adicionar `func move(from source: Int, to destination: Int)` que reordena
  `documents` **preservando o documento ativo** (guarda o `id` do ativo, reordena,
  recalcula `activeIndex` pelo `id`).
- Fechar continua usando o `close(at:)` existente (que já ajusta `activeIndex` e, ao
  esvaziar, deixa `documents` vazio → `ContentView` mostra o estado vazio).

**`ContentView`** (modificar)
- Substituir o `TabView { ForEach … MarkdownView … }` por:
  ```
  VStack(spacing: 0) {
      if !store.documents.isEmpty { TabBarView(); Divider() }
      if searchState.isVisible { FindBarView(); Divider() }
      if store.documents.isEmpty {
          emptyState
      } else {
          ZStack { /* uma MarkdownView por doc; ativa visível */ }
      }
  }
  ```
  (As `MarkdownView` continuam recebendo `.environmentObject(searchState)` e
  `documentID: doc.id`.)
- Adicionar um **botão oculto** com `.keyboardShortcut("w", modifiers: .command)` que
  fecha a aba ativa (`store.close(at: store.activeIndex)` quando há docs). Por estar na
  hierarquia da view, o atalho fica no escopo da janela em foco (sem broadcast global a
  outras janelas).
- `TabBarView` recebe o `store` via `@EnvironmentObject` (já injetado).

### Reordenação (drag)

A barra é horizontal e customizada, então a reordenação usa um gesto de arrastar sobre
as `TabItemView`. A implementação concreta (cálculo do índice de destino conforme a
posição do drag, animação) fica a cargo da fase de implementação, mas o contrato é:
ao soltar, chamar `store.move(from: origem, to: destino)`. Esta é a parte mais
trabalhosa do escopo.

---

## Testes

- **Unit (Swift Testing):**
  - `DocumentStore.move(from:to:)`: reordena corretamente e mantém `activeIndex`
    apontando para o mesmo documento (testar mover ativo e mover não-ativo).
  - `DocumentStore.close(at:)`: ajuste de `activeIndex` ao fechar antes/depois do ativo
    e ao esvaziar (se ainda não coberto).
- **Manual (no macOS):** aparência das abas (estilo navegador), ×, +, drag-reorder,
  Cmd+W, scroll horizontal com muitas abas, estado vazio ao fechar a última, e
  confirmar que ⇧⌘F ainda encontra matches em abas inativas (todas as webviews montadas).

---

## Fora de escopo
- Menu de contexto na aba (fechar outras, fechar à direita, etc.).
- Persistência da ordem das abas entre sessões.
- Pré-visualização/tooltip do caminho do arquivo na aba.
