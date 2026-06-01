import SwiftUI

struct RecentsSection: View {
    @EnvironmentObject var recentsManager: RecentsManager
    @EnvironmentObject var store: DocumentStore

    var body: some View {
        if recentsManager.recents.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            Text("Nenhum arquivo recente")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }

    private var list: some View {
        List(recentsManager.recents, id: \.url) { recent in
            RecentRow(url: recent.url, title: recent.title)
                .onTapGesture(count: 1) {
                    openFile(recent.url)
                }
                .onTapGesture(count: 2) {
                    openFileInNewTab(recent.url)
                }
        }
        .listStyle(.sidebar)
    }

    private func openFile(_ url: URL) {
        try? store.open(url)
    }

    private func openFileInNewTab(_ url: URL) {
        try? store.openInNewTab(url)
    }
}

private struct RecentRow: View {
    let url: URL
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
