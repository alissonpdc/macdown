# Plan — MacDown

**Fonte da verdade de requisitos:** PRD.md
**Este arquivo:** ordem de implementação + checklist. Cada item só vira "done" com testes verdes (`swift test` = gate).

## Decisões técnicas

- Targets: `MacDown` (App SwiftUI) + `MacDownCore` (package local, lógica pura)
- Motor markdown: cmark-gfm (SwiftMarkdown) — AST testável
- Frontmatter: parser YAML mínimo próprio (chaves/listas); malformado → erro estruturado (R10.2)
- Arquitetura: MVVM; regra de ouro — toda lógica no Core, SwiftUI só desenha estado
- Deployment mínimo: macOS 14
- Testes: unit/integration desde a Fase 0; **UI tests a partir da Fase 3**
- Mermaid: WKWebView + mermaid.js local bundleado
- Rastreabilidade: todo requisito PRD tem ≥1 teste mapeado ao ID (R3.2 etc.)

## Regras TDD

- RED → GREEN → REFACTOR obrigatório por item
- Commit/suite: `swift test` verde é gate de aprovação
- Core: cobertura ~100% esperada; Views: testar estado do ViewModel

---

## Checklist

### Fase 0 — Esqueleto + CI
- [x] MacDownCore package local (SPM, macOS 14+) com test target
- [x] App target MacDown (SwiftUI) — MacDownApp.swift, ContentView.swift, SidebarView, TabBarView, ReaderTabView
- [x] Suite rodando verde (`swift test`)
- [x] Gate de teste documentado neste arquivo
- [x] CI GitHub Actions — `ci.yml` (build release falha com warning + `swift test` em branches/PRs) e `release.yml` (push main: build/test, `make app`, release automática com versionamento semver baseado em conventional commits + release notes)

### Fase 1 — MacDownCore (parse)
- [x] Parser swift-markdown (cmark-gfm) integrado ao Core
- [x] Modelo de blocos inicial (HeadingNode, TableNode, TaskListItemsNode, GenericBlockNode)
- [x] Fixtures GFM: tabelas, task lists, strikethrough, autolinks, footnotes (R3.1)
- [x] AST navegável: paragraph, code (linguagem), list/quote genéricos; outline+slug p/ TOC (R3.7/R3.8), TaskSummary (R3.13), PlainTextExtractor

### Fase 2 — Documento
- [x] Split frontmatter antes do parse
- [x] YAML mínimo: chaves, valores, listas (R3.4 base)
- [x] YAML malformado / não-suportado → erro estruturado (R10.2)
- [ ] NSDocument abrir arquivo único (R1.1, R1.2 base) — **não implementado**: app usa WindowGroup custom, não NSDocument. Arquivos abrem via NSOpenPanel.

### Fase 3 — ReaderView (+ início dos UI tests)
- [x] Renderização na tela — BlockView (heading, paragraph, code, quote, list, task list, table)
- [x] Tema Claro/Escuro/Sistema persistido (R9.1) — ThemeStore + MacDownApp menu
- [x] Tipografia leitura longa (R3.6) — ReadingPrefs (largura ajustável 50-120ch + zoom 12-24px) com persistência; CSS centraliza conteúdo com `max-width: var(--reading-width)`
- [ ] UI tests: abrir arquivo → conteúdo visível; trocar tema — **não implementado**: nenhum target UITests existe

### Fase 4 — Abas
- [x] TabState por documento, incluindo scroll position (R2.5) — TabStore
- [x] Tab bar estilo Chrome, fechar Cmd+W (R6.1) — TabBarView + Cmd+W menu
- [ ] Múltiplas janelas/arquivos (R1.3) — **não implementado**: app usa WindowGroup único com abas, não múltiplas janelas

### Fase 5 — Projeto
- [x] Scanner de pasta recursivo, filtro família md (R2.4) — FolderScanner
- [x] Sidebar árvore colapsável, arquivo ativo destacado (R2.1–R2.3) — SidebarView
- [x] Links internos relativos → nova aba (R3.5, R6.2) — ContentView onOpenLink
- [x] Histórico por aba (R6.3) — History + Navigate menu (Cmd+[/Cmd+])

### Fase 6 — FileWatcher + Diff
- [x] Watch arquivo aberto e árvore (FSEvents/DispatchSource) (R4.1, R4.3)
- [x] Rename/move externo atualiza abas/sidebar (R4.4)
- [x] Indicador discreto de atualizado (R4.2)
- [x] Diff engine puro: baseline→novo, rounds cumulativos, confirmar leitura (R13.1–R13.3)

### Fase 7 — Busca
- [x] Cmd+F no documento, ocorrências, destaque (R5.1)
- [x] Cmd+Shift+F global na pasta, resultados por arquivo (R5.2)

