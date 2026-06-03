@testable import MacDown
import Testing
import Foundation

@Suite("DocumentStore move Tests")
struct DocumentStoreMoveTests {

    @MainActor
    private func makeStore() -> DocumentStore {
        let store = DocumentStore()
        store.documents = [
            OpenDocument(url: URL(fileURLWithPath: "/tmp/a.md"), content: "A"),
            OpenDocument(url: URL(fileURLWithPath: "/tmp/b.md"), content: "B"),
            OpenDocument(url: URL(fileURLWithPath: "/tmp/c.md"), content: "C")
        ]
        return store
    }

    @Test("Move forward reorders documents")
    @MainActor
    func testMoveForward() {
        let store = makeStore()
        store.move(from: 0, to: 2)
        #expect(store.documents.map(\.title) == ["b", "c", "a"])
    }

    @Test("Move backward reorders documents")
    @MainActor
    func testMoveBackward() {
        let store = makeStore()
        store.move(from: 2, to: 0)
        #expect(store.documents.map(\.title) == ["c", "a", "b"])
    }

    @Test("Move preserves the active document (active was moved)")
    @MainActor
    func testMovePreservesActive() {
        let store = makeStore()
        store.activeIndex = 0 // active = "a"
        store.move(from: 0, to: 2)
        #expect(store.documents[store.activeIndex].title == "a")
    }

    @Test("Move keeps active pointing at an untouched doc")
    @MainActor
    func testMoveKeepsOtherActive() {
        let store = makeStore()
        store.activeIndex = 1 // active = "b"
        store.move(from: 0, to: 2) // -> [b, c, a]; b now at 0
        #expect(store.documents[store.activeIndex].title == "b")
    }

    @Test("Move with equal indices is a no-op")
    @MainActor
    func testMoveNoOp() {
        let store = makeStore()
        store.move(from: 1, to: 1)
        #expect(store.documents.map(\.title) == ["a", "b", "c"])
    }
}
