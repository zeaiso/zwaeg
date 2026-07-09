import SwiftUI

/// Habbo-style wardrobe traits for a custom avatar, mapped 1:1 to
/// DiceBear avataaars options. Thumbnails for the option racks are
/// bundled; the combined preview renders via the DiceBear API.
struct AvatarTraits: Codable, Equatable, Hashable {
    var top: String
    var hairColor: String
    var skinColor: String
    var clothes: String
    var clothesColor: String
    var accessory: String?
    var facialHair: String?

    static let tops = [
        "bigHair", "bob", "bun", "curly", "curvy", "dreads", "dreads01", "dreads02",
        "frida", "frizzle", "fro", "froBand", "hat", "hijab", "longButNotTooLong",
        "miaWallace", "shaggy", "shaggyMullet", "shavedSides", "shortCurly",
        "shortFlat", "shortRound", "shortWaved", "sides", "straight01", "straight02",
        "straightAndStrand", "theCaesar", "theCaesarAndSidePart", "turban",
        "winterHat02", "winterHat03", "winterHat04", "winterHat1",
    ]

    static let clothesList = [
        "blazerAndShirt", "blazerAndSweater", "collarAndSweater", "graphicShirt",
        "hoodie", "overall", "shirtCrewNeck", "shirtScoopNeck", "shirtVNeck",
    ]

    static let accessories = [
        "eyepatch", "kurt", "prescription01", "prescription02", "round",
        "sunglasses", "wayfarers",
    ]

    static let facialHairs = [
        "beardLight", "beardMajestic", "beardMedium", "moustacheFancy", "moustacheMagnum",
    ]

    static let hairColors = [
        "2c1b18", "4a312c", "724133", "a55728", "b58143", "d6b370", "f59797",
        "ecdcbf", "c93305", "e8e1e1", "b6e3f4", "bf55b5", "62c1da", "b4da5f",
    ]

    static let skinColors = [
        "614335", "ae5d29", "d08b5b", "edb98a", "ffdbb4", "fd9841", "f8d25c",
        "b6e3f4", "9f6ff4", "3cf487", "eaf4d2",
    ]

    static let clothesColors = [
        "262e33", "65c9ff", "5199e4", "ff5c5c", "a7ffc4", "ffffb1", "fe61de",
        "bafe19", "feb550", "9583f5", "fe538e", "ffffff",
    ]

    static func starter(for sex: Sex) -> AvatarTraits {
        AvatarTraits(top: sex == .male ? "shortFlat" : "longButNotTooLong",
                     hairColor: "2c1b18",
                     skinColor: "edb98a",
                     clothes: "hoodie",
                     clothesColor: "ff5c5c",
                     accessory: nil,
                     facialHair: nil)
    }

    /// Live preview through the DiceBear 10.x API.
    var previewURL: URL? {
        var components = URLComponents(string: "https://api.dicebear.com/10.x/avataaars/png")
        var items = [
            URLQueryItem(name: "seed", value: "zwaeg"),
            URLQueryItem(name: "size", value: "256"),
            URLQueryItem(name: "backgroundColor", value: "F3ECE7"),
            URLQueryItem(name: "topVariant", value: top),
            URLQueryItem(name: "hairColor", value: hairColor),
            URLQueryItem(name: "skinColor", value: skinColor),
            URLQueryItem(name: "clothesVariant", value: clothes),
            URLQueryItem(name: "clothesColor", value: clothesColor),
            URLQueryItem(name: "eyesVariant", value: "default"),
            URLQueryItem(name: "mouthVariant", value: "smile"),
            URLQueryItem(name: "eyebrowsVariant", value: "default"),
        ]
        if let accessory {
            items.append(URLQueryItem(name: "accessoriesVariant", value: accessory))
            items.append(URLQueryItem(name: "accessoriesProbability", value: "100"))
            items.append(URLQueryItem(name: "accessoriesColor", value: "262e33"))
        } else {
            items.append(URLQueryItem(name: "accessoriesProbability", value: "0"))
        }
        if let facialHair {
            items.append(URLQueryItem(name: "facialHairVariant", value: facialHair))
            items.append(URLQueryItem(name: "facialHairProbability", value: "100"))
            items.append(URLQueryItem(name: "facialHairColor", value: hairColor))
        } else {
            items.append(URLQueryItem(name: "facialHairProbability", value: "0"))
        }
        components?.queryItems = items
        return components?.url
    }
}

extension Color {
    /// Hex string like "ff5c5c" to Color.
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
