import Foundation

/// R13 — diff puro por blocos entre a versão confirmada (baseline) e a atual.
///
/// Semântica:
/// - `.unchanged`: bloco novo com correspondência exata no baseline (LCS);
/// - `.strong` / `.weak`: bloco novo sem correspondência — fraco quando a mesma
///   assinatura de conteúdo já foi destacada em round anterior (R13.2);
/// - `removedCount`: blocos do baseline que não sobreviveram ("−N").
public enum BlockDiffer {
    public enum Status: Equatable {
        case unchanged
        /// Mudança nova neste round (destaque forte).
        case strong
        /// Mudança idêntica à de um round anterior (destaque fraco).
        case weak
    }

    public struct Removal: Equatable {
        /// Índice no documento novo onde o conteúdo removido aparecia.
        public let insertAt: Int
        /// Texto legível dos blocos removidos (runs consecutivos agrupados).
        public let texts: [String]

        public init(insertAt: Int, texts: [String]) {
            self.insertAt = insertAt
            self.texts = texts
        }
    }

    public struct Result: Equatable {
        /// Status alinhado aos blocos da versão atual.
        public let statuses: [Status]
        /// Blocos do baseline não pareados ("−N").
        public let removedCount: Int
        /// R13.1 — remoções com posição, para exibição na visão Diff.
        public let removals: [Removal]
        /// Blocos alterados/adicionados ("+N").
        public var changedCount: Int { statuses.filter { $0 != .unchanged }.count }
        /// R13.1 — resumo para o indicador: "Atualizado · +8 −2".
        public var summary: String { "Atualizado · +\(changedCount) −\(removedCount)" }

        public init(statuses: [Status], removedCount: Int, removals: [Removal] = []) {
            self.statuses = statuses
            self.removedCount = removedCount
            self.removals = removals
        }

        public static let clean = Result(statuses: [], removedCount: 0)
    }

    // MARK: assinaturas

    /// Assinatura estável do conteúdo de um bloco (ignora decoração markdown).
    public static func signature(of block: any BlockNode) -> String {
        switch block {
        case let h as HeadingNode: return "h:\(h.level):\(h.inlineText)"
        case let p as ParagraphNode: return "p:\(p.text)"
        case let c as CodeBlockNode: return "c:\(c.language ?? ""):\(c.code)"
        case let q as QuoteNode: return "q:\(q.plainText)"
        case let l as ListNode: return "l:\(l.items.joined(separator: "\n"))"
        case let t as TaskListItemsNode:
            return "t:" + t.items.map { "\($0.isChecked ? "[x]" : "[ ]")\($0.text)" }.joined(separator: "\n")
        case let t as TableNode:
            return "tbl:\((t.headerCells + t.rows.flatMap { $0 }).joined(separator: "|"))"
        case let g as GenericBlockNode: return "g:\(g.kindName)"
        default: return String(describing: block)
        }
    }

    // MARK: texto legível

    /// Texto plano do bloco, para exibir remoções na visão Diff.
    public static func plainText(of block: any BlockNode) -> String {
        switch block {
        case let h as HeadingNode: return h.inlineText
        case let p as ParagraphNode: return p.text
        case let c as CodeBlockNode: return c.code
        case let q as QuoteNode: return q.plainText
        case let l as ListNode:
            return l.items.map { "- \($0)" }.joined(separator: "\n")
        case let t as TaskListItemsNode:
            return t.items.map { "\($0.isChecked ? "[x]" : "[ ]") \($0.text)" }.joined(separator: "\n")
        case let t as TableNode:
            return ([t.headerCells] + t.rows).map { $0.joined(separator: " | ") }.joined(separator: "\n")
        case let g as GenericBlockNode: return g.kindName
        default: return ""
        }
    }

    // MARK: diff

    public static func diff(baseline: CoreDocument,
                            updated: CoreDocument,
                            knownChanges: Set<String> = []) -> Result {
        let old = baseline.blocks.map(signature(of:))
        let new = updated.blocks.map(signature(of:))
        let table = lcsTable(old, new)

        var matchOfNew = [Int?](repeating: nil, count: new.count)
        var matchOfOld = [Int?](repeating: nil, count: old.count)
        var i = 0, j = 0
        while i < old.count && j < new.count {
            if old[i] == new[j] {
                matchOfNew[j] = i
                matchOfOld[i] = j
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }

        var statuses = [Status](repeating: .unchanged, count: new.count)
        for jj in 0..<new.count where matchOfNew[jj] == nil {
            statuses[jj] = knownChanges.contains(new[jj]) ? .weak : .strong
        }

        // runs consecutivos de blocos antigos removidos; posição = índice novo do próximo pareado
        var removals: [Removal] = []
        var k = 0
        while k < old.count {
            guard matchOfOld[k] == nil else { k += 1; continue }
            let start = k
            while k < old.count && matchOfOld[k] == nil { k += 1 }
            let insertAt = k < old.count ? matchOfOld[k]! : new.count
            let texts = (start..<k).map { plainText(of: baseline.blocks[$0]) }
            if let last = removals.last, last.insertAt == insertAt {
                removals[removals.count - 1] = Removal(insertAt: insertAt, texts: last.texts + texts)
            } else {
                removals.append(Removal(insertAt: insertAt, texts: texts))
            }
        }

        return Result(statuses: statuses,
                      removedCount: old.count - matchOfNew.compactMap { $0 }.count,
                      removals: removals)
    }

    private static func lcsTable(_ a: [String], _ b: [String]) -> [[Int]] {
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        return lcs
    }

    static func diff(oldSignatures: [String], newSignatures: [String],
                     knownChanges: Set<String>) -> Result {
        let n = oldSignatures.count, m = newSignatures.count
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = oldSignatures[i] == newSignatures[j]
                    ? lcs[i + 1][j + 1] + 1
                    : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }

        var matchOfNew = [Int?](repeating: nil, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if oldSignatures[i] == newSignatures[j] {
                matchOfNew[j] = i
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }

        var statuses = [Status](repeating: .unchanged, count: m)
        for jj in 0..<m where matchOfNew[jj] == nil {
            statuses[jj] = knownChanges.contains(newSignatures[jj]) ? .weak : .strong
        }
        let matches = matchOfNew.compactMap { $0 }.count

        return Result(statuses: statuses, removedCount: n - matches)
    }
}
