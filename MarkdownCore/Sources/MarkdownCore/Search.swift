import Foundation

/// Opções de busca (R5.1 / R5.2).
public struct SearchOptions: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Diferencia maiúsculas/minúsculas.
    public static let caseSensitive = SearchOptions(rawValue: 1 << 0)
    /// Exige que o termo esteja delimitado por fronteiras de palavra.
    public static let wholeWord = SearchOptions(rawValue: 1 << 1)
}

/// Uma ocorrência de busca dentro de um documento.
public struct SearchMatch: Identifiable, Equatable {
    public let id: UUID
    /// Índice do bloco (em `CoreDocument.blocks`) onde a ocorrência foi encontrada.
    public let blockIndex: Int
    /// Posição ordinal da ocorrência no documento inteiro (0-based).
    public let ordinal: Int
    /// Intervalo (offsets UTF-16) dentro do texto buscável do bloco.
    public let range: Range<Int>
    /// Trecho de contexto ao redor da ocorrência.
    public let snippet: String
    /// Offset (UTF-16) do início do match dentro de `snippet`.
    public let snippetMatchStart: Int

    public init(blockIndex: Int, ordinal: Int, range: Range<Int>, snippet: String, snippetMatchStart: Int) {
        self.id = UUID()
        self.blockIndex = blockIndex
        self.ordinal = ordinal
        self.range = range
        self.snippet = snippet
        self.snippetMatchStart = snippetMatchStart
    }
}

/// Resultado de busca global em um único arquivo (R5.2).
public struct FileSearchResult: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let matches: [SearchMatch]
    public var count: Int { matches.count }

    public init(url: URL, matches: [SearchMatch]) {
        self.id = UUID()
        self.url = url
        self.matches = matches
    }
}

public enum SearchEngine {
    /// Texto passível de busca de um bloco — fonte única de verdade tanto para
    /// a localização das ocorrências (Core) quanto para o destaque (UI).
    public static func searchableText(of block: any BlockNode) -> String {
        switch block {
        case let h as HeadingNode:
            return h.inlineText
        case let p as ParagraphNode:
            return p.text
        case let c as CodeBlockNode:
            return c.code
        case let q as QuoteNode:
            return q.plainText
        case let l as ListNode:
            return l.items.joined(separator: "\n")
        case let t as TaskListItemsNode:
            return t.items.map { ($0.isChecked ? "[x] " : "[ ] ") + $0.text }
                .joined(separator: "\n")
        case let t as TableNode:
            let header = t.headerCells.joined(separator: " ")
            let rows = t.rows.map { $0.joined(separator: " ") }.joined(separator: "\n")
            return ([header] + (rows.isEmpty ? [] : [rows])).joined(separator: "\n")
        default:
            return ""
        }
    }

    /// Encontra todas as ocorrências de `query` em um documento (R5.1).
    public static func findMatches(in document: CoreDocument, query: String,
                                   options: SearchOptions = []) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        let nsQuery = query as NSString
        var results: [SearchMatch] = []
        var ordinal = 0

        for (bi, block) in document.blocks.enumerated() {
            let text = searchableText(of: block)
            guard !text.isEmpty else { continue }
            let ns = text as NSString
            let compare: NSString.CompareOptions = options.contains(.caseSensitive) ? [] : [.caseInsensitive]
            var searchRange = NSRange(location: 0, length: ns.length)

            while true {
                let found = ns.range(of: nsQuery as String, options: compare, range: searchRange)
                guard found.location != NSNotFound else { break }

                if options.contains(.wholeWord), !isWordBoundary(ns: ns, found: found) {
                    let next = found.location + 1
                    guard next < ns.length else { break }
                    searchRange = NSRange(location: next, length: ns.length - next)
                    continue
                }

                let window = 40
                let snippetStart = max(0, found.location - window)
                let snippetEnd = min(ns.length, found.location + found.length + window)
                let snippet = ns.substring(with: NSRange(location: snippetStart,
                                                         length: snippetEnd - snippetStart))
                let snippetMatchStart = found.location - snippetStart

                results.append(SearchMatch(
                    blockIndex: bi,
                    ordinal: ordinal,
                    range: found.location ..< (found.location + found.length),
                    snippet: snippet,
                    snippetMatchStart: snippetMatchStart
                ))
                ordinal += 1

                let next = found.location + found.length
                guard next < ns.length else { break }
                searchRange = NSRange(location: next, length: ns.length - next)
            }
        }
        return results
    }

    /// Busca global em vários arquivos; retorna apenas os que têm ocorrências (R5.2).
    public static func findInFiles(_ inputs: [(url: URL, document: CoreDocument)],
                                   query: String, options: SearchOptions = []) -> [FileSearchResult] {
        inputs.compactMap { input in
            let matches = findMatches(in: input.document, query: query, options: options)
            guard !matches.isEmpty else { return nil }
            return FileSearchResult(url: input.url, matches: matches)
        }
    }

    private static func isWord(_ ns: NSString, at index: Int) -> Bool {
        guard index >= 0, index < ns.length else { return false }
        let ch = ns.character(at: index)
        guard let scalar = Unicode.Scalar(ch) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
    }

    private static func isWordBoundary(ns: NSString, found: NSRange) -> Bool {
        !isWord(ns, at: found.location - 1) && !isWord(ns, at: found.location + found.length)
    }
}
