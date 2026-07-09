import SwiftUI
import Observation

/// The selectable app looks: warm-colorful (default), dark, and greyscale.
enum AppLook: String, CaseIterable, Identifiable {
    case munch
    case midnight
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .munch: return "Munch"
        case .midnight: return "Midnight"
        case .mono: return "Mono"
        }
    }

    var detail: String {
        switch self {
        case .munch: return "Hell und farbig".loc
        case .midnight: return "Dunkel und gemütlich".loc
        case .mono: return "Schlicht in Graustufen".loc
        }
    }

    /// Swatch colors for the picker preview, independent of the active look.
    var previewBackground: Color {
        switch self {
        case .munch: return Color(red: 0.953, green: 0.925, blue: 0.906)
        case .midnight: return Color(red: 0.11, green: 0.095, blue: 0.085)
        case .mono: return Color(red: 0.93, green: 0.93, blue: 0.93)
        }
    }

    var previewAccent: Color {
        switch self {
        case .munch: return Color(red: 1.0, green: 0.325, blue: 0.188)
        case .midnight: return Color(red: 1.0, green: 0.45, blue: 0.33)
        case .mono: return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }
}

/// Persisted look selection; reading `look` inside a view body registers
/// observation, so switching re-renders the whole app live (same trick as Lingo).
@Observable
final class Themer {
    static let shared = Themer()

    var look: AppLook {
        didSet { UserDefaults.standard.set(look.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "appLook"

    private init() {
        // Debug: -look munch|midnight|mono forces a look for simulator screenshots.
        if let flagIndex = CommandLine.arguments.firstIndex(of: "-look"),
           CommandLine.arguments.indices.contains(flagIndex + 1),
           let forced = AppLook(rawValue: CommandLine.arguments[flagIndex + 1]) {
            look = forced
            return
        }
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        look = AppLook(rawValue: raw) ?? .munch
    }
}

/// "Munch" palette: warm cream background, soft white cards, coral accent, warm ink text.
/// Midnight swaps the surfaces for warm dark tones; Mono keeps Munch and lets a
/// root-level grayscale filter drain the color.
enum Theme {
    private static var look: AppLook { Themer.shared.look }

    static var background: Color {
        look == .midnight ? Color(red: 0.10, green: 0.088, blue: 0.078)
                          : Color(red: 0.953, green: 0.925, blue: 0.906)
    }

    static var card: Color {
        look == .midnight ? Color(red: 0.155, green: 0.135, blue: 0.12)
                          : Color(red: 0.996, green: 0.984, blue: 0.976)
    }

    static var field: Color {
        look == .midnight ? Color(red: 0.235, green: 0.205, blue: 0.185)
                          : Color(red: 0.918, green: 0.878, blue: 0.851)
    }

    /// Coral primary accent; pair with white text.
    static var accent: Color {
        look == .midnight ? Color(red: 1.0, green: 0.38, blue: 0.25)
                          : Color(red: 1.0, green: 0.325, blue: 0.188)
    }

    /// Soft peach for icon chips and selected states.
    static var accentSoft: Color {
        look == .midnight ? Color(red: 0.26, green: 0.16, blue: 0.125)
                          : Color(red: 1.0, green: 0.929, blue: 0.902)
    }

    static var yellow: Color {
        look == .midnight ? Color(red: 0.28, green: 0.24, blue: 0.14)
                          : Color(red: 1.0, green: 0.945, blue: 0.839)
    }

    /// Warm near-black for text; warm cream on Midnight.
    static var ink: Color {
        look == .midnight ? Color(red: 0.96, green: 0.94, blue: 0.925)
                          : Color(red: 0.129, green: 0.11, blue: 0.102)
    }

    /// Text and icons sitting on the coral accent.
    static let onAccent = Color.white

    /// Shadows stay dark in every look (a light ink would glow on Midnight).
    static let shadow = Color.black

    /// Track behind rings and progress bars on soft surfaces.
    static var track: Color {
        look == .midnight ? .white.opacity(0.14) : .white.opacity(0.7)
    }

    /// Decorative blush circles on the summary card.
    static var decorStrong: Color {
        look == .midnight ? .white.opacity(0.05) : .white.opacity(0.35)
    }

    static var decorSoft: Color {
        look == .midnight ? .white.opacity(0.04) : .white.opacity(0.25)
    }

    /// System appearance matching the look, so .secondary and system greys adapt.
    static var colorScheme: ColorScheme {
        look == .midnight ? .dark : .light
    }

    /// Root-level grayscale amount; Mono drains every color in the app.
    static var grayscale: Double {
        look == .mono ? 1 : 0
    }
}

extension Color {
    /// Slightly deepened coral, readable as a tint on light surfaces.
    static var appAccent: Color {
        Themer.shared.look == .midnight ? Color(red: 1.0, green: 0.47, blue: 0.35)
                                        : Color(red: 0.898, green: 0.29, blue: 0.165)
    }
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
