# PRD — MacDown

**Produto:** MacDown
**Plataforma:** macOS (nativo, Swift/SwiftUI)
**Data:** 2026-08-25
**Status:** Fonte da verdade — requisitos atuais do produto

---


## 1. Visão

No mundo do desenvolvimento agênico, markdown virou o novo código-fonte: specs, PRDs, planos e documentação vivem em arquivos `.md`. O MacDown é um app nativo para macOS focado exclusivamente na **leitura facilitada de markdown** — rápido de abrir, bonito de ler, sempre atualizado.

> Não é um editor. É um leitor. A proposta de valor é acelerar a leitura e validação de docs e specs durante o trabalho com agentes de código.

## 2. Problema

- Ler `.md` no VS Code/Xcode exige abrir uma IDE pesada ou alternar entre raw/preview.
- Visualizadores web (Typora web clones, extensões) são lentos para abrir, não entendem pastas como projetos.
- Frontmatter YAML (comum em specs agentivas) aparece como texto cru sem tratamento visual.
- Arquivos mudam constantemente (agentes escrevendo); leitores estáticos exigem reabrir manualmente.

## 3. Público-alvo

- Desenvolvedores que trabalham com agentes de código (Claude Code, Hermes, Codex etc.)
- Autores/leitores de docs técnicas, RFCs e especificações em markdown

## 4. Requisitos funcionais

### 4.1 Abertura de arquivos

- **R1.1** — App aberto diretamente (sem arquivo): exibe um diálogo/popup para selecionar um arquivo ou pasta `.md`.
- **R1.2** — Registro como app padrão (ou opção "Abrir com") para arquivos `.md`: duplo-clique no Finder abre direto no MacDown.
- **R1.3** — Suporte a múltiplas janelas/arquivos simultâneos via documento nativo do macOS (NSDocument) quando aplicável.

### 4.2 Navegador de pastas (sidebar)

- **R2.1** — Menu `Arquivos > Abrir Pasta…` carrega uma pasta raiz.
- **R2.2** — Sidebar esquerda estilo IDE: árvore da pasta aberta com subpastas colapsáveis e arquivos `.md` clicáveis.
- **R2.3** — Arquivo ativo destacado na sidebar; seleção atualiza o painel de leitura.
- **R2.4** — **Apenas arquivos markdown são exibidos na sidebar** (subpastas sempre visíveis; qualquer outro tipo é omitido). Extensões aceitas: família markdown — `.md`, `.markdown`, `.mdown`, `.mkd`.
- **R2.5** — **Estado de leitura por documento:** a posição de scroll de cada arquivo é lembrada na sessão; fechar e reabrir a aba restaura o ponto de leitura.

### 4.3 Renderização

- **R3.1** — Renderização completa de CommonMark + GFM (tabelas, task lists, strikethrough, autolinks, footnotes).
- **R3.2** — Blocos de código com syntax highlighting e botão de copiar com menu de contexto: **Copiar** (conteúdo bruto) e, em blocos shell (`bash`/`sh`/`zsh`/`console`), **Copiar Comando** — limpa prompts (`$`, `%`, `#`), comentários e continuações de linha, entregando o comando executável pronto para o terminal.
- **R3.3** — Suporte a **Mermaid** (diagramas renderizados inline).
- **R3.4** — **Frontmatter YAML** renderizado adequadamente: card/metadata header distinto no topo do documento (chave: valor, listas), não como bloco de código cru. O card é **colapsável** com um clique.
- **R3.5** — Links internos relativos (entre arquivos da pasta aberta) navegáveis dentro do app.
- **R3.6** — Tipografia e espaçamento otimizados para leitura longa.
- **R3.7** — **Outline/TOC à direita:** painel lateral direito listando os títulos do documento aberto; sincronia nos dois sentidos: clicar num título rola até a seção, e rolar o conteúdo destaca automaticamente a seção ativa no TOC.
- **R3.8** — **Âncoras nos títulos:** hover sobre um título mostra ícone `#` que copia o link da seção (`arquivo.md#requisitos`).
- **R3.9** — **Tabelas largas:** rolam horizontalmente sem quebrar o layout.
- **R3.10** — **Fold de blocos de código longos:** blocos acima de ~30 linhas aparecem resumidos com botão "expandir/recolher".
- **R3.11** — **Largura de leitura ajustável:** coluna de texto centralizada com largura máxima padrão (~70ch); o usuário pode aumentar/diminuir (preferência no menu View), persistida entre sessões.
- **R3.12** — **Imagens locais relativas:** imagens referenciadas por caminho relativo ao arquivo (`![x](assets/img.png)`) são resolvidas e renderizadas.
- **R3.13** — **Task lists agregadas:** quando o documento contém checkboxes, o rodapé exibe o total concluído (ex.: `12/18 tasks`).

