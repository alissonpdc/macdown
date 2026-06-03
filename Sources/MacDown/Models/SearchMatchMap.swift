import Foundation

/// Pure value type that maps a flat "global" match index across multiple tabs
/// to a concrete (tab, local) position, and handles wrap-around navigation.
struct SearchMatchMap: Equatable {
    /// Match count per tab, indexed in the same order as the open documents.
    let countsPerTab: [Int]

    init(countsPerTab: [Int] = []) {
        self.countsPerTab = countsPerTab
    }

    var total: Int { countsPerTab.reduce(0, +) }

    /// Maps a global index in `0..<total` to (tab, local). Returns nil if out of range.
    func location(forGlobalIndex global: Int) -> (tab: Int, local: Int)? {
        guard global >= 0, global < total else { return nil }
        var remaining = global
        for (tab, count) in countsPerTab.enumerated() {
            if remaining < count { return (tab, remaining) }
            remaining -= count
        }
        return nil
    }

    /// Next global index with wrap-around. Returns nil when there are no matches.
    func nextIndex(after current: Int) -> Int? {
        guard total > 0 else { return nil }
        return (current + 1) % total
    }

    /// Previous global index with wrap-around. Returns nil when there are no matches.
    func previousIndex(before current: Int) -> Int? {
        guard total > 0 else { return nil }
        return ((current - 1) % total + total) % total
    }
}
