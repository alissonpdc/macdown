import Foundation

/// Evento de mudança detectado no disco.
public struct WatchEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case modified
        case created
        case deleted
        /// `url` = novo caminho; associado = caminho anterior.
        case renamed(previous: URL)
    }

    public let url: URL
    public let kind: Kind

    public init(url: URL, kind: Kind) {
        self.url = url
        self.kind = kind
    }
}

/// R4.x — watch de arquivo(s)/pasta.
/// Estratégia híbrida:
/// - vnode (DispatchSource) para arquivos existentes → modified
/// - polling leve do diretório (0.5s) → created/deleted/rename de arquivos markdown
public final class FileWatcher {
    private let paths: [URL]
    private let markdownOnly: Bool
    private let handler: ([WatchEvent]) -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fds: [Int32] = []
    private let queue = DispatchQueue(label: "com.macdown.filewatcher")
    private var stopped = false

    private let debounceInterval: TimeInterval

    public init(paths: [URL],
                markdownOnly: Bool = true,
                debounce: TimeInterval = 0.2,
                handler: @escaping ([WatchEvent]) -> Void)
    {
        self.paths = paths
        self.markdownOnly = markdownOnly
        debounceInterval = debounce
        self.handler = handler
    }

    public func start() {
        for url in paths {
            if Self.isDirectory(url) {
                watchTree(under: url)
                startDirectoryPolling(for: url)
            } else {
                watchFile(url)
            }
        }
    }

    public func stop() {
        stopped = true
        pollTimer?.cancel()
        pollTimer = nil
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        for fd in fds {
            close(fd)
        }
        fds.removeAll()
    }

    deinit { stop() }

    // MARK: diretórios

    static func isDirectory(_ url: URL) -> Bool {
        if let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory {
            return isDir
        }
        return url.pathIsDirectory()
    }

    /// vnode nos arquivos markdown imediatos do diretório (1 nível).
    /// Não recursivo: diretórios são cobertos por `startDirectoryPolling`.
    private func watchTree(under dir: URL) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return }
        for child in children {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                startDirectoryPolling(for: child)
            } else if !markdownOnly || FolderScanner.isMarkdown(child) {
                watchFile(child)
            }
        }
    }

    // MARK: vnode por arquivo

    private func watchFile(_ rawURL: URL) {
        guard !stopped else { return }
        let url = Self.canonical(rawURL)
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fds.append(fd)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, !self.stopped else { return }
            // escritas atômicas geram rename/delete; qualquer evento = conteúdo pode ter mudado
            scheduleDebounce(WatchEvent(url: url, kind: .modified))
        }
        source.resume()
        sources.append(source)
    }

    // MARK: debounce

    private var pending: [String: WatchEvent.Kind] = [:]
    private var debounceWorkItem: DispatchWorkItem?

    private func scheduleDebounce(_ event: WatchEvent) {
        pending[event.url.path] = event.kind
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.stopped else { return }
            let events = pending.map { WatchEvent(url: URL(fileURLWithPath: $0.key), kind: $0.value) }
            pending.removeAll()
            guard !events.isEmpty else { return }
            DispatchQueue.main.async { self.handler(events) }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    // MARK: polling de diretório (created/deleted/rename)

    private var pollTimer: DispatchSourceTimer?
    private var lastSnapshot: [String: UInt64] = [:]

    private func startDirectoryPolling(for dir: URL) {
        lastSnapshot.merge(Self.markdownChildren(of: dir), uniquingKeysWith: { _, new in new })
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            guard let self, !self.stopped else { return }
            let now = Self.markdownChildren(of: dir)
            let events = Self.diff(previous: lastSnapshot, current: now)
            lastSnapshot = now
            guard !events.isEmpty else { return }
            DispatchQueue.main.async { self.handler(events) }
        }
        timer.resume()
        pollTimer = timer
    }

    /// R4.4 — created/deleted viram `.renamed` quando compartilham inode (mesmo arquivo, outro nome).
    static func diff(previous: [String: UInt64], current: [String: UInt64]) -> [WatchEvent] {
        var events: [WatchEvent] = []
        var created = Set(current.keys).subtracting(previous.keys)
        for oldPath in previous.keys where current[oldPath] == nil {
            let inode = previous[oldPath] ?? 0
            if inode != 0, let newPath = created.first(where: { current[$0] == inode }) {
                events.append(WatchEvent(url: URL(fileURLWithPath: newPath),
                                         kind: .renamed(previous: URL(fileURLWithPath: oldPath))))
                created.remove(newPath)
            } else {
                events.append(WatchEvent(url: URL(fileURLWithPath: oldPath), kind: .deleted))
            }
        }
        events += created.map { WatchEvent(url: URL(fileURLWithPath: $0), kind: .created) }
        return events.sorted { $0.url.path < $1.url.path }
    }

    private static func markdownChildren(of rawDir: URL) -> [String: UInt64] {
        let dir = canonical(rawDir)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileIdentifierKey],
            options: []
        ) else { return [:] }
        var result: [String: UInt64] = [:]
        for item in items where FolderScanner.isMarkdown(item) {
            let inode = (try? item.resourceValues(forKeys: [.fileIdentifierKey]))?.fileIdentifier ?? 0
            result[canonical(item).path] = inode
        }
        return result
    }

    /// contentsOfDirectory devolve `/private/var/...` mesmo quando a raiz observada é `/var/...`;
    /// canonicalizamos uma vez para que eventos e comparações de URL sejam consistentes.
    static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }
}

private extension URL {
    /// hasDirectoryPath falha para URLs relativas/não-resolvidas; isto é confiável.
    func pathIsDirectory() -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
