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

    /// User-chosen accent color; nil means the look's default coral.
    var accent: Color? {
        didSet {
            if let hex = accent?.hexString {
                UserDefaults.standard.set(hex, forKey: Self.accentKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.accentKey)
            }
        }
    }

    private static let storageKey = "appLook"
    private static let accentKey = "appAccentHex"

    private init() {
        // Debug: -look munch|midnight|mono and -accent RRGGBB for screenshots.
        var initialAccent: Color?
        if let flagIndex = LaunchArgs.all.firstIndex(of: "-accent"),
           LaunchArgs.all.indices.contains(flagIndex + 1) {
            initialAccent = Color(hex: LaunchArgs.all[flagIndex + 1])
        } else if let hex = UserDefaults.standard.string(forKey: Self.accentKey) {
            initialAccent = Color(hex: hex)
        }
        accent = initialAccent

        if let flagIndex = LaunchArgs.all.firstIndex(of: "-look"),
           LaunchArgs.all.indices.contains(flagIndex + 1),
           let forced = AppLook(rawValue: LaunchArgs.all[flagIndex + 1]) {
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

    /// Primary accent: the user's chosen color, defaulting to Munch coral.
    static var accent: Color {
        if let custom = Themer.shared.accent { return custom }
        return look == .midnight ? Color(red: 1.0, green: 0.38, blue: 0.25)
                                 : Color(red: 1.0, green: 0.325, blue: 0.188)
    }

    /// Lighter partner of the accent for gradients.
    static var accentLight: Color {
        if let custom = Themer.shared.accent { return custom.opacity(0.72) }
        return Color(red: 1.0, green: 0.51, blue: 0.33)
    }

    /// Soft tint for icon chips, selected states and the summary card.
    static var accentSoft: Color {
        if let custom = Themer.shared.accent {
            return custom.opacity(look == .midnight ? 0.20 : 0.14)
        }
        return look == .midnight ? Color(red: 0.26, green: 0.16, blue: 0.125)
                                 : Color(red: 1.0, green: 0.929, blue: 0.902)
    }

    /// Warm near-black for text; warm cream on Midnight.
    static var ink: Color {
        look == .midnight ? Color(red: 0.96, green: 0.94, blue: 0.925)
                          : Color(red: 0.129, green: 0.11, blue: 0.102)
    }

    /// Text and icons sitting on the coral accent.
    static let onAccent = Color.white

    /// Text and icons sitting on an ink-filled control; inverts on Midnight
    /// where ink itself is light.
    static var onInk: Color {
        look == .midnight ? Color(red: 0.10, green: 0.088, blue: 0.078) : .white
    }

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
    /// Tint color for text and small controls; the custom accent when set.
    static var appAccent: Color {
        if let custom = Themer.shared.accent { return custom }
        return Themer.shared.look == .midnight ? Color(red: 1.0, green: 0.47, blue: 0.35)
                                               : Color(red: 0.898, green: 0.29, blue: 0.165)
    }

    /// Hex string for persisting the custom accent (Color(hex:) lives in AvatarTraits).
    var hexString: String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
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
