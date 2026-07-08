import SwiftUI

/// "Munch" palette: warm cream background, soft white cards, coral accent, warm ink text.
enum Theme {
    static let background = Color(red: 0.953, green: 0.925, blue: 0.906)
    static let card = Color(red: 0.996, green: 0.984, blue: 0.976)
    static let field = Color(red: 0.918, green: 0.878, blue: 0.851)
    /// Coral primary accent; pair with white text.
    static let accent = Color(red: 1.0, green: 0.325, blue: 0.188)
    /// Soft peach for icon chips and selected states.
    static let accentSoft = Color(red: 1.0, green: 0.929, blue: 0.902)
    static let yellow = Color(red: 1.0, green: 0.945, blue: 0.839)
    /// Warm near-black for text.
    static let ink = Color(red: 0.129, green: 0.11, blue: 0.102)
    /// Text and icons sitting on the coral accent.
    static let onAccent = Color.white
}

extension Color {
    /// Slightly deepened coral, readable as a tint on light surfaces.
    static let appAccent = Color(red: 0.898, green: 0.29, blue: 0.165)
}

extension Font {
    /// Fredoka, the app's display face (headings, numbers, buttons).
    static func fredoka(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = "Fredoka-SemiBold"
        case .medium:
            name = "Fredoka-Medium"
        default:
            name = "Fredoka-Regular"
        }
        return .custom(name, size: size)
    }
}

/// The Znüni mascot: a friendly face on a coral gradient circle.
struct MascotAvatar: View {
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.35), Theme.accent],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: size * 0.10) {
                eye
                eye
            }
            .offset(y: -size * 0.10)
            UnevenRoundedRectangle(topLeadingRadius: size * 0.05,
                                   bottomLeadingRadius: size * 0.17,
                                   bottomTrailingRadius: size * 0.17,
                                   topTrailingRadius: size * 0.05)
                .fill(Color(red: 0.24, green: 0.12, blue: 0.08))
                .frame(width: size * 0.34, height: size * 0.15)
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size * 0.24, height: size * 0.24)
            Circle()
                .fill(Color(red: 0.24, green: 0.12, blue: 0.08))
                .frame(width: size * 0.13, height: size * 0.13)
        }
    }
}
