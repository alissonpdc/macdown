import XCTest
@testable import MacDownCore

// R4.1/R4.3/R4.4 — watch de arquivo e árvore; eventos com debounce
final class FileWatcherTests: XCTestCase {
    private var root: URL!
    private var watcher: FileWatcher!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "v1".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "v1".write(to: root.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        watcher?.stop()
        try? FileManager.default.removeItem(at: root)
    }

    func testDetectsFileModification() throws {
        let exp = expectation(description: "modify event")
        watcher = FileWatcher(paths: [root]) { events in
            if events.contains(where: { $0.url.lastPathComponent == "a.md" && $0.kind == .modified }) {
                exp.fulfill()
            }
        }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3) // watcher assentar
        try "v2".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        wait(for: [exp], timeout: 5)
    }

    func testDetectsNewMarkdownFile() throws {
        let exp = expectation(description: "created event")
        watcher = FileWatcher(paths: [root]) { events in
            if events.contains(where: { $0.url.lastPathComponent == "novo.md" && $0.kind == .created }) {
                exp.fulfill()
            }
        }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        try "x".write(to: root.appendingPathComponent("novo.md"), atomically: true, encoding: .utf8)
        wait(for: [exp], timeout: 5)
    }

    func testDetectsDeletion() throws {
        let exp = expectation(description: "deleted event")
        let target = root.appendingPathComponent("b.md").resolvingSymlinksInPath() // eventos vêm canônicos
        watcher = FileWatcher(paths: [root]) { events in
            if events.contains(where: { $0.url == target && $0.kind == .deleted }) {
                exp.fulfill()
            }
        }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        try FileManager.default.removeItem(at: target)
        wait(for: [exp], timeout: 5)
    }

    func testDetectsRenameAsSingleRenamedEvent() throws {
        let exp = expectation(description: "renamed event")
        let newURL = root.appendingPathComponent("c.md").resolvingSymlinksInPath()
        let oldURL = root.appendingPathComponent("b.md").resolvingSymlinksInPath()
        watcher = FileWatcher(paths: [root]) { events in
            for event in events {
                if case .renamed(let previous) = event.kind,
                   event.url.standardizedFileURL == newURL.standardizedFileURL,
                   previous.standardizedFileURL == oldURL.standardizedFileURL {
                    exp.fulfill()
                }
            }
        }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        try FileManager.default.moveItem(at: root.appendingPathComponent("b.md"), to: newURL)
        wait(for: [exp], timeout: 5)
    }

    func testIgnoresNonMarkdownFiles() throws {
        var sawTxt = false
        watcher = FileWatcher(paths: [root], markdownOnly: true) { events in
            sawTxt = sawTxt || events.contains { $0.url.pathExtension == "txt" }
        }
        watcher.start()
        Thread.sleep(forTimeInterval: 0.3)
        try "x".write(to: root.appendingPathComponent("outro.txt"), atomically: true, encoding: .utf8)
        Thread.sleep(forTimeInterval: 1.0) // daria tempo do evento chegar
        XCTAssertFalse(sawTxt)
    }
}
