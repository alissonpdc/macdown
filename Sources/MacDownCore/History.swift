/// R6.3 — histórico de navegação linear (back/forward) por aba.
public struct History: Equatable {
    public private(set) var entries: [String] = []
    public private(set) var index: Int = -1

    public init() {}

    public var current: String? {
        (0 ..< entries.count).contains(index) ? entries[index] : nil
    }

    public var canGoBack: Bool {
        index > 0
    }

    public var canGoForward: Bool {
        index < entries.count - 1
    }

    /// Nova visita na posição atual: descarta o forward.
    public mutating func push(_ entry: String) {
        if index >= 0, index < entries.count - 1 {
            entries = Array(entries[...index])
        }
        // evita duplicar a mesma entrada consecutiva
        if entries.last != entry {
            entries.append(entry)
        }
        index = entries.count - 1
    }

    public mutating func goBack() {
        guard canGoBack else { return }
        index -= 1
    }

    public mutating func goForward() {
        guard canGoForward else { return }
        index += 1
    }

    /// R4.4 — rename/move: reescreve o caminho em todas as entradas.
    public mutating func remapPath(from oldPath: String, to newPath: String) {
        for i in entries.indices where entries[i] == oldPath {
            entries[i] = newPath
        }
    }
}
