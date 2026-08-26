import SwiftUI
import MarkdownCore

/// R6.1 — barra de abas estilo Chrome com botão de fechar e nova aba.
struct TabBarView: View {
    @ObservedObject var store: TabStore
    var onOpenFile: () -> Void
    var recordVisit: (URL) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(store.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isActive: tab.id == store.activeTabID,
                    onConfirmUpdate: { store.confirmExternalUpdate(in: tab.id) },
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

}

struct TabItemView: View {
    let tab: ReaderTab
    let isActive: Bool
    var hasExternalUpdate = false
    var onConfirmUpdate: () -> Void = {}
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false
    @State private var hoveringClose = false

    var body: some View {
        HStack(spacing: 6) {
            // R4.2 — indicador discreto de atualizado; clique confirma a leitura
            if tab.hasExternalUpdate {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                    .onTapGesture(perform: onConfirmUpdate)
                    .help("Conteúdo atualizado fora do app — clique para confirmar")
                    .accessibilityLabel("Conteúdo atualizado")
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
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(isActive ? Color.primary.opacity(0.15) : .clear)
        )
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab", action: onClose)
        }
    }
}
