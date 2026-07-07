import SwiftUI

/// App palette: soft sage background, white cards, lime accents, dark ink text.
enum Theme {
    static let background = Color(red: 0.937, green: 0.957, blue: 0.882)
    static let card = Color.white
    static let field = Color(red: 0.949, green: 0.961, blue: 0.918)
    /// Bright lime for fills and highlights; pair with ink text.
    static let lime = Color(red: 0.839, green: 0.937, blue: 0.353)
    static let limeSoft = Color(red: 0.925, green: 0.969, blue: 0.741)
    static let yellow = Color(red: 0.973, green: 0.918, blue: 0.353)
    /// Near-black with a green tint, for text on lime and dark buttons.
    static let ink = Color(red: 0.106, green: 0.125, blue: 0.071)
}

extension Color {
    /// Olive-lime tint readable on white; used for icons and interactive tints.
    static let appAccent = Color(red: 0.46, green: 0.60, blue: 0.11)
}
