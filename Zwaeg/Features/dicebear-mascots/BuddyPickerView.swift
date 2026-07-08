import SwiftUI

/// Gallery of all buddies; tap to choose yours.
struct BuddyPickerView: View {
    @Binding var buddy: Buddy

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 14)]

    static let allBuddies: [Buddy] = (0..<Buddy.colorCount).flatMap { color in
        (0..<Buddy.faceCount).map { Buddy(color: color, face: $0) }
    }

    var body: some View {
        VStack(spacing: 24) {
            BuddyView(buddy: buddy, size: 132)
                .shadow(color: buddy.bodyColor.opacity(0.4), radius: 16, y: 8)
                .animation(.snappy, value: buddy)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Self.allBuddies, id: \.self) { candidate in
                    Button {
                        withAnimation(.snappy) { buddy = candidate }
                    } label: {
                        BuddyView(buddy: candidate, size: 84)
                            .overlay(RoundedRectangle(cornerRadius: 84 * 0.3, style: .continuous)
                                .stroke(buddy == candidate ? Theme.ink : .clear, lineWidth: 3))
                            .scaleEffect(buddy == candidate ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
