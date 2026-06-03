import SwiftUI
import UniformTypeIdentifiers

/// Chrome-style horizontal tab bar for the open documents.
struct TabBarView: View {
    @EnvironmentObject var store: DocumentStore
    @State private var draggingID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(store.documents.enumerated()), id: \.element.id) { index, doc in
                    TabItemView(
                        title: doc.title,
                        isActive: index == store.activeIndex,
                        onSelect: { store.activeIndex = index },
                        onClose: { store.close(at: index) }
                    )
                    .onDrag {
                        draggingID = doc.id
                        return NSItemProvider(object: doc.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: TabDropDelegate(targetID: doc.id, store: store, draggingID: $draggingID)
                    )
                }

                Button {
                    presentOpenPanel(store: store)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderless)
                .help("Abrir arquivo")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .background(.bar)
    }
}

private struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 200)
        .background(
            TopRoundedRectangle(radius: 8)
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
    }
}

/// A rectangle with only its top corners rounded. macOS 13-safe (avoids
/// `UnevenRoundedRectangle`, which is macOS 14+).
private struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Live-reorders tabs as one is dragged over another.
private struct TabDropDelegate: DropDelegate {
    let targetID: UUID
    let store: DocumentStore
    @Binding var draggingID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID,
              let from = store.documents.firstIndex(where: { $0.id == draggingID }),
              let to = store.documents.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.move(from: from, to: to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
