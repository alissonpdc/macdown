@testable import MacDown
import Testing

@Suite("SearchState Tests")
struct SearchStateTests {

    @Test("updateCounts sets total and navigates to first match")
    @MainActor
    func testUpdateCounts() {
        let state = SearchState()
        var navigated: (tab: Int, local: Int)?
        state.onNavigate = { tab, local in navigated = (tab, local) }

        state.updateCounts([2, 0, 3])

        #expect(state.matchMap.total == 5)
        #expect(state.currentGlobalIndex == 0)
        #expect(navigated! == (tab: 0, local: 0))
    }

    @Test("goToNext moves and wraps across tabs")
    @MainActor
    func testGoToNextWraps() {
        let state = SearchState()
        var navigated: (tab: Int, local: Int)?
        state.onNavigate = { tab, local in navigated = (tab, local) }
        state.updateCounts([1, 2])   // total 3

        state.goToNext() // global 1 -> tab 1 local 0
        #expect(state.currentGlobalIndex == 1)
        #expect(navigated! == (tab: 1, local: 0))

        state.goToNext() // global 2 -> tab 1 local 1
        state.goToNext() // wrap to global 0 -> tab 0 local 0
        #expect(state.currentGlobalIndex == 0)
        #expect(navigated! == (tab: 0, local: 0))
    }

    @Test("goToPrevious wraps to last match")
    @MainActor
    func testGoToPreviousWraps() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        state.updateCounts([2, 1]) // total 3

        state.goToPrevious() // from 0 wraps to 2
        #expect(state.currentGlobalIndex == 2)
    }

    @Test("counterText formats human-friendly position")
    @MainActor
    func testCounterText() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        #expect(state.counterText == "0 de 0")
        state.updateCounts([3])
        #expect(state.counterText == "1 de 3")
        state.goToNext()
        #expect(state.counterText == "2 de 3")
    }

    @Test("close resets state")
    @MainActor
    func testClose() {
        let state = SearchState()
        state.onNavigate = { _, _ in }
        state.query = "hello"
        state.isVisible = true
        state.updateCounts([4])

        state.close()

        #expect(state.isVisible == false)
        #expect(state.query == "")
        #expect(state.matchMap.total == 0)
        #expect(state.currentGlobalIndex == 0)
    }

    @Test("activate sets mode and visibility")
    @MainActor
    func testActivate() {
        let state = SearchState()
        state.activate(mode: .allTabs)
        #expect(state.isVisible == true)
        #expect(state.mode == .allTabs)
    }
}
