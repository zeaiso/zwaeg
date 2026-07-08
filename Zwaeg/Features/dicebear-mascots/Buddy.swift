import SwiftUI

/// A user's personal mascot: body color, eyes, mouth and accessory.
/// Deterministic seeding gives battle opponents stable faces.
struct Buddy: Codable, Equatable {
    var color: Int
    var eyes: Int
    var mouth: Int
    var accessory: Int

    static let colorCount = 6
    static let eyeCount = 3
    static let mouthCount = 3
    static let accessoryCount = 4

    /// Body colors with their lighter belly shades.
    static let palette: [(body: Color, belly: Color)] = [
        (Color(red: 1.0, green: 0.42, blue: 0.29), Color(red: 1.0, green: 0.65, blue: 0.52)),
        (Color(red: 0.62, green: 0.82, blue: 0.26), Color(red: 0.78, green: 0.91, blue: 0.52)),
        (Color(red: 0.28, green: 0.66, blue: 1.0), Color(red: 0.55, green: 0.79, blue: 1.0)),
        (Color(red: 0.55, green: 0.49, blue: 0.95), Color(red: 0.71, green: 0.66, blue: 0.98)),
        (Color(red: 1.0, green: 0.77, blue: 0.25), Color(red: 1.0, green: 0.87, blue: 0.55)),
        (Color(red: 1.0, green: 0.51, blue: 0.6), Color(red: 1.0, green: 0.7, blue: 0.75)),
    ]

    var bodyColor: Color { Self.palette[color % Self.colorCount].body }
    var bellyColor: Color { Self.palette[color % Self.colorCount].belly }

    static func random() -> Buddy {
        Buddy(color: Int.random(in: 0..<colorCount),
              eyes: Int.random(in: 0..<eyeCount),
              mouth: Int.random(in: 0..<mouthCount),
              accessory: Int.random(in: 0..<accessoryCount))
    }

    /// Stable buddy for a seed string (bot names, participant ids).
    static func seeded(_ text: String) -> Buddy {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Buddy(color: Int(hash % UInt64(colorCount)),
                     eyes: Int((hash / 7) % UInt64(eyeCount)),
                     mouth: Int((hash / 31) % UInt64(mouthCount)),
                     accessory: Int((hash / 101) % UInt64(accessoryCount)))
    }

    // MARK: - Persistence (JSON in UserProfile.buddyRaw)

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) -> Buddy? {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Buddy.self, from: data)
    }
}
