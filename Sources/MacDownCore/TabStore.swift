import Foundation
import SwiftUI

/// R4.4 — renomear/mover externamente atualiza abas sem órfãs; R4.1/R4.2 — mudança externa
/// re-renderiza (recarregando o documento) e marca o indicador discreto de atualizado.
public extension TabStore {
    /// Aplica eventos do FileWatcher ao estado das abas.
    func apply(_ events: [WatchEvent]) {
        for event in events {
            switch event.kind {
            case let .renamed(previous):
                handleRename(from: previous, to: event.url)
            case .modified:
                handleExternalModification(of: event.url)
            default:
                break
            }
        }
    }

    /// R4.2 — usuário confirma que leu as mudanças externas (R13.2: baseline vira o atual).
    func confirmExternalUpdate(in tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].hasExternalUpdate = false
        tabs[index].baseline = nil
        tabs[index].diffResult = nil
        tabs[index].knownChanges = []
    }

    /// R13.3 — alterna visão "Nova"/"Diff" da aba.
    func toggleDiffView(in tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].showsDiff.toggle()
    }

    private func handleRename(from oldURL: URL, to newURL: URL) {
        let oldPath = oldURL.standardizedFileURL.path
        for index in tabs.indices where tabs[index].document.url.standardizedFileURL.path == oldPath {
            guard let doc = try? OpenDocument(url: newURL) else { continue }
            let tab = tabs[index]
            tabs[index] = ReaderTab(document: doc, id: tab.id, scrollOffset: tab.scrollOffset,
                                    hasExternalUpdate: tab.hasExternalUpdate)
            histories[tab.id]?.remapPath(from: oldURL.path, to: newURL.resolvingSymlinksInPath().path)
        }
    }

    /// R4.1 — recarrega o documento (re-render preservando scroll);
    /// R4.2 — marca indicador; R13.x — calcula diff cumulativo contra o baseline.
    private func handleExternalModification(of url: URL) {
        let path = url.standardizedFileURL.path
        for index in tabs.indices where tabs[index].document.url.standardizedFileURL.path == path {
            let tab = tabs[index]
            guard let doc = try? OpenDocument(url: tab.document.url), doc != tab.document else { continue }
            let base = tab.baseline ?? tab.document
            let result = BlockDiffer.diff(baseline: base.document, updated: doc.document,
                                          knownChanges: tab.knownChanges)
            // assinaturas destacadas neste round ficam conhecidas (fracas nos próximos)
            let changedSigs = zip(doc.document.blocks, result.statuses)
                .filter { $0.1 != .unchanged }
                .map { BlockDiffer.signature(of: $0.0) }
            tabs[index] = ReaderTab(
                document: doc,
                id: tab.id,
                scrollOffset: tab.scrollOffset,
                hasExternalUpdate: true,
                baseline: base,
                diffResult: result,
                knownChanges: tab.knownChanges.union(changedSigs),
                showsDiff: tab.showsDiff
            )
        }
    }
}

/// Estado de busca de uma aba (R5.1 / R5.2).
public struct SearchState: Equatable {
    public var query: String = ""
    public var matches: [SearchMatch] = []
    public var current: Int = 0
    public var isActive: Bool = false
    public var options: SearchOptions = []
    /// R5.2 — incrementado a cada salto vindo da busca global; força o WebView
    /// a re-navegar mesmo com query/occorrência iguais.
    public var navigationToken: Int = 0
    public var count: Int {
        matches.count
    }

    public init() {}
}

/// Uma aba aberta: documento + estado de leitura da sessão (R2.5).
public struct ReaderTab: Identifiable, Equatable {
    public let id: UUID
    public let document: OpenDocument
    public var scrollOffset: CGFloat
    /// R4.2 — conteúdo mudou fora do app e o usuário ainda não confirmou a leitura.
    public var hasExternalUpdate: Bool
    /// R13.2 — última versão confirmada como lida; nil = sem pendências.
    public var baseline: OpenDocument?
    /// R13.1/R13.2 — diff baseline→atual pendente.
    public var diffResult: BlockDiffer.Result?
    /// R13.2 — assinaturas de blocos alterados em rounds anteriores (destaque fraco).
    public var knownChanges: Set<String>
    /// R13.3 — aba exibindo a visão "Diff" em vez da visão "Nova".
    public var showsDiff: Bool
    /// R5.1 / R5.2 — estado de busca da aba.
    public var search: SearchState

    public init(document: OpenDocument, id: UUID = UUID(), scrollOffset: CGFloat = 0,
                hasExternalUpdate: Bool = false,
                baseline: OpenDocument? = nil,
                diffResult: BlockDiffer.Result? = nil,
                knownChanges: Set<String> = [],
                showsDiff: Bool = false,
                search: SearchState = SearchState())
    {
        self.id = id
        self.document = document
        self.scrollOffset = scrollOffset
        self.hasExternalUpdate = hasExternalUpdate
        self.baseline = baseline
        self.diffResult = diffResult
        self.knownChanges = knownChanges
        self.showsDiff = showsDiff
        self.search = search
    }

    public var title: String {
        DisplayName.file(document.url)
    }
}

/// R6.1 — gerenciador de abas; cada arquivo vira no máximo uma aba.
public final class TabStore: ObservableObject {
    @Published public private(set) var tabs: [ReaderTab] = []
    @Published public var activeTabID: UUID?
    var histories: [UUID: History] = [:]

    public init() {}

    public var activeTab: ReaderTab? {
        tabs.first { $0.id == activeTabID }
    }

