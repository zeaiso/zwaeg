import SwiftUI

/// A user's personal mascot. Three pools: the Zwäg blob set (18, asset
/// catalog) and 250 funky avatar characters per gender (bundled PNGs,
/// DiceBear avataaars, free for commercial use).
/// Deterministic seeding gives battle opponents stable faces.
struct Buddy: Codable, Equatable, Hashable {
    /// "blob", "m", "f", "custom" or "monster".
    var kind: String
    var index: Int
    /// Wardrobe traits and cached image file for kind "custom".
    var traits: AvatarTraits?
    /// Monster traits for kind "monster"; shares the cached file field.
    var monster: MonsterTraits?
    var file: String?

    static let blobColorCount = 6
    static let blobFaceCount = 3
    static let blobCount = 18
    static let avatarCount = 250

    static let colorNames = ["coral", "lime", "blue", "purple", "yellow", "pink"]

    /// Palette used for picker accents and glow shadows.
    static let palette: [Color] = [
        Color(red: 1.0, green: 0.33, blue: 0.19),
        Color(red: 0.61, green: 0.8, blue: 0.25),
        Color(red: 0.28, green: 0.66, blue: 1.0),
        Color(red: 0.55, green: 0.49, blue: 0.95),
        Color(red: 1.0, green: 0.77, blue: 0.25),
        Color(red: 1.0, green: 0.51, blue: 0.6),
    ]

    var assetName: String {
        switch kind {
        case "custom", "monster":
            return ""
        case "m", "f":
            return "\(kind)-\(index % Self.avatarCount)"
        default:
            let color = (index / Self.blobFaceCount) % Self.blobColorCount
            let face = index % Self.blobFaceCount
            return "buddy-\(Self.colorNames[color])-\(face + 1)"
        }
    }

    var bodyColor: Color {
        Self.palette[index % Self.palette.count]
    }

    static func random(for sex: Sex) -> Buddy {
        Buddy(kind: sex == .male ? "m" : "f", index: Int.random(in: 0..<avatarCount))
    }

    static func randomBlob() -> Buddy {
        Buddy(kind: "blob", index: Int.random(in: 0..<blobCount))
    }

    static func custom(traits: AvatarTraits, file: String) -> Buddy {
        var buddy = Buddy(kind: "custom", index: 0)
        buddy.traits = traits
        buddy.file = file
        return buddy
    }

    static func monster(traits: MonsterTraits, file: String) -> Buddy {
        var buddy = Buddy(kind: "monster", index: 0)
        buddy.monster = traits
        buddy.file = file
        return buddy
    }

    /// Absolute path of the cached custom or monster image, if any.
    var customImagePath: String? {
        guard kind == "custom" || kind == "monster", let file else { return nil }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return folder?.appendingPathComponent(file).path
    }

    /// Stable buddy for a seed string (bot names, participant ids).
    /// Mixes all three pools so battle bots feel varied.
    static func seeded(_ text: String) -> Buddy {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        switch hash % 3 {
        case 0: return Buddy(kind: "blob", index: Int((hash / 7) % UInt64(blobCount)))
        case 1: return Buddy(kind: "m", index: Int((hash / 7) % UInt64(avatarCount)))
        default: return Buddy(kind: "f", index: Int((hash / 7) % UInt64(avatarCount)))
        }
    }

    // MARK: - Persistence (JSON in UserProfile.buddyRaw)

    init(kind: String, index: Int) {
        self.kind = kind
        self.index = index
    }

    /// Tolerates the earlier formats: {color, face} and {color, eyes, ...}.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let kind = try container.decodeIfPresent(String.self, forKey: .kind),
           let index = try container.decodeIfPresent(Int.self, forKey: .index) {
            self.kind = kind
            self.index = index
            traits = try container.decodeIfPresent(AvatarTraits.self, forKey: .traits)
            monster = try container.decodeIfPresent(MonsterTraits.self, forKey: .monster)
            file = try container.decodeIfPresent(String.self, forKey: .file)
            return
        }
        kind = "blob"
        var color = 0
        var face = 0
        if let legacy = try? decoder.container(keyedBy: LegacyKeys.self) {
            if let value = try? legacy.decodeIfPresent(Int.self, forKey: .color) {
                color = value
            }
            if let value = try? legacy.decodeIfPresent(Int.self, forKey: .face) {
                face = value
            } else if let value = try? legacy.decodeIfPresent(Int.self, forKey: .eyes) {
                face = value
            }
        }
        index = (color % Self.blobColorCount) * Self.blobFaceCount + (face % Self.blobFaceCount)
    }

    private enum LegacyKeys: String, CodingKey {
        case color, face, eyes
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
