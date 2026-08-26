import SwiftUI
import Foundation

/// Uma aba aberta: documento + estado de leitura da sessão (R2.5).
public struct ReaderTab: Identifiable, Equatable {
    public let id: UUID
    public let document: OpenDocument
    public var scrollOffset: CGFloat

    public init(document: OpenDocument, id: UUID = UUID(), scrollOffset: CGFloat = 0) {
        self.id = id
        self.document = document
        self.scrollOffset = scrollOffset
    }

    public var title: String {
        document.url.deletingPathExtension().lastPathComponent
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
        let tab = ReaderTab(document: try OpenDocument(url: url))
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

    // MARK: R6.3 — histórico de navegação por aba

    public func recordVisit(_ path: String, in tabID: UUID) {
        guard histories[tabID] != nil else { return }
        histories[tabID]?.push(path)
    }

    public func canGoBack(in tabID: UUID) -> Bool { histories[tabID]?.canGoBack ?? false }
    public func canGoForward(in tabID: UUID) -> Bool { histories[tabID]?.canGoForward ?? false }

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