    /// Abre o arquivo em aba (ou foca a existente) e ativa.
    public func open(url: URL) throws {
        if let existing = tabs.first(where: { $0.document.url.standardizedFileURL == url.standardizedFileURL }) {
            select(existing.id)
            return
        }
        let tab = try ReaderTab(document: OpenDocument(url: url))
        tabs.append(tab)
        histories[tab.id] = History()
        recordVisit(url.path, in: tab.id)
        select(tab.id)
    }

    public func close(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        histories.removeValue(forKey: id)
        if activeTabID == id {
            // R6.1 — vizinho herda o foco (preferindo o da esquerda)
            let next = index > 0 ? index - 1 : min(index, tabs.count - 1)
            activeTabID = next >= 0 ? tabs[next].id : nil
        }
    }

    public func select(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    public func setScrollOffset(_ offset: CGFloat, for id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].scrollOffset = offset
    }

    // MARK: navegação entre abas (Cmd+←/→, Ctrl+Tab)

    /// Aba seguinte, com wrap-around cíclico.
    public func selectNext() {
        cycle(+1)
    }

    /// Aba anterior, com wrap-around cíclico.
    public func selectPrevious() {
        cycle(-1)
    }

    private func cycle(_ step: Int) {
        guard tabs.count > 1 else { return }
        #if DEBUG
            // print("cycle from", activeTabID as Any, "of", tabs.count)
        #endif
        let current = activeTabID.flatMap { id in tabs.firstIndex { $0.id == id } } ?? 0
        let next = (current + step + tabs.count) % tabs.count
        select(tabs[next].id)
    }

    // MARK: R6.3 — histórico de navegação por aba

    public func recordVisit(_ path: String, in tabID: UUID) {
        guard histories[tabID] != nil else { return }
        histories[tabID]?.push(path)
    }

    public func canGoBack(in tabID: UUID) -> Bool {
        histories[tabID]?.canGoBack ?? false
    }

    public func canGoForward(in tabID: UUID) -> Bool {
        histories[tabID]?.canGoForward ?? false
    }

    public func currentHistoryEntry(in tabID: UUID) -> URL? {
        histories[tabID]?.current.map { URL(fileURLWithPath: $0) }
    }

    /// Volta/avança no histórico; retorna o destino (a view carrega e reseta scroll).
    @discardableResult
    public func goBack(in tabID: UUID) -> URL? {
        guard histories[tabID]?.canGoBack == true else { return nil }
        histories[tabID]?.goBack()
        return navigateToCurrentEntry(in: tabID)
    }

    @discardableResult
    public func goForward(in tabID: UUID) -> URL? {
        guard histories[tabID]?.canGoForward == true else { return nil }
        histories[tabID]?.goForward()
        return navigateToCurrentEntry(in: tabID)
    }

    private func navigateToCurrentEntry(in tabID: UUID) -> URL? {
        guard let path = histories[tabID]?.current,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let doc = try? OpenDocument(url: URL(fileURLWithPath: path)) else { return nil }
        tabs[index] = ReaderTab(document: doc, id: tabID)
        activeTabID = tabID
        return tabs[index].document.url
    }
}

// MARK: Fase 7 — Busca (R5.1 / R5.2)

public extension TabStore {
    /// Atualiza a busca da aba a partir do termo digitado; recalcula as ocorrências.
    func updateSearch(query: String, in tabID: UUID, options: SearchOptions? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        var state = tabs[index].search
        // No-op quando nada mudou: re-focar o campo (Enter da busca cíclica)
        // re-dispara o binding e não deve resetar a ocorrência atual.
        if state.query == query, options == nil || options == state.options {
            return
        }
        if let options {
            state.options = options
        }
        state.query = query
        if query.isEmpty {
            state.matches = []
            state.current = 0
            state.isActive = false
        } else {
            state.matches = SearchEngine.findMatches(in: tabs[index].document.document,
                                                     query: query, options: state.options)
            state.current = 0
            state.isActive = true
        }
        tabs[index].search = state
        tabs = tabs
    }

    /// Liga/desliga a barra de busca sem perder o termo (usado por Cmd+F / Esc).
    func setSearchActive(_ active: Bool, in tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if !active {
            tabs[index].search.query = ""
            tabs[index].search.matches = []
            tabs[index].search.current = 0
        }
        tabs[index].search.isActive = active
        tabs = tabs
    }

    /// Avança para a próxima ocorrência (Cmd+G).
    func nextMatch(in tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard !tabs[index].search.matches.isEmpty else { return }
        tabs[index].search.current = (tabs[index].search.current + 1) % tabs[index].search.matches.count
        tabs = tabs
    }

    /// Volta para a ocorrência anterior (Shift+Cmd+G).
    func previousMatch(in tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard !tabs[index].search.matches.isEmpty else { return }
        let n = tabs[index].search.matches.count
        tabs[index].search.current = (tabs[index].search.current - 1 + n) % n
        tabs = tabs
    }

    /// R5.2 — abre o arquivo (ou foca a aba existente) e salta a render até a
    /// ocorrência encontrada pela busca global, ativando o destaque do termo.
    func open(url: URL, revealingMatch match: SearchMatch,
              query: String, options: SearchOptions = []) throws
    {
        try open(url: url)
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        var state = tabs[index].search
        state.options = options
        state.query = query
        state.isActive = true
        state.matches = SearchEngine.findMatches(in: tabs[index].document.document,
                                                 query: query, options: options)
        state.current = min(match.ordinal, max(0, state.matches.count - 1))
        state.navigationToken += 1
        tabs[index].search = state
        tabs = tabs
    }
}
