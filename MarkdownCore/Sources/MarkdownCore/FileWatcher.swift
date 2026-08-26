import Foundation

/// Evento de mudança detectado no disco.
public struct WatchEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case modified
        case created
        case deleted
        case renamed
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
                handler: @escaping ([WatchEvent]) -> Void) {
        self.paths = paths
        self.markdownOnly = markdownOnly
        self.debounceInterval = debounce
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
        for source in sources { source.cancel() }
        sources.removeAll()
        for fd in fds { close(fd) }
        fds.removeAll()
    }

    deinit { stop() }

    // MARK: diretórios

    static func isDirectory(_ url: URL) -> Bool {
        if let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory { return isDir }
        return url.pathIsDirectory()
    }

    /// vnode em cada arquivo markdown atual da árvore (1 nível + abas abertas cobre R4.1).
    private func watchTree(under dir: URL) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return }
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                watchTree(under: child)
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
            guard let self = self, !self.stopped else { return }
            // escritas atômicas geram rename/delete; qualquer evento = conteúdo pode ter mudado
            self.scheduleDebounce(WatchEvent(url: url, kind: .modified))
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
            guard let self = self, !self.stopped else { return }
            let events = self.pending.map { WatchEvent(url: URL(fileURLWithPath: $0.key), kind: $0.value) }
            self.pending.removeAll()
            guard !events.isEmpty else { return }
            DispatchQueue.main.async { self.handler(events) }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    // MARK: polling de diretório (created/deleted/rename)

    private var pollTimer: DispatchSourceTimer?
    private var lastSnapshot: Set<String> = []

    private func startDirectoryPolling(for dir: URL) {
        lastSnapshot.formUnion(Self.markdownChildren(of: dir))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            guard let self = self, !self.stopped else { return }
            let now = Set(Self.markdownChildren(of: dir))
            let created = now.subtracting(self.lastSnapshot).map { WatchEvent(url: URL(fileURLWithPath: $0), kind: .created) }
            let deleted = self.lastSnapshot.subtracting(now).map { WatchEvent(url: URL(fileURLWithPath: $0), kind: .deleted) }
            self.lastSnapshot = now
            let events = created + deleted
            guard !events.isEmpty else { return }
            DispatchQueue.main.async { self.handler(events) }
        }
        timer.resume()
        pollTimer = timer
    }

    private static func markdownChildren(of rawDir: URL) -> [String] {
        let dir = canonical(rawDir)
        return (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []))?
            .filter { FolderScanner.isMarkdown($0) }
            .map { canonical($0).path } ?? []
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
