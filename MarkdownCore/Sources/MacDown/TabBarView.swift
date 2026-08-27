import SwiftUI
import MarkdownCore

/// R6.1 — barra de abas estilo VSCode com integração visual ao conteúdo.
struct TabBarView: View {
    @ObservedObject var store: TabStore
    var onOpenFile: () -> Void
    var recordVisit: (URL) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isActive: tab.id == store.activeTabID,
                    updateSummary: tab.hasExternalUpdate ? (tab.diffResult?.summary ?? "Atualizado") : nil,
                    onSelect: { store.select(tab.id) },
                    onClose: { store.close(id: tab.id) }
                )
            }
            Button {
                onOpenFile()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Open file")
            .accessibilityLabel("New tab")
            .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 0)
        .background(Color(nsColor: .controlBackgroundColor))
    }

}

private extension Color {
    static let mdBg = Color(nsColor: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    static let mdBgDark = Color(nsColor: NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0))

    static var mdContentBackground: Color {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .mdBgDark : .mdBg
    }
}

struct TabItemView: View {
    let tab: ReaderTab
    let isActive: Bool
    var updateSummary: String?
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false
    @State private var hoveringClose = false

    var body: some View {
        HStack(spacing: 6) {
            if let updateSummary {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                    .help(updateSummary)
                    .accessibilityLabel("Conteúdo atualizado: \(updateSummary)")
            }
            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: 140)
            if hovering || isActive {
                Button(action: onClose) {
                    Image(systemName: hoveringClose ? "xmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hoveringClose = $0 }
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .font(isActive ? .system(size: 12, weight: .medium) : .system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            VStack(spacing: 0) {
                Color.accentColor.frame(height: isActive ? 2 : 0)
                isActive ? Color.mdContentBackground : Color.clear
            }
        )
        .opacity(isActive ? 1.0 : (hovering ? 0.85 : 0.55))
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab", action: onClose)
        }
    }
}
