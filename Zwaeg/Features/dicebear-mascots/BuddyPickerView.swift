import SwiftUI

/// Random-first buddy picker: big preview, a dice to reroll, and a
/// pool switch between the funky avatars (gender matched) and the blobs.
struct BuddyPickerView: View {
    @Binding var buddy: Buddy
    var sex: Sex

    var body: some View {
        VStack(spacing: 26) {
            BuddyView(buddy: buddy, size: 168)
                .shadow(color: buddy.bodyColor.opacity(0.4), radius: 18, y: 9)
                .animation(.snappy, value: buddy)

            HStack(spacing: 10) {
                poolChip("Funky", isActive: buddy.kind != "blob") {
                    buddy = .random(for: sex)
                }
                poolChip("Blob", isActive: buddy.kind == "blob") {
                    buddy = .randomBlob()
                }
            }

            Button {
                withAnimation(.snappy) {
                    buddy = buddy.kind == "blob" ? .randomBlob() : .random(for: sex)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "dice.fill")
                        .font(.fredoka(16, .semibold))
                    Text("Neu würfeln")
                        .font(.fredoka(17, .semibold))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule())
                .foregroundStyle(Theme.onAccent)
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func poolChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(label)
                .font(.fredoka(14, .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Theme.ink : Theme.card, in: Capsule())
                .foregroundStyle(isActive ? Theme.onAccent : .secondary)
        }
        .buttonStyle(.plain)
    }
}
