import SwiftUI

/// Full recipe page: hero, per-portion macros, ingredients, steps
/// and a button that logs the recipe through the portion sheet.
struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var showPortionSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RecipeHero(recipe: recipe, height: 170, symbolSize: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(.fredoka(24, .semibold))
                    HStack(spacing: 14) {
                        Label("\(recipe.minutes) \("Min".loc)", systemImage: "clock")
                        Label("\(recipe.servings)", systemImage: "person.2")
                        if recipe.vegetarian {
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
            .padding(16)
            .padding(.bottom, 90)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .sheet(isPresented: $showPortionSheet) {
            ProductPortionSheet(product: recipe.asProduct)
        }
    }

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
                Text("Zutaten".loc)
                    .font(.fredoka(15, .semibold))
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 6, height: 6)
                            .offset(y: -2)
                        Text(ingredient)
                            .font(.fredoka(14))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stepsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Zubereitung".loc)
                    .font(.fredoka(15, .semibold))
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
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

    private var addButton: some View {
        Button {
            showPortionSheet = true
        } label: {
            Label("Hinzufügen".loc, systemImage: "plus")
                .font(.fredoka(17, .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        // Clears the floating tab bar, which the inner safe area does not know about.
        .padding(.bottom, 74)
    }
}
