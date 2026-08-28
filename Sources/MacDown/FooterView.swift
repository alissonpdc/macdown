import SwiftUI
import MacDownCore

/// R8.1 — Rodapé fixo: breadcrumb + contagem palavras/caracteres + tasks agregadas.
/// R10.1 — badge de links quebrados abre popover com a lista; clicar num item
/// rola o documento até a ocorrência do link.
struct FooterView: View {
    let info: FooterInfo
    /// R10.1 — callback ao clicar num item do popover (nil = popover sem navegação).
    var onSelectBrokenLink: ((BrokenLink) -> Void)?

    @State private var showBrokenList = false

    var body: some View {
        HStack(spacing: 12) {
            Text(info.breadcrumb)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            // R10.1 — badge discreto de links quebrados; clique abre a lista
            if !info.brokenLinks.isEmpty {
                Button {
                    showBrokenList = true
                } label: {
                    Label("\(info.brokenLinks.count) broken link\(info.brokenLinks.count == 1 ? "" : "s")",
                          systemImage: "link.badge.clock")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Links quebrados neste documento — clique para ver")
                .accessibilityLabel("\(info.brokenLinks.count) broken links")
                .popover(isPresented: $showBrokenList, arrowEdge: .bottom) {
                    brokenListPopover
                }
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

    // MARK: R10.1 — popover com a lista de links quebrados

    private var brokenListPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "link.badge.clock")
                    .foregroundStyle(.orange)
                Text("Broken links (\(info.brokenLinks.count))")
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            List(info.brokenLinks, id: \.href) { link in
                Button {
                    onSelectBrokenLink?(link)
                    showBrokenList = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon(for: link.reason))
                            .foregroundStyle(.orange)
                            .help(reasonText(for: link.reason))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(link.href)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.callout)
                                .foregroundStyle(.primary)
                            Text(reasonText(for: link.reason))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.right.circle")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .frame(width: 360, height: min(CGFloat(info.brokenLinks.count) * 44 + 60, 320))
    }

    private func icon(for reason: BrokenLink.Reason) -> String {
        switch reason {
        case .fileNotFound: return "doc.questionmark"
        case .anchorNotFound: return "number"
        }
    }

    private func reasonText(for reason: BrokenLink.Reason) -> String {
        switch reason {
        case .fileNotFound: return "file not found"
        case .anchorNotFound: return "anchor not found"
        }
    }
}
