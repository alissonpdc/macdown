import SwiftUI

struct FindBarView: View {
    @EnvironmentObject var searchState: SearchState
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar", text: $searchState.query)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit { searchState.goToNext() }
                .frame(minWidth: 160)

            Text(searchState.counterText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Button { searchState.goToPrevious() } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(searchState.matchMap.total == 0)
            .help("Anterior")

            Button { searchState.goToNext() } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(searchState.matchMap.total == 0)
            .help("Próxima")

            Text(searchState.mode == .allTabs ? "Todas as abas" : "Arquivo")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            Button { searchState.close() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Fechar")

            // Hidden hotkey: Shift+Enter navigates to the previous match.
            Button("") { searchState.goToPrevious() }
                .keyboardShortcut(.return, modifiers: .shift)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onExitCommand { searchState.close() }
        .onAppear { fieldFocused = true }
        .onChange(of: searchState.isVisible) { visible in
            if visible { fieldFocused = true }
        }
    }
}
