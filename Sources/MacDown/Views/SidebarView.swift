import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var recentsManager: RecentsManager
    @EnvironmentObject var folderManager: FolderManager

    @State private var dividerPosition: CGFloat = 0.4

    var body: some View {
        VStack(spacing: 0) {
            // Recentes Section
            RecentsSection()
                .frame(maxHeight: .infinity, alignment: .top)

            // Draggable Divider
            Divider()
                .padding(.vertical, 4)

            // Folders Section
            FoldersSection()
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 180)
    }
}
