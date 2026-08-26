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

    public struct Result: Equatable {
        /// Status alinhado aos blocos da versão atual.
        public let statuses: [Status]
        /// Blocos do baseline não pareados ("−N").
        public let removedCount: Int
        /// Blocos alterados/adicionados ("+N").
        public var changedCount: Int { statuses.filter { $0 != .unchanged }.count }
        /// R13.1 — resumo para o indicador: "Atualizado · +8 −2".
        public var summary: String { "Atualizado · +\(changedCount) −\(removedCount)" }

        public init(statuses: [Status], removedCount: Int) {
            self.statuses = statuses
            self.removedCount = removedCount
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

    // MARK: diff

    public static func diff(baseline: CoreDocument,
                            updated: CoreDocument,
                            knownChanges: Set<String> = []) -> Result {
        let old = baseline.blocks.map(signature(of:))
        let new = updated.blocks.map(signature(of:))
        return diff(oldSignatures: old, newSignatures: new, knownChanges: knownChanges)
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
