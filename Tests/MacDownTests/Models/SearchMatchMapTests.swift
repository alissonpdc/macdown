@testable import MacDown
import Testing

@Suite("SearchMatchMap Tests")
struct SearchMatchMapTests {

    @Test("Empty map has no matches")
    func testEmpty() {
        let map = SearchMatchMap(countsPerTab: [])
        #expect(map.total == 0)
        #expect(map.location(forGlobalIndex: 0) == nil)
        #expect(map.nextIndex(after: 0) == nil)
        #expect(map.previousIndex(before: 0) == nil)
    }

    @Test("Single tab maps indices and wraps")
    func testSingleTab() {
        let map = SearchMatchMap(countsPerTab: [3])
        #expect(map.total == 3)
        #expect(map.location(forGlobalIndex: 0)! == (tab: 0, local: 0))
        #expect(map.location(forGlobalIndex: 2)! == (tab: 0, local: 2))
        #expect(map.location(forGlobalIndex: 3) == nil)
        #expect(map.nextIndex(after: 2) == 0)        // wrap to first
        #expect(map.previousIndex(before: 0) == 2)   // wrap to last
    }

    @Test("Multi tab skips empty tabs")
    func testMultiTab() {
        let map = SearchMatchMap(countsPerTab: [3, 0, 5])
        #expect(map.total == 8)
        #expect(map.location(forGlobalIndex: 2)! == (tab: 0, local: 2))
        #expect(map.location(forGlobalIndex: 3)! == (tab: 2, local: 0)) // tab 1 has 0
        #expect(map.location(forGlobalIndex: 7)! == (tab: 2, local: 4))
        #expect(map.nextIndex(after: 7) == 0)
        #expect(map.previousIndex(before: 0) == 7)
    }
}
