import Foundation
import Observation

/// The app languages: the four Swiss ones plus the languages of the
/// biggest communities in Switzerland. iOS offers no system-level
/// Swiss German, so the switch lives in the app instead of iOS settings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case swissGerman = "gsw"
    case french = "fr"
    case italian = "it"
    case english = "en"
    case albanian = "sq"
    case serbian = "sr"
    case croatian = "hr"
    case portuguese = "pt"
    case spanish = "es"
    case turkish = "tr"
    case polish = "pl"
    case danish = "da"
    case norwegian = "nb"
    case swedish = "sv"
    case dutch = "nl"
    case romansh = "rm"
    case bosnian = "bs"
    case ukrainian = "uk"
    case tamil = "ta"
    case arabic = "ar"
    case farsi = "fa"
    case tigrinya = "ti"

    var id: String { rawValue }

    /// Right-to-left scripts flip the whole layout.
    var isRTL: Bool {
        self == .arabic || self == .farsi
    }

    /// Locale for date and number formatting; Swiss variants where they exist.
    var locale: Locale {
        switch self {
        case .german, .swissGerman: return Locale(identifier: "de_CH")
        case .french: return Locale(identifier: "fr_CH")
        case .italian: return Locale(identifier: "it_CH")
        case .romansh: return Locale(identifier: "rm_CH")
        case .english: return Locale(identifier: "en_CH")
        default: return Locale(identifier: rawValue)
        }
    }

    /// The national-language options shown in the picker's Swiss section.
    var isSwiss: Bool {
        switch self {
        case .german, .swissGerman, .french, .italian, .romansh: return true
        default: return false
        }
    }

    /// Native name, shown in the picker.
    var label: String {
        switch self {
        case .german: return "Deutsch"
        case .swissGerman: return "Schwiizerdütsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .english: return "English"
        case .albanian: return "Shqip"
        case .serbian: return "Srpski"
        case .croatian: return "Hrvatski"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        case .turkish: return "Türkçe"
        case .polish: return "Polski"
        case .danish: return "Dansk"
        case .norwegian: return "Norsk"
        case .swedish: return "Svenska"
        case .dutch: return "Nederlands"
        case .romansh: return "Rumantsch"
        case .bosnian: return "Bosanski"
        case .ukrainian: return "Українська"
        case .tamil: return "தமிழ்"
        case .arabic: return "العربية"
        case .farsi: return "فارسی"
        case .tigrinya: return "ትግርኛ"
        }
    }

    var detail: String {
        switch self {
        case .german: return "Standard"
        case .swissGerman: return "So wie me redt"
        case .french: return "Suisse romande"
        case .italian: return "Ticino"
        case .english: return "Englisch"
        case .albanian: return "Albanisch"
        case .serbian: return "Serbisch"
        case .croatian: return "Kroatisch"
        case .portuguese: return "Portugiesisch"
        case .spanish: return "Spanisch"
        case .turkish: return "Türkisch"
        case .polish: return "Polnisch"
        case .danish: return "Dänisch"
        case .norwegian: return "Norwegisch"
        case .swedish: return "Schwedisch"
        case .dutch: return "Niederländisch"
        case .romansh: return "Rumantsch Grischun"
        case .bosnian: return "Bosnisch"
        case .ukrainian: return "Ukrainisch"
        case .tamil: return "Tamilisch"
        case .arabic: return "Arabisch"
        case .farsi: return "Persisch"
        case .tigrinya: return "Tigrinya"
        }
    }
}

/// In-app localization: the German UI strings double as lookup keys via `.loc`,
/// tables live in bundled JSON files (Resources/Languages/<code>.json), and
/// missing entries fall back to German. Reading `language` inside a view body
/// registers observation, so switching re-renders every visible screen.
@Observable
final class Lingo {
    static let shared = Lingo()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private var cache: [AppLanguage: [String: String]] = [:]

    private static let storageKey = "appLanguage"

    private init() {
        // Debug: -lang <code> forces a language for simulator screenshots.
        if let flagIndex = LaunchArgs.all.firstIndex(of: "-lang"),
           LaunchArgs.all.indices.contains(flagIndex + 1),
           let forced = AppLanguage(rawValue: LaunchArgs.all[flagIndex + 1]) {
            language = forced
            return
        }
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        language = AppLanguage(rawValue: raw) ?? Self.deviceDefault()
    }

    /// Best supported match for the device language, German as fallback.
    private static func deviceDefault() -> AppLanguage {
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(while: { $0 != "-" }))
            if let match = AppLanguage(rawValue: code == "no" ? "nb" : code) {
                return match
            }
        }
        return .german
    }

    func localized(_ german: String) -> String {
        guard language != .german else { return german }
        return table(for: language)[german] ?? german
    }

    private func table(for language: AppLanguage) -> [String: String] {
        if let cached = cache[language] {
            return cached
        }
        var table: [String: String] = [:]
        if let url = Bundle.main.url(forResource: language.rawValue, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            table = decoded
        }
        cache[language] = table
        return table
    }
}

extension String {
    /// The receiver (a German UI string) translated into the app language.
    var loc: String { Lingo.shared.localized(self) }

    /// Format-string variant; the German key carries the format specifiers.
    func loc(_ args: CVarArg...) -> String {
        String(format: Lingo.shared.localized(self), arguments: args)
    }
}
