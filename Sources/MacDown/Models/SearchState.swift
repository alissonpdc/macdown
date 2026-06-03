import SwiftUI

@MainActor
final class SearchState: ObservableObject {
    enum Mode: Equatable { case currentFile, allTabs }

    @Published var query: String = ""
    @Published var mode: Mode = .currentFile
    @Published var isVisible: Bool = false
    @Published private(set) var matchMap = SearchMatchMap()
    @Published private(set) var currentGlobalIndex: Int = 0

    /// Per-document search controllers (the rendered WebViews), keyed by `OpenDocument.id`.
    /// Populated by `MarkdownView` as tabs mount/unmount.
    private(set) var controllers: [UUID: DocumentSearchController] = [:]

    /// Wired by the view layer: switch to `tab` and scroll its WebView to occurrence `local`.
    var onNavigate: ((_ tab: Int, _ local: Int) -> Void)?

    func register(_ controller: DocumentSearchController, for id: UUID) {
        controllers[id] = controller
    }

    func unregister(for id: UUID) {
        controllers[id] = nil
    }

    func activate(mode: Mode) {
        self.mode = mode
        isVisible = true
    }

    func close() {
        isVisible = false
        query = ""
        matchMap = SearchMatchMap()
        currentGlobalIndex = 0
    }

    /// Replaces match counts (in document order) and navigates to the first match.
    func updateCounts(_ counts: [Int]) {
        matchMap = SearchMatchMap(countsPerTab: counts)
        currentGlobalIndex = 0
        navigateToCurrent()
    }

    func goToNext() {
        guard let next = matchMap.nextIndex(after: currentGlobalIndex) else { return }
        currentGlobalIndex = next
        navigateToCurrent()
    }

    func goToPrevious() {
        guard let prev = matchMap.previousIndex(before: currentGlobalIndex) else { return }
        currentGlobalIndex = prev
        navigateToCurrent()
    }

    /// Human-friendly counter: "X de Y" (1-based). "0 de 0" when empty.
    var counterText: String {
        guard matchMap.total > 0 else { return "0 de 0" }
        return "\(currentGlobalIndex + 1) de \(matchMap.total)"
    }

    private func navigateToCurrent() {
        guard let loc = matchMap.location(forGlobalIndex: currentGlobalIndex) else { return }
        onNavigate?(loc.tab, loc.local)
    }
}
