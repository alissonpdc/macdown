# Design: Busca no documento + Menus nativos + Settings

**Data:** 2026-06-02
**Itens do NEXT:** 1.1 (Busca dentro do arquivo aberto), com extensão para busca multi-aba.

---

## Contexto

O MacDown hoje é um **visualizador** de Markdown (read-only): abre arquivos `.md`,
guarda o conteúdo como `String` em `OpenDocument`, e renderiza como HTML numa
`WKWebView` (`MarkdownView` → `Resources/renderer.html`, usando `marked.js` +
`highlight.js`). **Não existe editor de texto.**

Por isso, "busca dentro do arquivo aberto" opera sobre **o texto renderizado que o
usuário vê** no preview — destacando as ocorrências diretamente no HTML da WebView.

Os menus já são montados via SwiftUI `.commands` em `MacDownApp`. A toolbar
customizada vive em `ContentView` (botões Abrir/Salvar + seletor de Tema).

---

## Escopo deste trabalho

1. **Busca no arquivo (⌘F)** e **busca em todas as abas abertas (⇧⌘F)**.
2. **Reorganização dos menus nativos** (`File > Open`, `Edit > Find`).
3. **Limpeza da toolbar customizada** (remover Abrir, Salvar, Tema).
4. **Settings do app (⌘,)** com o seletor de Tema migrado.

### Fora de escopo (itens futuros do NEXT)
- Busca em toda a **pasta/workspace** (item 1.2 — escopo diferente do "todas as abas").
- Replace / replace all (1.3).
- Filtros avançados: case-sensitive, palavra inteira, regex (1.4). **A busca aqui é
  sempre case-insensitive.**
- Histórico de buscas (1.5).
- Preview de matches em lista (1.6).

---

## 1. Busca

### 1.1 Comportamento (UX)

**Dois modos, uma única barra de busca:**

- **⌘F** — busca apenas na **aba ativa** (documento atual).
- **⇧⌘F** — busca em **todas as abas abertas**, em sequência.

**Barra de busca dedicada**, que aparece no **topo da área de conteúdo** (logo abaixo
da barra de título / onde ficava a toolbar):

- Campo de texto que recebe **foco automático** ao abrir.
- Contador **"X de Y"**. No modo todas-abas, indica também a aba atual, ex.:
  `3 de 12 · README.md`.
- Setas **↑ / ↓** para navegar entre ocorrências.
- **Enter** = próxima ocorrência, **Shift+Enter** = anterior.
- Botão **✕** para fechar.
- **Escape** fecha a barra **e limpa os destaques**.
- Indicador discreto do **modo ativo** (arquivo / todas as abas).

**Busca em tempo real:** a cada tecla digitada, todas as ocorrências são destacadas e
o contador atualiza. A ocorrência **atual** recebe um destaque mais forte, e a WebView
**rola até ela**.

**Navegação:**
- Dá a volta (wrap-around): da última ocorrência, "próxima" volta para a primeira; e
  vice-versa.
- No modo todas-abas, ao cruzar o limite entre abas, a **aba ativa troca
  automaticamente** para a aba da ocorrência alvo.

**Sem resultados:** contador mostra `0 de 0`; nenhum destaque; campo pode ter feedback
visual sutil (ex.: contador em cor de atenção).

### 1.2 Arquitetura técnica

**`SearchState`** (`ObservableObject`, `@MainActor`)
- Estado: `query: String`, `mode: .currentFile | .allTabs`, `isVisible: Bool`,
  `totalMatches: Int`, `currentGlobalIndex: Int`, e a info da aba atual para o rótulo.
- Responsável por orquestrar a busca, agregar contagens por aba e mapear o índice
  global → `(abaIndex, índiceLocal)`.
- Lógica pura (mapeamento de índice e wrap-around) é **testável em unit tests**, sem
  WebView.

**`FindBarView`** (SwiftUI)
- A barra dedicada: campo, contador, setas, indicador de modo, botão fechar.
- Lê/escreve em `SearchState`. Encaminha ações de navegação e fechamento.
- Atalhos de teclado internos: Enter / Shift+Enter / Escape.

**Ponte JavaScript no `renderer.html`**
- Novas funções JS, chamadas via `evaluateJavaScript`:
  - `searchHighlight(query)` → destaca todas as ocorrências (case-insensitive) no
    `#content`, devolve a **contagem** de matches.
  - `goToMatch(index)` → marca a ocorrência `index` como "atual" (destaque forte) e
    faz `scrollIntoView`.
  - `clearSearch()` → remove todos os destaques.
- Implementação: envolve as ocorrências em `<mark>` (ou spans com classe), tomando
  cuidado para **não quebrar o HTML** (busca apenas em nós de texto, ignorando tags).
  Classe distinta para a ocorrência atual. Estilos de destaque adicionados ao
  `renderer.html` e adaptados ao tema claro/escuro.

