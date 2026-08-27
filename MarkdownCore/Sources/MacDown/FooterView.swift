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
