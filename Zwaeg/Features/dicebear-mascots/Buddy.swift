import SwiftUI

/// A user's personal mascot, backed by the bundled DiceBear thumbs set
/// (CC0) tuned to the Zwäg palette: 6 colors x 3 faces.
/// Deterministic seeding gives battle opponents stable buddies.
struct Buddy: Codable, Equatable, Hashable {
    var color: Int
    var face: Int

    static let colorCount = 6
    static let faceCount = 3

    static let colorNames = ["coral", "lime", "blue", "purple", "yellow", "pink"]

    /// Body colors, used for picker dots and glow shadows.
    static let palette: [Color] = [
        Color(red: 1.0, green: 0.33, blue: 0.19),
        Color(red: 0.61, green: 0.8, blue: 0.25),
        Color(red: 0.28, green: 0.66, blue: 1.0),
        Color(red: 0.55, green: 0.49, blue: 0.95),
        Color(red: 1.0, green: 0.77, blue: 0.25),
        Color(red: 1.0, green: 0.51, blue: 0.6),
    ]

    var assetName: String {
        "buddy-\(Self.colorNames[color % Self.colorCount])-\(face % Self.faceCount + 1)"
    }

    var bodyColor: Color {
        Self.palette[color % Self.colorCount]
    }

    static func random() -> Buddy {
        Buddy(color: Int.random(in: 0..<colorCount), face: Int.random(in: 0..<faceCount))
    }

    /// Stable buddy for a seed string (bot names, participant ids).
    static func seeded(_ text: String) -> Buddy {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Buddy(color: Int(hash % UInt64(colorCount)),
                     face: Int((hash / 7) % UInt64(faceCount)))
    }

    // MARK: - Persistence (JSON in UserProfile.buddyRaw)

    init(color: Int, face: Int) {
        self.color = color
        self.face = face
    }

    /// Tolerates the earlier placeholder format that stored eyes/mouth/accessory.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = (try container.decodeIfPresent(Int.self, forKey: .color)) ?? 0
        if let face = try container.decodeIfPresent(Int.self, forKey: .face) {
            self.face = face
        } else {
            let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
            face = ((try? legacy?.decodeIfPresent(Int.self, forKey: .eyes)) ?? 0) ?? 0
        }
    }

    private enum LegacyKeys: String, CodingKey {
        case eyes
    }

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) -> Buddy? {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Buddy.self, from: data)
    }
}
