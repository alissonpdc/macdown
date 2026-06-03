# MacDown

Editor/visualizador de Markdown nativo para macOS, escrito em Swift + SwiftUI. Renderiza Markdown via `marked.min.js` + `highlight.min.js` dentro de um `WKWebView`, com workspace de pastas, abas, busca e temas claro/escuro.

## Como trabalhar comigo (preferências do dono do projeto)

- **Idioma:** fale comigo em **português**. Discussões de feature/design sempre em português.
- **Swift:** não conheço a linguagem. Para código, arquitetura e organização, **pense profundamente e decida sozinho** — não me peça para validar decisões técnicas.
- **Evite jargão técnico de Swift** nas explicações; foque no comportamento e no resultado.
- **Só me pergunte sobre UI/UX e funcionalidade** — nunca sobre implementação.

## Fluxo de execução (obrigatório)

- Toda codificação (features, bugfixes, refinamentos) usa **subagent-driven-development** no modelo Sonnet mais atual.
- Planos antes de codar: use **writing-plans**; criação de features começa por **brainstorming**.
- Nunca implemente inline ou manualmente quando o fluxo de subagentes se aplica.
- Specs e planos ficam em `docs/superpowers/specs/` e `docs/superpowers/plans/` (nomeados por data, ex.: `2026-06-02-busca-e-menus-nativos-*`).

## Comandos

```bash
make build    # swift build -c release + empacota MacDown.app + codesign ad-hoc
make run      # build e abre o app
make test     # swift test
make clean     # remove .build e MacDown.app
swift build    # build debug rápido (sem empacotar .app)
```

- Toolchain: `swift-tools-version: 5.9`, alvo **macOS 13+**.
- Frameworks linkados: CoreServices, WebKit, UniformTypeIdentifiers.

## Arquitetura

Estrutura em `Sources/MacDown/`:

- **`MacDownApp.swift`** — entrada `@main`. Define a `Scene`, injeta `DocumentStore.shared` e `ThemeState.shared` no ambiente, monta os menus nativos (`.commands`) e a Settings scene (Cmd+,).
- **`AppDelegate.swift`** — integração com AppKit (abrir arquivos via Finder, "app padrão", etc.).
- **`Models/`** — lógica de estado, sem UI:
  - `DocumentStore` — abas/documentos abertos e aba ativa.
  - `FolderManager` / `FolderTreeNode` — workspace de pastas e árvore de arquivos.
  - `RecentsManager` — arquivos recentes.
  - `SearchState` / `DocumentSearchController` / `SearchMatchMap` — estado e orquestração da busca.
  - `OpenDocument` — modelo de um documento aberto.
- **`Views/`** — SwiftUI. `ContentView` é a raiz (`NavigationSplitView`: `SidebarView` + área de detalhe com `FindBarView`, `TabView` e `MarkdownView`).
- **`Theme/ThemeState.swift`** — tema atual; CSS em `Resources/themes/`.
- **`Resources/`** — `renderer.html`, `marked.min.js`, `highlight.min.js`, temas CSS. A renderização de Markdown acontece em JS dentro do `WKWebView` de `MarkdownView`.

### Convenções observadas

- Estado compartilhado via singletons `@EnvironmentObject` (`DocumentStore.shared`, `ThemeState.shared`).
- Comunicação UI ↔ menus por `Notification.Name` (ex.: `activateFindCurrentFile`).
- **Strings de UI em português** (rótulos de menu, botões).
- Models são testáveis e isolados de SwiftUI — testes em `Tests/MacDownTests/` espelham a pasta `Models/`. Mantenha lógica nova nos Models, com cobertura de testes.

