# MacDown v1 — Design Spec

**Data:** 2026-05-22  
**Versão:** 1.0  
**Status:** Aprovado

---

## Objetivo

MacDown é um app macOS para visualização de arquivos Markdown renderizados como rich text. Voltado para usuários que trabalham com Spec-Driven Design e precisam de uma forma rápida e nativa de abrir e ler arquivos `.md` no macOS.

A v1 é exclusivamente um **leitor** — sem edição de texto.

---

## Distribuição

- Entregue como `.app` bundle (sem `.pkg`, `.dmg` ou qualquer installer)
- O usuário move o `.app` para `/Applications` manualmente
- Compatível com macOS 13 (Ventura) ou superior

---

## Primeira execução

Ao ser aberto pela primeira vez, o app exibe um diálogo:

> "Deseja definir MacDown como app padrão para arquivos .md?"

O usuário pode confirmar ou ignorar. A preferência não é perguntada novamente após a primeira resposta.

---

## Comportamento de abertura

| Situação | Comportamento |
|---|---|
| Usuário abre o app diretamente (sem arquivo) | Interface completa é exibida + popup do Finder para escolher um `.md` |
| Usuário abre um `.md` pelo Finder | Arquivo abre em uma aba na janela principal |
| App já está aberto e usuário abre outro `.md` pelo Finder | Arquivo abre em nova aba na janela existente |

---

## Layout da janela

```
┌─────────────────────────────────────────────────────┐
│  [Abrir]  [Salvar]          [Claro | Escuro | Sistema] │  ← Toolbar
├──────────┬──────────────────────────────────────────┤
│          │  [aba1.md] [aba2.md]  +                  │  ← Abas
│ sidebar  ├──────────────────────────────────────────┤
│          │                                          │
│ arquivo1 │   Conteúdo renderizado do Markdown       │
│ arquivo2 │   em estilo GitHub Flavored Markdown     │
│ arquivo3 │                                          │
│          │                                          │
└──────────┴──────────────────────────────────────────┘
```

---

## Sidebar

- Exibe a lista de todos os arquivos atualmente abertos no app
- Mostra o nome do arquivo (sem o caminho completo)
- **Clique simples:** substitui o conteúdo da aba ativa pelo arquivo clicado
- **Clique duplo:** abre o arquivo em uma nova aba e a ativa

---

## Toolbar

| Elemento | Comportamento na v1 |
|---|---|
| Botão "Abrir" | Abre popup do Finder para selecionar um `.md` |
| Botão "Salvar" | Visível porém desabilitado (cinza) — reservado para v2 |
| Seletor de tema | Segmented control: Claro / Escuro / Sistema |

O seletor de tema persiste a preferência do usuário entre sessões.

---

## Abas

- A janela usa abas nativas para múltiplos arquivos
- Cada aba exibe o nome do arquivo
- Fechar todas as abas mantém a janela aberta (sem conteúdo)

---

## Renderização do Markdown

- Estilo **GitHub Flavored Markdown (GFM)**
- Suporte a: headings, negrito, itálico, listas, tabelas, task lists, blocos de código com syntax highlight, links
- Motor: `marked.js` para parsing + `highlight.js` para syntax highlight em blocos de código
- Renderizado via WebView embarcada no app
- A troca de tema aplica-se instantaneamente sem recarregar o arquivo

### Temas

| Opção | Comportamento |
|---|---|
| Claro | Fundo branco, texto escuro, estilo GitHub light |
| Escuro | Fundo escuro, texto claro, estilo GitHub dark |
| Sistema | Segue automaticamente o tema do macOS (light/dark) |

---

## Registro como app padrão para .md

- O app declara suporte às extensões `.md` e `.markdown` no seu manifesto
- Aparece como opção em "Abrir com" no Finder após a primeira execução
- Na primeira execução, oferece ao usuário tornar-se o app padrão (conforme seção "Primeira execução")
- O usuário também pode definir manualmente via Finder > Obter Informações > Abrir com > Alterar tudo

---

## Fora de escopo na v1

- Edição de texto
- Exportação (PDF, HTML)
- Busca dentro do documento
- Modo side-by-side (editor + preview)
- Sincronização ou cloud storage
- Renderização de imagens (locais ou remotas)
