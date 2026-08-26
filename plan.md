# Plan — MacDown

**Fonte da verdade de requisitos:** PRD.md
**Este arquivo:** ordem de implementação + checklist. Cada item só vira "done" com testes verdes (`xcodebuild test` = gate).

## Decisões técnicas

- Targets: `MacDown` (App SwiftUI) + `MarkdownCore` (package local, lógica pura)
- Motor markdown: cmark-gfm (SwiftMarkdown) — AST testável
- Frontmatter: parser YAML mínimo próprio (chaves/listas); malformado → erro estruturado (R10.2)
- Arquitetura: MVVM; regra de ouro — toda lógica no Core, SwiftUI só desenha estado
- Deployment mínimo: macOS 14
- Testes: unit/integration desde a Fase 0; **UI tests a partir da Fase 3**
- Mermaid: WKWebView + mermaid.js local bundleado
- Rastreabilidade: todo requisito PRD tem ≥1 teste mapeado ao ID (R3.2 etc.)

## Regras TDD

- RED → GREEN → REFACTOR obrigatório por item
- Commit/suite: `xcodebuild test` verde é gate de aprovação
- Core: cobertura ~100% esperada; Views: testar estado do ViewModel

---

## Checklist

### Fase 0 — Esqueleto + CI
- [x] MarkdownCore package local (SPM, macOS 14+) com test target
- [ ] App target MacDown (SwiftUI)
- [x] Suite rodando verde (`swift test`)
- [x] Gate de teste documentado neste arquivo

### Fase 1 — MarkdownCore (parse)
- [x] Parser swift-markdown (cmark-gfm) integrado ao Core
- [x] Modelo de blocos inicial (HeadingNode, TableNode, TaskListItemsNode, GenericBlockNode)
- [x] Fixtures GFM: tabelas, task lists, strikethrough, autolinks, footnotes (R3.1)
- [x] AST navegável: paragraph, code (linguagem), list/quote genéricos; outline+slug p/ TOC (R3.7/R3.8), TaskSummary (R3.13), PlainTextExtractor

### Fase 2 — Documento
- [x] Split frontmatter antes do parse
- [x] YAML mínimo: chaves, valores, listas (R3.4 base)
- [x] YAML malformado / não-suportado → erro estruturado (R10.2)
- [ ] NSDocument abrir arquivo único (R1.1, R1.2 base)

### Fase 3 — ReaderView (+ início dos UI tests)
- [ ] Renderização na tela (markdown → AttributedString/HTML)
- [ ] Tema Claro/Escuro/Sistema persistido (R9.1)
- [ ] Tipografia leitura longa (R3.6)
- [ ] UI tests: abrir arquivo → conteúdo visível; trocar tema

### Fase 4 — Abas
- [ ] TabState por documento, incluindo scroll position (R2.5 desde já)
- [ ] Tab bar estilo Chrome, fechar Cmd+W (R6.1)
- [ ] Múltiplas janelas/arquivos (R1.3)

### Fase 5 — Projeto
- [ ] Scanner de pasta recursivo, filtro família md (R2.4) — lógica pura TDD
- [ ] Sidebar árvore colapsável, arquivo ativo destacado (R2.1–R2.3)
- [ ] Links internos relativos → nova aba (R3.5, R6.2)
- [ ] Histórico por aba Cmd+←/→ (R6.3)

### Fase 6 — FileWatcher + Diff
- [x] Watch arquivo aberto e árvore (FSEvents/DispatchSource) (R4.1, R4.3)
- [x] Rename/move externo atualiza abas/sidebar (R4.4)
- [x] Indicador discreto de atualizado (R4.2)
- [x] Diff engine puro: baseline→novo, rounds cumulativos, confirmar leitura (R13.1–R13.3)

### Fase 7 — Busca
- [ ] Cmd+F no documento, ocorrências, destaque (R5.1)
- [ ] Cmd+Shift+F global na pasta, resultados por arquivo (R5.2)

### Fase 8 — Polish incremental
- [ ] Syntax highlighting completo (R3.2)
- [ ] Copiar Comando shell: limpar prompts/comentários/continuações (R3.2)
- [ ] Fold de código >30 linhas (R3.10)
- [ ] Outline/TOC bidirecional (R3.7)
- [ ] Âncoras com hover `#` (R3.8)
- [ ] Tabelas largas rolam horizontal (R3.9)
- [ ] Footer: breadcrumb + palavras/caracteres + tasks (R8.1, R3.13)
- [ ] Validação: links quebrados, mermaid erro (R10.1)
- [ ] Mermaid inline (R3.3)
- [ ] Imagens locais relativas (R3.12)
- [ ] Largura de leitura ajustável persistida (R3.11)
- [ ] Zoom de texto Cmd+=/- persistido (R11.1)
- [ ] Copiar como Contexto (R11.3)
- [ ] Grafo de apontamentos Mermaid em aba própria (R14)
- [ ] Renderização progressiva >500KB (R15.1)
- [ ] Deep link macdown:// (R11.2)
- [ ] CLI macdown (R12.1)
- [ ] Menu nativo + atalhos completos (R7.1)
- [ ] Acessibilidade: teclado sidebar/abas/TOC, VoiceOver, contraste 3 temas (R16.1)
- [ ] Default handler onboarding (R1.2)
