import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: DocumentStore

    var body: some View {
        List(store.documents.indices, id: \.self) { index in
            SidebarRow(title: store.documents[index].title,
                       isActive: index == store.activeIndex)
                .onTapGesture(count: 1) {
                    store.activeIndex = index
                }
                .onTapGesture(count: 2) {
                    store.openInNewTabFromSidebar(at: index)
                }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }
}

private struct SidebarRow: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .foregroundColor(isActive ? .accentColor : .primary)
            .fontWeight(isActive ? .semibold : .regular)
    }
}
