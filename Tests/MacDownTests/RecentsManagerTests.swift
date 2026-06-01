@testable import MacDown
import Testing
import Foundation

@Suite("RecentsManager Tests")
struct RecentsManagerTests {

    @Test("Add recent file")
    @MainActor
    func testAddRecent() {
        let manager = RecentsManager()
        let url = URL(fileURLWithPath: "/tmp/test.md")

        manager.addRecent(url, title: "test.md")

        #expect(manager.recents.count == 1)
        #expect(manager.recents[0].url == url)
        #expect(manager.recents[0].title == "test.md")
    }

    @Test("Recents are in order")
    @MainActor
    func testRecentsOrder() {
        let manager = RecentsManager()
        let url1 = URL(fileURLWithPath: "/tmp/test1.md")
        let url2 = URL(fileURLWithPath: "/tmp/test2.md")

        manager.addRecent(url1, title: "test1.md")
        manager.addRecent(url2, title: "test2.md")

        #expect(manager.recents.count == 2)
        #expect(manager.recents[0].url == url1)
        #expect(manager.recents[1].url == url2)
    }

    @Test("Clear recents")
    @MainActor
    func testClear() {
        let manager = RecentsManager()
        let url = URL(fileURLWithPath: "/tmp/test.md")

        manager.addRecent(url, title: "test.md")
        manager.clear()

        #expect(manager.recents.isEmpty)
    }
}
