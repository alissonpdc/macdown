import SwiftUI
import MacDownCore

/// R6.1 — barra de abas estilo VSCode com integração visual ao conteúdo.
/// Vive na coluna central (ao lado do TOC em altura total): com uma aba só,
/// ela fica no meio; com várias, o grupo inteiro se centraliza e vira scroll
/// horizontal quando excede a largura da coluna.
struct TabBarView: View {
    @ObservedObject var store: TabStore
    var onOpenFile: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
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
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open file")
                    .accessibilityLabel("New tab")
                    .padding(.leading, 4)
                }
                // minWidth = largura da coluna central: conteúdo menor que a
                // viewport fica CENTRALIZADO; maior, habilita o scroll horizontal.
                .padding(.horizontal, 8)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 32)
        .background(MDTheme.chromeBackground)
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
        // Sem .opacity no conjunto: no modo claro o texto sumia sobre o fundo.
        // Cor de texto explícita por estado + fundo sólido por estado.
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isActive ? Color.accentColor : .clear)
                    .frame(height: isActive ? 2 : 0)
                isActive ? MDTheme.contentBackground
                    : hovering ? Color.primary.opacity(0.06)
                    : Color.clear
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab", action: onClose)
        }
    }
}
