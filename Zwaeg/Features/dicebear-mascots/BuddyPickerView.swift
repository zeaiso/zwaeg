import SwiftUI

/// Random-first buddy picker: big preview, a dice to reroll, and a
/// pool switch between the funky avatars (gender matched) and the blobs.
struct BuddyPickerView: View {
    @Binding var buddy: Buddy
    var sex: Sex

    @State private var showStudio = false

    private var debugOpensStudio: Bool {
        CommandLine.arguments.contains("-open-studio")
    }

    var body: some View {
        VStack(spacing: 26) {
            BuddyView(buddy: buddy, size: 168)
                .shadow(color: buddy.bodyColor.opacity(0.4), radius: 18, y: 9)
                .animation(.snappy, value: buddy)
                .onAppear {
                    if debugOpensStudio {
                        Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            showStudio = true
                        }
                    }
                }

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

            Button {
                showStudio = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tshirt.fill")
                        .font(.fredoka(14, .semibold))
                    Text("Selbst gestalten")
                        .font(.fredoka(15, .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Theme.card, in: Capsule())
                .foregroundStyle(Theme.ink)
                .shadow(color: Theme.ink.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showStudio) {
                BuddyStudioView(sex: sex, initialTraits: buddy.traits) { custom in
                    buddy = custom
                }
            }
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
