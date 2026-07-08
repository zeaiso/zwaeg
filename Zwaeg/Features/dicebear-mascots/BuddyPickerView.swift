import SwiftUI

/// Fun buddy customizer: pick a color, shuffle the face, cycle accessories.
struct BuddyPickerView: View {
    @Binding var buddy: Buddy

    var body: some View {
        VStack(spacing: 24) {
            BuddyView(buddy: buddy, size: 150)
                .shadow(color: buddy.bodyColor.opacity(0.35), radius: 16, y: 8)
                .animation(.snappy, value: buddy)

            HStack(spacing: 12) {
                ForEach(0..<Buddy.colorCount, id: \.self) { index in
                    Button {
                        withAnimation(.snappy) { buddy.color = index }
                    } label: {
                        Circle()
                            .fill(Buddy.palette[index].body)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Theme.ink.opacity(buddy.color == index ? 0.8 : 0),
                                                     lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                pickerButton(symbol: "dice.fill", label: "Gesicht") {
                    var fresh = buddy
                    while fresh.eyes == buddy.eyes && fresh.mouth == buddy.mouth {
                        fresh.eyes = Int.random(in: 0..<Buddy.eyeCount)
                        fresh.mouth = Int.random(in: 0..<Buddy.mouthCount)
                    }
                    withAnimation(.snappy) { buddy = fresh }
                }
                pickerButton(symbol: "hat.cap.fill", label: "Accessoire") {
                    withAnimation(.snappy) {
                        buddy.accessory = (buddy.accessory + 1) % Buddy.accessoryCount
                    }
                }
            }
        }
    }

    private func pickerButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.fredoka(14, .semibold))
                Text(label)
                    .font(.fredoka(15, .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.card, in: Capsule())
            .foregroundStyle(Theme.ink)
            .shadow(color: Theme.ink.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
