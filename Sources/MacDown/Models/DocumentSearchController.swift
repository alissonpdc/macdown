import Foundation

/// Abstraction over a single rendered document (a WebView) that can run
/// text search inside its rendered HTML.
@MainActor
protocol DocumentSearchController: AnyObject {
    /// Highlights all case-insensitive occurrences of `query` and returns the match count.
    func highlight(_ query: String) async -> Int
    /// Marks occurrence `index` as the current one and scrolls it into view.
    func goToMatch(_ index: Int) async
    /// Removes all search highlights.
    func clearSearch() async
}
