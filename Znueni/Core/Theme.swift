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