### 4.4 Validação

- **R10.1** — Badge discreto de problemas do documento: links internos quebrados (arquivo/âncora inexistente) e diagramas Mermaid com erro de sintaxe.
- **R10.2** — **Frontmatter inválido:** YAML malformado é sinalizado com aviso claro em vez de renderizar silenciosamente errado.

### 4.5 Rodapé

- **R8.1** — Footer fixo abaixo do conteúdo exibindo: caminho (breadcrumb) do arquivo aberto, contagem de palavras/caracteres e tasks agregadas quando houver checklist.

### 4.6 Abas e navegação

- **R6.1** — **Barra de abas estilo Chrome** acima do conteúdo: cada `.md` aberto vira uma aba com título e botão `X` para fechar.
- **R6.2** — Clicar em um link interno abre o arquivo de destino em **nova aba**.
- **R6.3** — Histórico de navegação por aba: `Cmd+→` avança, `Cmd+←` volta.

### 4.7 Temas

- **R9.1** — Três modos de tema: Claro, Escuro e Sistema (seguir o macOS). Seleção via menu nativo (View/Aparência), persistida entre sessões.

### 4.7 Menu nativo e atalhos

- **R7.1** — Barra de menus nativa do macOS com atalhos padrão, incluindo no mínimo: Abrir (`Cmd+O`), Abrir Pasta, Fechar Aba (`Cmd+W`), Encerrar (`Cmd+Q`), Buscar no Documento (`Cmd+F`), Busca Global (`Cmd+Shift+F`).

### 4.8 CLI

- **R12.1** — **Comando `macdown`:** binário/symlink instalável (ex.: via app ou menu "Instalar ferramenta de linha de comando") permitindo `macdown arquivo.md` e `macdown pasta/` a partir do terminal.

### 4.9 Atualização ao vivo

- **R4.1** — Watch no arquivo aberto (e nos arquivos da pasta na sidebar): alteração externa re-renderiza automaticamente, preservando posição de scroll aproximada.
- **R4.2** — Indicador visual discreto de "atualizado" quando o conteúdo muda fora do app.
- **R4.3** - Novos arquivos criados/removidos na pasta aparecem/desaparecem na sidebar em tempo real.
- **R4.4** — **Rename/move externo:** quando um arquivo aberto ou da árvore é renomeado/movido fora do app, abas e sidebar atualizam título/caminho automaticamente (sem ficar órfão).

### 4.10 Visão diff pós-agente

- **R13.1** — Quando um arquivo aberto muda externamente, além de re-renderizar, os blocos alterados são **destacados**: verde-suave para adicionados/modificados, com resumo no indicador (`Atualizado · +8 −2`).
- **R13.2** — **Diff cumulativo contra o baseline:** o app mantém a última versão "confirmada como lida" pelo usuário. Cada nova escrita gera diff `baseline → novo`; alterações novas recebem destaque forte e as já presentes em rounds anteriores, destaque fraco. Clicar no indicador (ou atalho) confirma a leitura: baseline passa a ser a versão atual e os destaques somem.
- **R13.3** — **Alternância de visão por aba:** toggle entre visão "Nova" (render limpo) e visão "Diff" (destaques), via botão na barra e `Cmd+D`.

### 4.11 Busca