**Registro de WebViews por aba (modo todas-abas)**
- Cada `MarkdownView` registra seu `Coordinator`/WebView no `SearchState` (chaveado
  pelo `OpenDocument.id`) em `makeNSView`, e remove o registro ao ser desmontado.
- No modo todas-abas, o `SearchState` percorre as abas **na ordem de `documents`**,
  consulta cada WebView para obter a contagem local, e soma o total. A navegação
  global resolve qual aba/ocorrência ativar, troca `DocumentStore.activeIndex` se
  necessário, e chama `goToMatch` na WebView correspondente.
- Premissa: o `TabView` mantém as WebViews das abas inativas instanciadas. Se uma aba
  não estiver montada/carregada no momento da consulta, o `SearchState` trata o caso
  graciosamente (conta 0 para aquela aba até ela responder).

**Acionamento**
- ⌘F e ⇧⌘F vêm dos menus nativos (ver seção 2). Cada um seta o `mode` e torna a
  `FindBarView` visível, focando o campo.

### 1.3 Testes
- **Unit (XCTest):** mapeamento índice-global → `(aba, índiceLocal)`, agregação de
  contagens por aba, e wrap-around (próxima/anterior nos limites) no `SearchState`.
- **Manual:** ponte JS de destaque/navegação/scroll na WebView, em tema claro e
  escuro, e a troca automática de aba no modo todas-abas.

---

## 2. Menus nativos

Reorganizar os `.commands` em `MacDownApp` para agrupar ações em **submenus
agrupadores com ícone**.

```
File
 └─ 🗁 Open  ▸                       (submenu agrupador, ícone "folder")
       Abrir arquivo…                 ⌘O
       Adicionar pasta ao Workspace   ⇧⌘O
       Abrir pasta                    ⇧⌘N

Edit
 └─ 🔍 Find  ▸                       (submenu agrupador, ícone "magnifyingglass")
       Buscar no arquivo              ⌘F
       Buscar em todas as abas        ⇧⌘F
```

**Regras:**
- **Apenas os agrupadores intermediários** ("Open", "Find") têm ícone (SF Symbol). As
  ações-folha não têm ícone.
- **Atalhos exibidos em cor muted:** comportamento nativo automático do menu do macOS
  (atalho à direita, em cinza). Basta atribuir `keyboardShortcut` a cada ação.

**Implementação:**
- Submenus criados com `Menu { … } label: { Label("Open", systemImage: "folder") }`
  dentro dos `.commands`.
- `File > Open` substitui o grupo atual (hoje em `CommandGroup(replacing: .newItem)`).
- `Edit > Find` adicionado ao menu Edit via `CommandGroup` com placement apropriado
  (ex.: `after: .textEditing`).
- **Fallback de ícone:** se o SwiftUI não renderizar o ícone do agrupador no menu bar
  nativo, ajustar pontualmente via `NSMenu`/`NSMenuItem.image` no `AppDelegate` após o
  launch. Não altera a UX.

---

## 3. Toolbar customizada (limpeza)

Em `ContentView`, o bloco `.toolbar` atual contém: "Abrir", "Salvar" (desabilitado) e
o seletor de Tema. Todos saem:

- **Abrir** → migra para `File > Open`.
- **Salvar** → **removido** (MacDown é read-only; não há edição).
- **Seletor de Tema** → migra para Settings (seção 4).

Com isso o bloco `.toolbar` fica vazio e é **removido por completo**. O
`.onReceive(...ImportFolderToWorkspace...)` e o resto do `ContentView` permanecem.

---

## 4. Settings do app (⌘,)

- Adicionar uma cena `Settings { SettingsView() }` em `MacDownApp`. O macOS cria
  automaticamente o item **MacDown > Settings…** com o atalho **⌘,**.
- **`SettingsView`** (SwiftUI): contém o seletor de Tema (Claro / Escuro / Sistema),
  lendo e escrevendo em `ThemeState.shared`.
- O picker pode usar o mesmo estilo já existente (ou um layout de formulário de
  Settings, ex.: `Form`/`Picker`), conforme melhor se encaixe no padrão de Preferências
  do macOS.

---

## Resumo de arquivos afetados (estimativa)

- `Sources/MacDown/Models/SearchState.swift` — **novo**.
- `Sources/MacDown/Views/FindBarView.swift` — **novo**.
- `Sources/MacDown/Views/SettingsView.swift` — **novo**.
- `Sources/MacDown/Views/MarkdownView.swift` — registrar WebView no `SearchState`,
  expor chamadas JS de busca.
- `Sources/MacDown/Resources/renderer.html` — funções JS de busca + estilos de
  destaque.
- `Sources/MacDown/Views/ContentView.swift` — remover toolbar; hospedar a `FindBarView`
  no topo do conteúdo.
- `Sources/MacDown/MacDownApp.swift` — reorganizar `.commands` (Open/Find), adicionar
  cena `Settings`.
- `Tests/MacDownTests/Models/SearchStateTests.swift` — **novo**.
