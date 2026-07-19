import SwiftUI

/// Full recipe page: edge-to-edge hero with floating actions, per-portion
/// macros, ingredients, steps and a bottom bar that replaces the tab bar
/// with shopping list and diary actions.
struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var servings: Int
    /// Content in the app language when the user asked for it; nil = German.
    @State private var translated: TranslatedRecipe?
    @State private var showPortionSheet = false
    @State private var addedToList = false
    @State private var favorites = RecipeFavorites.shared
    @Environment(\.dismiss) private var dismiss

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: recipe.servings)
    }

    /// Ingredient lines start with their quantity; scale it to the chosen
    /// servings and leave lines without a leading number untouched.
    private func scaledIngredient(_ ingredient: String) -> String {
        guard servings != recipe.servings,
              let match = ingredient.firstMatch(of: /^(\d+(?:\.\d+)?)/),
              let value = Double(match.1) else { return ingredient }
        let scaled = value * Double(servings) / Double(recipe.servings)
        let number = scaled.formatted(.number.precision(.fractionLength(0...2))
            .locale(Lingo.shared.language.locale))
        return number + ingredient[match.range.upperBound...]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RecipeHero(recipe: recipe, height: 340, emojiSize: 96, flat: true)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let credit = RecipeCredits.byId[recipe.id] {
                            Text(credit.license == "Pexels License"
                                 ? "Foto: \(credit.artist) · Pexels"
                                 : "Foto: \(credit.artist) · \(credit.license) · Wikimedia Commons")
                                .font(.fredoka(10))
                                .foregroundStyle(.tertiary)
                        }
                        Text(translated?.name ?? recipe.name)
                            .font(.fredoka(26, .semibold))
                        RecipeTranslateBar(recipe: recipe) { translated = $0 }
                        HStack(spacing: 14) {
                            Label("\(recipe.minutes) \("Min".loc)", systemImage: "clock")
                            Label("\(recipe.servings)", systemImage: "person.2")
                            if recipe.vegan {
                                Label("Vegan".loc, systemImage: "leaf.fill")
                            } else if recipe.vegetarian {
                                Label("Vegetarisch".loc, systemImage: "leaf")
                            }
                        }
                        .font(.fredoka(14))
                        .foregroundStyle(.secondary)
                    }

                    macroCard
                    ingredientsCard
                    stepsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            heroButtons
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showPortionSheet) {
            ProductPortionSheet(product: recipe.asProduct)
        }
        .onAppear {
            TabRouter.shared.tabBarHidden = true
        }
        .onDisappear {
            TabRouter.shared.tabBarHidden = false
        }
    }

    private var displayedIngredients: [String] {
        translated?.ingredients ?? recipe.ingredients
    }

    private var displayedSteps: [String] {
        translated?.steps ?? recipe.steps
    }

    // MARK: - Hero actions

    private var shareText: String {
        var lines = ["\(recipe.emoji) \(translated?.name ?? recipe.name)",
                     "\(recipe.kcal) kcal · \(recipe.minutes) \("Min".loc) · \(recipe.servings)x", "",
                     "\("Zutaten".loc):"]
        lines += displayedIngredients.map { "- \($0)" }
        lines += ["", "\("Zubereitung".loc):"]
        lines += displayedSteps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        lines += ["", "Zwäg 🧡"]
        return lines.joined(separator: "\n")
    }

    private var heroButtons: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                heroCircle("chevron.backward")
            }
            .buttonStyle(.plain)
            Spacer()
            ShareLink(item: shareText) {
                heroCircle("square.and.arrow.up")
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    favorites.toggle(recipe.id)
                }
            } label: {
                heroCircle(favorites.contains(recipe.id) ? "heart.fill" : "heart",
                           color: .appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func heroCircle(_ symbol: String, color: Color = .primary) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(.thinMaterial, in: Circle())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                ShoppingList.shared.add(displayedIngredients.map(scaledIngredient))
                withAnimation(.snappy(duration: 0.2)) {
                    addedToList = true
                }
            } label: {
                Label(addedToList ? "Einkaufsliste".loc : "Liste".loc,
                      systemImage: addedToList ? "checkmark" : "basket")
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(addedToList ? Color.appAccent : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.card, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showPortionSheet = true
            } label: {
                Label("Hinzufügen".loc, systemImage: "plus")
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.accent.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Theme.background.opacity(0.92))
    }

    // MARK: - Cards

    private var macroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pro Portion".loc)
                        .font(.fredoka(15, .semibold))
                    Spacer()
                    Text("\(recipe.kcal.formatted(.number.locale(Lingo.shared.language.locale))) kcal")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                HStack(spacing: 10) {
                    macroTile("Protein".loc, grams: recipe.proteinG)
                    macroTile("Kohlenhydrate".loc, grams: recipe.carbsG)
                    macroTile("Fett".loc, grams: recipe.fatG)
                }
            }
        }
    }

    private func macroTile(_ label: String, grams: Double) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(grams.rounded())) g")
                .font(.fredoka(17, .semibold))
            Text(label)
                .font(.fredoka(11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 14))
    }

    private var ingredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zutaten".loc)
                            .font(.fredoka(15, .semibold))
                        Text((servings == 1 ? "Für %d Portion" : "Für %d Portionen").loc(servings))
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    servingsButton("minus", enabled: servings > 1) { servings -= 1 }
                    servingsButton("plus", enabled: servings < 12) { servings += 1 }
                }
                ForEach(displayedIngredients, id: \.self) { ingredient in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 6, height: 6)
                            .offset(y: -2)
                        Text(scaledIngredient(ingredient))
                            .font(.fredoka(14))
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func servingsButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                action()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.onAccent : Color(.systemGray2))
                .frame(width: 32, height: 32)
                .background(enabled ? AnyShapeStyle(Theme.accent.gradient)
                                    : AnyShapeStyle(Theme.field),
                            in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var stepsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Zubereitung".loc)
                    .font(.fredoka(15, .semibold))
                ForEach(Array(displayedSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\((index + 1).formatted(.number.locale(Lingo.shared.language.locale)))")
                            .font(.fredoka(13, .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent.gradient, in: Circle())
                        Text(step)
                            .font(.fredoka(14))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