- **R5.1** — **Busca no documento aberto:** localizar texto dentro do `.md` atual (Cmd+F), com navegação entre ocorrências e destaque visual dos matches no conteúdo renderizado.
- **R5.2** — **Busca global na pasta aberta:** busca em todos os markdown da árvore (Cmd+Shift+F), com lista de resultados por arquivo, trecho de contexto e clique para abrir o arquivo na ocorrência.

### 4.12 Fluxo de trabalho agênico

- **R11.1** — **Zoom de texto próprio:** `Cmd+=` / `Cmd+-` ajustam o tamanho da fonte, persistido entre sessões (independe do zoom do sistema).
- **R11.2** — **Deep link `macdown://`:** esquema de URL para abrir arquivos direto no app (ex.: `macdown://open?path=/caminho/spec.md`), permitindo que agentes/CLI abram documentos no MacDown.
- **R11.3** — **Copiar como contexto (menu de contexto):** no clique-direito sobre o documento (ou seleção), opção "Copiar como Contexto" copia `caminho + conteúdo` formatado para colar num prompt de agente; com seleção ativa, copia apenas a seção/trecho selecionado com seu caminho e âncora.

### 4.13 Grafo de apontamentos

- **R14.1** — Menu `Visualizar > Árvore de Apontamentos`: gera um **diagrama (Mermaid) de todos os markdown da pasta aberta que se apontam** via links internos — nós são arquivos, setas são links entre eles.
- **R14.2** — O diagrama abre numa aba própria (não interfere nas abas de leitura); clicar num nó navega para o arquivo correspondente.
- **R14.3** — Arquivos sem nenhum link (isolados) aparecem como nós soltos, para revelar docs desconectados do conjunto.

### 4.14 Renderização progressiva

- **R15.1** — Arquivos grandes (> ~500KB) renderizam o primeiro viewport imediatamente e completam o restante em background, preservando a meta de <300ms até primeiro render.

### 4.15 Acessibilidade

- **R16.1** — Navegação completa por teclado na sidebar, abas e TOC; suporte a Voice Over nos elementos principais; contraste validado nos três temas.

## 5. Fora de escopo

- Edição de markdown
- Exportação (PDF/HTML)
- Sincronização em nuvem
- Indexação/persistência de cache de busca entre sessões (a busca global é on-demand)
- Breadcrumb na barra de título / histórico Cmd+[ ] do navegador de arquivos
- Arquivos recentes, "Revelar no Finder", tempo de leitura estimado
- Modo foco/zen, multi-janela avançada, status git na sidebar, restauração completa de sessão, Quick Open (Cmd+P)

## 6. Métricas de sucesso

- Tempo até primeiro byte renderizado < 300ms para arquivos típicos (< 200KB)
- Zero reabrir manual após edição externa (auto-refresh 100% das vezes)
- Uso recorrente como handler padrão de `.md`

## 7. Marcos de desenvolvimento

Ordem de construção sugerida (cada marco entrega um app utilizável):

| Marco | Escopo |
|---|---|
| M1 — Leitor | Abrir arquivo único, abas estilo Chrome, renderização GFM + frontmatter colapsável, temas claro/escuro/sistema |
| M2 — Projeto | Abrir pasta, sidebar em árvore (família markdown), links internos em nova aba, histórico Cmd+←/→, estado de leitura por doc |
| M3 — Vivo | File watching (arquivo + árvore + rename/move), indicador de refresh, visão diff pós-agente (R13) |
| M4 — Busca | Cmd+F no documento, Cmd+Shift+F global na pasta |
| M5 — Polish | Mermaid, outline/TOC bidirecional, âncoras, fold de código longo, Copiar Comando em blocos shell, footer completo (breadcrumb + stats + tasks), validação (links quebrados/mermaid/frontmatter), largura de leitura ajustável, imagens locais, zoom de texto, copiar como contexto, grafo de apontamentos, renderização progressiva, deep link `macdown://`, CLI `macdown`, acessibilidade, syntax highlight completo, default-handler onboarding |
