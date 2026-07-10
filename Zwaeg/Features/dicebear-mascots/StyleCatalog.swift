import Foundation

/// Generated from the DiceBear 9.x style schemas (see scripts in the session log).
/// Request params use the 10.x naming: enum options as <param>Variant.
struct StyleOption: Identifiable {
    let param: String
    let title: String
    let values: [String]
    let optional: Bool
    var id: String { param }
}

struct StyleColorOption: Identifiable {
    let param: String
    let title: String
    let presets: [String]
    var id: String { param }
}

struct AvatarStyle: Identifiable {
    let id: String
    let name: String
    let credit: String
    let options: [StyleOption]
    let colors: [StyleColorOption]
}

enum StyleCatalog {
    static let styles: [AvatarStyle] = [
        AvatarStyle(id: "notionists", name: "Notion", credit: "Zoish · CC0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["hat", "variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25", "variant26", "variant27", "variant28", "variant29", "variant30", "variant31", "variant32", "variant33", "variant34", "variant35", "variant36", "variant37", "variant38", "variant39", "variant40", "variant41", "variant42", "variant43", "variant44", "variant45", "variant46", "variant47", "variant48", "variant49", "variant50", "variant51", "variant52", "variant53", "variant54", "variant55", "variant56", "variant57", "variant58", "variant59", "variant60", "variant61", "variant62", "variant63"], optional: false),
            StyleOption(param: "body", title: "Körper".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25"], optional: false),
            StyleOption(param: "brows", title: "Brauen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13"], optional: false),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05"], optional: false),
            StyleOption(param: "lips", title: "Lippen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25", "variant26", "variant27", "variant28", "variant29", "variant30"], optional: false),
            StyleOption(param: "nose", title: "Nase".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20"], optional: false),
            StyleOption(param: "glasses", title: "Brille".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11"], optional: true),
            StyleOption(param: "beard", title: "Bart".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12"], optional: true),
            StyleOption(param: "gesture", title: "Geste".loc, values: ["hand", "handPhone", "ok", "okLongArm", "point", "pointLongArm", "waveLongArm", "waveLongArms", "waveOkLongArms", "wavePointLongArms"], optional: true),
        ], colors: [
        ]),
        AvatarStyle(id: "adventurer", name: "Abenteuer", credit: "Lisa Wischofsky · CC BY 4.0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["long01", "long02", "long03", "long04", "long05", "long06", "long07", "long08", "long09", "long10", "long11", "long12", "long13", "long14", "long15", "long16", "long17", "long18", "long19", "long20", "long21", "long22", "long23", "long24", "long25", "long26", "short01", "short02", "short03", "short04", "short05", "short06", "short07", "short08", "short09", "short10", "short11", "short12", "short13", "short14", "short15", "short16", "short17", "short18", "short19"], optional: true),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25", "variant26"], optional: false),
            StyleOption(param: "eyebrows", title: "Brauen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25", "variant26", "variant27", "variant28", "variant29", "variant30"], optional: false),
            StyleOption(param: "glasses", title: "Brille".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05"], optional: true),
            StyleOption(param: "earrings", title: "Ohrringe".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06"], optional: true),
            StyleOption(param: "features", title: "Extras".loc, values: ["birthmark", "blush", "freckles", "mustache"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["f2d3b1", "ecad80", "9e5622", "763900"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["ac6511", "cb6820", "ab2a18", "e5d7a3", "b9a05f", "796a45", "6a4e35", "562306", "0e0e0e", "afafaf", "3eac2c", "85c2c6", "dba3be", "592454"]),
        ]),
        AvatarStyle(id: "big-smile", name: "Happy", credit: "Ashley Seo · CC BY 4.0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["bangs", "bowlCutHair", "braids", "bunHair", "curlyBob", "curlyShortHair", "froBun", "halfShavedHead", "mohawk", "shavedHead", "shortHair", "straightHair", "wavyBob"], optional: false),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["angry", "cheery", "confused", "normal", "sad", "sleepy", "starstruck", "winking"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["awkwardSmile", "braces", "gapSmile", "kawaii", "openSad", "openedSmile", "teethSmile", "unimpressed"], optional: false),
            StyleOption(param: "accessories", title: "Extras".loc, values: ["catEars", "clownNose", "faceMask", "glasses", "mustache", "sailormoonCrown", "sleepMask", "sunglasses"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["ffe4c0", "f5d7b1", "efcc9f", "e2ba87", "c99c62", "a47539", "8c5a2b", "643d19"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["220f00", "3a1a00", "71472d", "e2ba87", "605de4", "238d80", "d56c0c", "e9b729"]),
        ]),
        AvatarStyle(id: "lorelei", name: "Lorelei", credit: "Lisa Wischofsky · CC0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24", "variant25", "variant26", "variant27", "variant28", "variant29", "variant30", "variant31", "variant32", "variant33", "variant34", "variant35", "variant36", "variant37", "variant38", "variant39", "variant40", "variant41", "variant42", "variant43", "variant44", "variant45", "variant46", "variant47", "variant48"], optional: false),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23", "variant24"], optional: false),
            StyleOption(param: "eyebrows", title: "Brauen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["happy01", "happy02", "happy03", "happy04", "happy05", "happy06", "happy07", "happy08", "happy09", "happy10", "happy11", "happy12", "happy13", "happy14", "happy15", "happy16", "happy17", "happy18", "sad01", "sad02", "sad03", "sad04", "sad05", "sad06", "sad07", "sad08", "sad09"], optional: false),
            StyleOption(param: "nose", title: "Nase".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06"], optional: false),
            StyleOption(param: "glasses", title: "Brille".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05"], optional: true),
            StyleOption(param: "beard", title: "Bart".loc, values: ["variant01", "variant02"], optional: true),
            StyleOption(param: "earrings", title: "Ohrringe".loc, values: ["variant01", "variant02", "variant03"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["ffffff"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["000000"]),
        ]),
        AvatarStyle(id: "open-peeps", name: "Peeps", credit: "Pablo Stanley · CC0", options: [
            StyleOption(param: "head", title: "Frisur".loc, values: ["afro", "bangs", "bangs2", "bantuKnots", "bear", "bun", "bun2", "buns", "cornrows", "cornrows2", "dreads1", "dreads2", "flatTop", "flatTopLong", "grayBun", "grayMedium", "grayShort", "hatBeanie", "hatHip", "hijab", "long", "longAfro", "longBangs", "longCurly", "medium1", "medium2", "medium3", "mediumBangs", "mediumBangs2", "mediumBangs3", "mediumStraight", "mohawk", "mohawk2", "noHair1", "noHair2", "noHair3", "pomp", "shaved1", "shaved2", "shaved3", "short1", "short2", "short3", "short4", "short5", "turban", "twists", "twists2"], optional: false),
            StyleOption(param: "face", title: "Gesicht".loc, values: ["angryWithFang", "awe", "blank", "calm", "cheeky", "concerned", "concernedFear", "contempt", "cute", "cyclops", "driven", "eatingHappy", "explaining", "eyesClosed", "fear", "hectic", "lovingGrin1", "lovingGrin2", "monster", "old", "rage", "serious", "smile", "smileBig", "smileLOL", "smileTeethGap", "solemn", "suspicious", "tired", "veryAngry"], optional: false),
            StyleOption(param: "facialHair", title: "Bart".loc, values: ["chin", "full", "full2", "full3", "full4", "goatee1", "goatee2", "moustache1", "moustache2", "moustache3", "moustache4", "moustache5", "moustache6", "moustache7", "moustache8", "moustache9"], optional: true),
            StyleOption(param: "accessories", title: "Extras".loc, values: ["eyepatch", "glasses", "glasses2", "glasses3", "glasses4", "glasses5", "sunglasses", "sunglasses2"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["ffdbb4", "edb98a", "d08b5b", "ae5d29", "694d3d"]),
            StyleColorOption(param: "headContrastColor", title: "Haarfarbe".loc, presets: ["2c1b18", "e8e1e1", "ecdcbf", "d6b370", "f59797", "b58143", "a55728", "724133", "4a312c", "c93305"]),
            StyleColorOption(param: "clothingColor", title: "Outfit-Farbe".loc, presets: ["e78276", "ffcf77", "fdea6b", "78e185", "9ddadb", "8fa7df", "e279c7"]),
        ]),
        AvatarStyle(id: "personas", name: "Persona", credit: "Draftbit · CC BY 4.0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["bald", "balding", "beanie", "bobBangs", "bobCut", "bunUndercut", "buzzcut", "cap", "curly", "curlyBun", "curlyHighTop", "extraLong", "fade", "long", "mohawk", "pigtails", "shortCombover", "shortComboverChops", "sideShave", "straightBun"], optional: false),
            StyleOption(param: "body", title: "Outfit".loc, values: ["checkered", "rounded", "small", "squared"], optional: false),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["glasses", "happy", "open", "sleep", "sunglasses", "wink"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["bigSmile", "frown", "lips", "pacifier", "smile", "smirk", "surprise"], optional: false),
            StyleOption(param: "nose", title: "Nase".loc, values: ["mediumRound", "smallRound", "wrinkles"], optional: false),
            StyleOption(param: "facialHair", title: "Bart".loc, values: ["beardMustache", "goatee", "pyramid", "shadow", "soulPatch", "walrus"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["eeb4a4", "e7a391", "e5a07e", "d78774", "b16a5b", "92594b", "623d36"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["362c47", "6c4545", "e15c66", "e16381", "f27d65", "f29c65", "dee1f5"]),
            StyleColorOption(param: "clothingColor", title: "Outfit-Farbe".loc, presets: ["456dff", "54d7c7", "7555ca", "6dbb58", "e24553", "f3b63a", "f55d81"]),
        ]),
        AvatarStyle(id: "pixel-art", name: "Pixel", credit: "DiceBear · CC0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["long01", "long02", "long03", "long04", "long05", "long06", "long07", "long08", "long09", "long10", "long11", "long12", "long13", "long14", "long15", "long16", "long17", "long18", "long19", "long20", "long21", "short01", "short02", "short03", "short04", "short05", "short06", "short07", "short08", "short09", "short10", "short11", "short12", "short13", "short14", "short15", "short16", "short17", "short18", "short19", "short20", "short21", "short22", "short23", "short24"], optional: false),
            StyleOption(param: "clothing", title: "Outfit".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12", "variant13", "variant14", "variant15", "variant16", "variant17", "variant18", "variant19", "variant20", "variant21", "variant22", "variant23"], optional: false),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10", "variant11", "variant12"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["happy01", "happy02", "happy03", "happy04", "happy05", "happy06", "happy07", "happy08", "happy09", "happy10", "happy11", "happy12", "happy13", "sad01", "sad02", "sad03", "sad04", "sad05", "sad06", "sad07", "sad08", "sad09", "sad10"], optional: false),
            StyleOption(param: "glasses", title: "Brille".loc, values: ["dark01", "dark02", "dark03", "dark04", "dark05", "dark06", "dark07", "light01", "light02", "light03", "light04", "light05", "light06", "light07"], optional: true),
            StyleOption(param: "hat", title: "Hut".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08", "variant09", "variant10"], optional: true),
            StyleOption(param: "beard", title: "Bart".loc, values: ["variant01", "variant02", "variant03", "variant04", "variant05", "variant06", "variant07", "variant08"], optional: true),
        ], colors: [
            StyleColorOption(param: "skinColor", title: "Hautfarbe".loc, presets: ["ffdbac", "f5cfa0", "eac393", "e0b687", "cb9e6e", "b68655", "a26d3d", "8d5524"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["cab188", "603a14", "83623b", "a78961", "611c17", "603015", "612616", "28150a", "009bbd", "bd1700", "91cb15"]),
            StyleColorOption(param: "clothingColor", title: "Outfit-Farbe".loc, presets: ["5bc0de", "428bca", "03396c", "88d8b0", "44c585", "00b159", "ff6f69", "d11141", "ae0001", "ffeead", "ffd969", "ffc425"]),
            StyleColorOption(param: "hatColor", title: "Hut".loc, presets: ["2e1e05", "2663a3", "989789", "3d8a6b", "cc6192", "614f8a", "a62116"]),
        ]),
        AvatarStyle(id: "fun-emoji", name: "Emoji", credit: "Davis Uche · CC BY 4.0", options: [
            StyleOption(param: "eyes", title: "Augen".loc, values: ["closed", "closed2", "crying", "cute", "glasses", "love", "pissed", "plain", "sad", "shades", "sleepClose", "stars", "tearDrop", "wink", "wink2"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["cute", "drip", "faceMask", "kissHeart", "lilSmile", "pissed", "plain", "sad", "shout", "shy", "sick", "smileLol", "smileTeeth", "tongueOut", "wideSmile"], optional: false),
        ], colors: [
        ]),
        AvatarStyle(id: "micah", name: "Micah", credit: "Micah Lanier · CC BY 4.0", options: [
            StyleOption(param: "hair", title: "Frisur".loc, values: ["dannyPhantom", "dougFunny", "fonze", "full", "mrClean", "mrT", "pixie", "turban"], optional: true),
            StyleOption(param: "eyes", title: "Augen".loc, values: ["eyes", "eyesShadow", "round", "smiling", "smilingShadow"], optional: false),
            StyleOption(param: "eyebrows", title: "Brauen".loc, values: ["down", "eyelashesDown", "eyelashesUp", "up"], optional: false),
            StyleOption(param: "mouth", title: "Mund".loc, values: ["frown", "laughing", "nervous", "pucker", "sad", "smile", "smirk", "surprised"], optional: false),
            StyleOption(param: "nose", title: "Nase".loc, values: ["curve", "pointed", "tound"], optional: false),
            StyleOption(param: "glasses", title: "Brille".loc, values: ["round", "square"], optional: true),
            StyleOption(param: "earrings", title: "Ohrringe".loc, values: ["hoop", "stud"], optional: true),
            StyleOption(param: "facialHair", title: "Bart".loc, values: ["beard", "scruff"], optional: true),
            StyleOption(param: "shirt", title: "Outfit".loc, values: ["collared", "crew", "open"], optional: false),
        ], colors: [
            StyleColorOption(param: "baseColor", title: "Hautfarbe".loc, presets: ["f9c9b6", "ac6651", "77311d"]),
            StyleColorOption(param: "hairColor", title: "Haarfarbe".loc, presets: ["f9c9b6", "d2eff3", "000000", "e0ddff", "f4d150", "ac6651", "9287ff", "ffeba4", "fc909f", "ffedef", "6bd9e9", "77311d", "ffffff"]),
            StyleColorOption(param: "shirtColor", title: "Outfit-Farbe".loc, presets: ["f9c9b6", "d2eff3", "000000", "e0ddff", "f4d150", "ac6651", "9287ff", "ffeba4", "fc909f", "ffedef", "6bd9e9", "77311d", "ffffff"]),
        ]),
    ]

    static func style(_ id: String) -> AvatarStyle? {
        styles.first { $0.id == id }
    }
}

/// Chosen parts for any catalog style; missing optional params mean "none".
struct StyledTraits: Codable, Equatable, Hashable {
    var style: String
    var variants: [String: String]
    var colors: [String: String]

    static func starter(for style: AvatarStyle) -> StyledTraits {
        var variants: [String: String] = [:]
        for option in style.options where !option.optional {
            variants[option.param] = option.values.first
        }
        var colors: [String: String] = [:]
        for color in style.colors {
            colors[color.param] = color.presets.first
        }
        return StyledTraits(style: style.id, variants: variants, colors: colors)
    }

    /// Live preview through the DiceBear 10.x API.
    var previewURL: URL? {
        guard let spec = StyleCatalog.style(style) else { return nil }
        var components = URLComponents(string: "https://api.dicebear.com/10.x/\(style)/png")
        var items = [
            URLQueryItem(name: "seed", value: "zwaeg"),
            URLQueryItem(name: "size", value: "256"),
            URLQueryItem(name: "backgroundColor", value: "F3ECE7"),
        ]
        for option in spec.options {
            if let value = variants[option.param] {
                items.append(URLQueryItem(name: "\(option.param)Variant", value: value))
                if option.optional {
                    items.append(URLQueryItem(name: "\(option.param)Probability", value: "100"))
                }
            } else if option.optional {
                items.append(URLQueryItem(name: "\(option.param)Probability", value: "0"))
            }
        }
        for color in spec.colors {
            if let hex = colors[color.param] {
                items.append(URLQueryItem(name: color.param, value: hex))
            }
        }
        components?.queryItems = items
        return components?.url
    }
}

/// Human-readable, localized labels for raw DiceBear option values like
/// "wavePointLongArms" or "short07".
enum StyleValueNames {
    private static let numberedPrefixes: [(String, String)] = [
        ("variant", ""), ("short", "Kurz"), ("long", "Lang"), ("happy", "Froh"),
        ("sad", "Traurig"), ("light", "Hell"), ("dark", "Dunkel"),
    ]

    /// Whole-value overrides where word-by-word translation reads badly.
    private static let phrases: [String: String] = [
        "hand": "Hand", "handPhone": "Handy", "ok": "OK", "okLongArm": "OK",
        "point": "Zeigen", "pointLongArm": "Zeigen", "waveLongArm": "Winken",
        "waveLongArms": "Winken", "waveOkLongArms": "Winken & OK",
        "wavePointLongArms": "Winken & Zeigen", "mrT": "Irokese", "mrClean": "Glatze",
        "fonze": "Tolle", "dougFunny": "Wuschel", "dannyPhantom": "Scheitel",
        "sailormoonCrown": "Krone", "angryWithFang": "Wütend", "eatingHappy": "Genüsslich",
        "lovingGrin1": "Verliebt 1", "lovingGrin2": "Verliebt 2", "soulPatch": "Soul Patch",
        "tound": "Rund", "noHair": "Glatze",
    ]

    /// Word tokens with German labels; empty string drops filler words.
    /// Unknown tokens (Afro, Mohawk, Hijab, ...) stay as loanwords.
    private static let words: [String: String] = [
        "hair": "", "head": "", "with": "", "out": "", "very": "sehr",
        "angry": "Wütend", "arm": "", "arms": "", "awe": "Staunend", "awkward": "Verlegen",
        "bald": "Glatze", "balding": "Halbglatze", "bangs": "Pony", "bantu": "Bantu",
        "beanie": "Beanie", "bear": "Bär", "beard": "Bart", "big": "Gross",
        "birthmark": "Muttermal", "blank": "Neutral", "blush": "Rouge", "bowl": "Topf",
        "braces": "Zahnspange", "braids": "Zöpfe", "bun": "Dutt", "buns": "Duttli",
        "buzzcut": "Buzzcut", "calm": "Ruhig", "cap": "Cap", "cat": "Katzen",
        "checkered": "Kariert", "cheeky": "Frech", "cheery": "Fröhlich", "chin": "Kinn",
        "chops": "Koteletten", "clean": "Sauber", "close": "Zu", "closed": "Geschlossen",
        "clown": "Clown", "collared": "Kragen", "combover": "Seitenscheitel",
        "concerned": "Besorgt", "confused": "Verwirrt", "contempt": "Skeptisch",
        "cornrows": "Cornrows", "crew": "Rundhals", "crown": "Krone", "crying": "Weinend",
        "curly": "Locken", "curve": "Geschwungen", "cut": "", "cute": "Süss",
        "cyclops": "Zyklop", "down": "Unten", "dreads": "Dreads", "drip": "Sabber",
        "driven": "Motiviert", "drop": "Träne", "ears": "Ohren", "eating": "Essend",
        "explaining": "Erklärend", "extra": "Extra", "eyelashes": "Wimpern",
        "eyepatch": "Augenklappe", "eyes": "Augen", "face": "Gesicht", "fade": "Fade",
        "fang": "Zahn", "fear": "Ängstlich", "flat": "Flach", "freckles": "Sommersprossen",
        "fro": "Afro", "frown": "Runzeln", "full": "Voll", "gap": "Zahnlücke",
        "glasses": "Brille", "goatee": "Spitzbart", "gray": "Grau", "grin": "Grinsen",
        "half": "Halb", "hat": "Hut", "heart": "Herz", "hectic": "Hektisch",
        "high": "Hoch", "hijab": "Hijab", "hip": "Hip", "hoop": "Ring",
        "kiss": "Kuss", "knots": "Knoten", "laughing": "Lachend", "lil": "Klein",
        "lips": "Lippen", "lol": "LOL", "love": "Verliebt", "loving": "Verliebt",
        "mask": "Maske", "medium": "Mittel", "mohawk": "Irokese", "monster": "Monster",
        "moustache": "Schnauz", "mustache": "Schnauz", "nervous": "Nervös",
        "no": "Ohne", "normal": "Normal", "nose": "Nase", "old": "Alt",
        "open": "Offen", "opened": "Offen", "pacifier": "Nuggi", "patch": "",
        "phantom": "", "pigtails": "Zöpfe", "pissed": "Sauer", "pixie": "Pixie",
        "plain": "Schlicht", "pointed": "Spitz", "pomp": "Tolle", "pucker": "Kussmund",
        "pyramid": "Pyramide", "rage": "Wut", "round": "Rund", "rounded": "Rund",
        "scruff": "Stoppeln", "serious": "Ernst", "shades": "Sonnenbrille",
        "shadow": "Schatten", "shave": "Rasiert", "shaved": "Rasiert",
        "shout": "Schreiend", "shy": "Schüchtern", "sick": "Krank", "side": "Seitlich",
        "sleep": "Schlafend", "sleepy": "Schläfrig", "small": "Klein",
        "smile": "Lächeln", "smiling": "Lächelnd", "smirk": "Schmunzeln",
        "solemn": "Ernst", "soul": "Soul", "square": "Eckig", "squared": "Eckig",
        "stars": "Sterne", "starstruck": "Sterne", "straight": "Glatt", "stud": "Stecker",
        "sunglasses": "Sonnenbrille", "surprise": "Überrascht", "surprised": "Überrascht",
        "suspicious": "Skeptisch", "tear": "Träne", "teeth": "Zähne", "tired": "Müde",
        "tongue": "Zunge", "top": "Oben", "turban": "Turban", "twists": "Twists",
        "undercut": "Undercut", "unimpressed": "Unbeeindruckt", "up": "Oben",
        "walrus": "Walross", "wave": "Winken", "wavy": "Wellig", "wide": "Breit",
        "wink": "Zwinkern", "winking": "Zwinkernd", "wrinkles": "Falten",
    ]

    static func label(_ value: String) -> String {
        for (prefix, name) in numberedPrefixes where value.hasPrefix(prefix) {
            if let number = Int(value.dropFirst(prefix.count)) {
                return name.isEmpty ? "\(number)" : "\(name.loc) \(number)"
            }
        }
        if let phrase = phrases[value] {
            return phrase.loc
        }
        let tokens = split(value)
        let mapped = tokens.compactMap { token -> String? in
            if Int(token) != nil { return token }
            guard let german = words[token.lowercased()] else { return token.capitalized }
            return german.isEmpty ? nil : german.loc
        }
        return mapped.isEmpty ? value : mapped.joined(separator: " ")
    }

    private static func split(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for char in value {
            if char.isUppercase || (char.isNumber && !(current.last?.isNumber ?? false)) {
                if !current.isEmpty { tokens.append(current) }
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
