import SwiftUI
import Translation

/// A recipe's content in the app language, translated on this device by
/// Apple's Translation framework and cached per language. 890 recipes times
/// 22 languages can't ship as data; on-device translation can.
struct TranslatedRecipe: Codable {
    var name: String
    var ingredients: [String]
    var steps: [String]
}

enum RecipeTranslationStore {
    private static func fileURL(language: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("recipe-translations-\(language).json")
    }

    static func load(language: String) -> [String: TranslatedRecipe] {
        guard let url = fileURL(language: language),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: TranslatedRecipe].self, from: data)
        else { return [:] }
        return table
    }

    static func save(_ translation: TranslatedRecipe, id: String, language: String) {
        guard let url = fileURL(language: language) else { return }
        var table = load(language: language)
        table[id] = translation
        if let data = try? JSONEncoder().encode(table) {
            try? data.write(to: url)
        }
    }
}

/// Button row on the recipe page: offers on-device translation into the app
/// language, remembers the result, and toggles between translation and
/// original. Hidden for German-reading languages; an honest note appears
/// where Apple's translation doesn't support the language or the device
/// runs iOS 17.
struct RecipeTranslateBar: View {
    let recipe: Recipe
    let onDisplay: (TranslatedRecipe?) -> Void

    private var wantsTranslation: Bool {
        !["de", "gsw", "rm"].contains(Lingo.shared.language.rawValue)
    }

    var body: some View {
        if wantsTranslation {
            if #available(iOS 18.0, *) {
                TranslateBarCore(recipe: recipe, onDisplay: onDisplay)
            } else {
                unsupportedNote
            }
        }
    }
}

/// Shared note for every "can't translate here" case.
private var unsupportedNote: some View {
    Text("Rezepte sind aktuell auf Deutsch.".loc)
        .font(.fredoka(12))
        .foregroundStyle(.tertiary)
}

@available(iOS 18.0, *)
private struct TranslateBarCore: View {
    let recipe: Recipe
    let onDisplay: (TranslatedRecipe?) -> Void

    @State private var supported = true
    @State private var translation: TranslatedRecipe?
    @State private var showingTranslation = false
    @State private var isTranslating = false
    @State private var configuration: TranslationSession.Configuration?

    private var language: String { Lingo.shared.language.rawValue }

    var body: some View {
        Group {
            if !supported {
                unsupportedNote
            } else if isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Wird übersetzt …".loc)
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
            } else if translation != nil {
                Button {
                    showingTranslation.toggle()
                    onDisplay(showingTranslation ? translation : nil)
                } label: {
                    Label(showingTranslation ? "Original anzeigen".loc : "Übersetzung anzeigen".loc,
                          systemImage: "translate")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: "de"),
                        target: Locale.Language(identifier: language))
                } label: {
                    Label("Auf %@ übersetzen".loc(Lingo.shared.language.label),
                          systemImage: "translate")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            if let cached = RecipeTranslationStore.load(language: language)[recipe.id] {
                translation = cached
                showingTranslation = true
                onDisplay(cached)
                return
            }
            let status = try? await LanguageAvailability().status(
                from: Locale.Language(identifier: "de"),
                to: Locale.Language(identifier: language))
            supported = status != .unsupported && status != nil
        }
        .translationTask(configuration) { session in
            isTranslating = true
            defer { isTranslating = false }
            let texts = [recipe.name] + recipe.ingredients + recipe.steps
            let requests = texts.enumerated().map {
                TranslationSession.Request(sourceText: $0.element,
                                           clientIdentifier: "\($0.offset)")
            }
            guard let responses = try? await session.translations(from: requests) else { return }
            var byIndex: [Int: String] = [:]
            for response in responses {
                if let id = response.clientIdentifier, let index = Int(id) {
                    byIndex[index] = response.targetText
                }
            }
            func text(_ index: Int, fallback: String) -> String {
                byIndex[index] ?? fallback
            }
            let result = TranslatedRecipe(
                name: text(0, fallback: recipe.name),
                ingredients: recipe.ingredients.enumerated().map {
                    text($0.offset + 1, fallback: $0.element)
                },
                steps: recipe.steps.enumerated().map {
                    text($0.offset + 1 + recipe.ingredients.count, fallback: $0.element)
                })
            RecipeTranslationStore.save(result, id: recipe.id, language: language)
            translation = result
            showingTranslation = true
            onDisplay(result)
        }
    }
}