### Fase 8 — Polish incremental
- [x] Syntax highlighting completo (R3.2) — `SyntaxHighlighter`: lexer de uma passada ancorado (regra → token), nunca destaca dentro de strings/comentários; classes kw/st/cm/num/op/fn/ty; ~20 linguagens (swift, c/cpp/objc, java, kotlin, c#, js/ts, rust, go, php, python, ruby, bash/sh/zsh, sql, json, yaml, toml, html/xml/svg, css, diff) + aliases (js, ts, py, rb, golang, c++…); escape correto (& < >)
- [ ] Copiar Comando shell: limpar prompts/comentários/continuações (R3.2) — **não implementado**: botão "Copiar" copia código bruto. Sem opção "Copiar Comando".
- [x] Fold de código >30 linhas (R3.10) — blocos com >30 linhas rendem colapsados (`.code-block.folded`, max-height 500px + fade), botões com ícones SVG no code-header via `toggleFold()`; contraído permanece rolável vertical/horizontal (R3.10); threshold 30 em `MarkdownHTMLConverter.foldLineThreshold`
- [x] Outline/TOC bidirecional (R3.7) — TocPanelView lateral direito (Cmd+Shift+T, coluna redimensionável grow-only) + navegação por clique via âncoras + destaque da seção ativa ao rolar (scroll listener JS → WKScriptMessageHandler)
- [x] Âncoras com hover `#` (R3.8) — headings rendem `<a class="anchor" href="#slug">` visível no hover (`.anchor { opacity: 0 }` + `:hover`), clique executa `copyAnchor()` que copia `BASE_URL#slug` (BASE_URL injetado quando `baseFileURL` presente, senão `#slug`) com feedback `✓`
- [x] Tabelas largas rolam horizontal (R3.9) — **implementado**: CSS `.table-wrapper { overflow-x: auto; }` + `table { display: block; width: max-content; }`
- [x] Footer: breadcrumb + palavras/caracteres + tasks (R8.1, R3.13) — FooterInfo + FooterView
- [x] Validação: links quebrados, mermaid erro (R10.1) — **parcial**: `LinkValidator` valida links internos do corpo (frontmatter ignorado) — arquivo inexistente → `fileNotFound`, âncora `#slug` pura ou em `.md` alvo → `anchorNotFound` (slugs via `DocumentOutline`, dedupe de repetidos); externos/`mailto`/âncoras em não-md ignorados; suporta `%20` e `../`. Badge discreto laranja no footer (`FooterInfo.brokenLinks`) que abre popover com a lista; clicar num item rola até a 1ª ocorrência do link no documento com flash — links/imagens quebrados renderizados com `class="broken-link"` + `data-broken` (converter marca via `brokenHrefs`, CSS ondas laranja + outline tracejado). 6 testes em BrokenLinkRenderTests + 14 em LinkValidatorTests + 2 em FooterInfoTests. Mermaid erro: erros de sintaxe detectados via JS→Swift (`WKScriptMessageHandler macDownMermaidError`), exibidos inline (`.mermaid-error` div) + badge no footer.
- [x] Mermaid inline (R3.3) — `mermaid.min.js` (v11) bundleado no app (`Resources/`, copiado p/ `.app/Contents/Resources/` via Makefile); `MermaidLoader` copia p/ `/tmp` e injeta `<script src="file://...">` no HTML; `MarkdownHTMLConverter` detecta `language == "mermaid"` e renderiza `<div class="mermaid-container">` com código raw + botão copiar; CSS estiliza container; `mermaid.render()` via `DOMContentLoaded` com theme-aware (dark/light); erro → `.mermaid-error` visível. 12 testes em MermaidRenderTests.
- [x] Imagens locais relativas (R3.12) — `inlineMarkdown` converte `![alt](url)` para `<img>` (antes do regex de links); `imageURLSource` mantém URLs com scheme e resolve caminhos relativos contra a pasta do documento (`baseFileURL`, com `../` e %20); sem base mantém caminho relativo; CSS `img { max-width: 100% }`
- [x] Largura de leitura ajustável persistida (R3.11) — ReadingPrefs + menu "Reading Width" (Cmd+Opt+/-)
- [x] Zoom de texto Cmd+=/- persistido (R11.1) — ReadingPrefs + menu "Text Zoom" (Cmd+/-, Cmd+0 reset)
- [ ] Copiar como Contexto (R11.3) — **não implementado**
- [x] Grafo de apontamentos Mermaid em aba própria (R14) — `PointerGraphGenerator` (MacDownCore) escaneia pasta recursivamente, extrai links internos via regex, gera diagrama Mermaid `graph LR`; `ContentView.openPointerGraph()` cria .md temporário com bloco mermaid e abre em nova aba; menu "View > Pointer Graph". 19 testes em PointerGraphGeneratorTests.
- [ ] Renderização progressiva >500KB (R15.1) — **não implementado**
- [ ] Deep link macdown:// (R11.2) — **não implementado**
- [ ] CLI macdown (R12.1) — **parcial**: `LaunchArgs` existe mas sem binário/symlink instalável
- [x] Menu nativo + atalhos completos (R7.1) — File (⌘O, ⇧⌘O, ⌘W), Tabs (⌘←/→, Ctrl+Tab via TabShortcutMonitor), Navigate (⌘[/⌘], ⌘D), View (⇧⌘T TOC, ⌥⌘± width, ⌘±/⌘0 zoom), Find (⌘F, ⌘G/⇧⌘G, ⇧⌘F); ⌘Q nativo
- [ ] Acessibilidade: teclado sidebar/abas/TOC, VoiceOver, contraste 3 temas (R16.1) — **parcial**: 5 accessibilityLabels em Sidebar/TabBar, sem navegação completa por teclado ou VoiceOver
- [ ] Default handler onboarding (R1.2) — **não implementado**
