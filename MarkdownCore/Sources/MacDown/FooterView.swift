import SwiftUI
import MarkdownCore

/// R8.1 — Rodapé fixo: breadcrumb + contagem palavras/caracteres + tasks agregadas.
struct FooterView: View {
    let info: FooterInfo

    var body: some View {
        HStack(spacing: 12) {
            Text(info.breadcrumb)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            // R10.1 — badge discreto de links quebrados; hover lista os hrefs
            if !info.brokenLinks.isEmpty {
                Label("\(info.brokenLinks.count) broken link\(info.brokenLinks.count == 1 ? "" : "s")",
                      systemImage: "link.badge.clock")
                    .foregroundStyle(.orange)
                    .help(info.brokenLinks.map { link in
                        let reason = switch link.reason {
                        case .fileNotFound: "arquivo inexistente"
                        case .anchorNotFound: "âncora inexistente"
                        }
                        return "\(link.href) — \(reason)"
                    }.joined(separator: "\n"))
                    .accessibilityLabel("\(info.brokenLinks.count) links quebrados")
            }
            if let taskText = info.taskSummary {
                Label(taskText, systemImage: "checklist")
            }
            Text("\(info.wordCount) words")
            Text("\(info.characterCount) chars")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}
