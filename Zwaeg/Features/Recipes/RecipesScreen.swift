import SwiftUI

/// Recipe collection: healthy Swiss classics with illustrated gradient cards,
/// filterable by category, each loggable straight into the diary.
struct RecipesScreen: View {
    let profile: UserProfile

    @State private var filter: Recipe.Category?
    @State private var path: [Recipe] = []

    private var recipes: [Recipe] {
        guard let filter else { return RecipeStore.all }
        return RecipeStore.all.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Gesunde Schweizer Küche".loc)
                        .font(.fredoka(15))
                        .foregroundStyle(.secondary)
                    categoryChips
                    LazyVStack(spacing: 14) {
                        ForEach(recipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Rezepte".loc)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .onAppear {
                if let flagIndex = CommandLine.arguments.firstIndex(of: "-open-recipe") {
                    let id = CommandLine.arguments.indices.contains(flagIndex + 1)
                        ? CommandLine.arguments[flagIndex + 1] : ""
                    if let recipe = RecipeStore.all.first(where: { $0.id == id }) ?? RecipeStore.all.first {
                        path = [recipe]
                    }
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "Alle".loc)
                ForEach(Recipe.Category.allCases) { category in
                    chip(category, label: category.label)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ category: Recipe.Category?, label: String) -> some View {
        let selected = filter == category
        return Button {
            withAnimation(.snappy(duration: 0.2)) { filter = category }
        } label: {
            Text(label)
                .font(.fredoka(14, .medium))
                .foregroundStyle(selected ? Theme.onAccent : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? AnyShapeStyle(Theme.accent.gradient)
                                     : AnyShapeStyle(Theme.card),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Illustrated recipe card: gradient hero band with symbol, name and meta below.
struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeHero(recipe: recipe, height: 108, symbolSize: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    Label("\(recipe.minutes) \("Min".loc)", systemImage: "clock")
                    Label(recipe.category.label, systemImage: "tag")
                    if recipe.vegetarian {
                        Label("Vegetarisch".loc, systemImage: "leaf")
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.tertiary)
                }
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
            .padding(14)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.shadow.opacity(0.06), radius: 10, y: 4)
    }
}

/// Gradient band with the recipe symbol and a kcal chip; stands in for photos.
struct RecipeHero: View {
    let recipe: Recipe
    var height: CGFloat
    var symbolSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: recipe.category.gradient,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: height * 1.3)
                .offset(x: -height * 0.9, y: height * 0.35)
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: height * 0.9)
                .offset(x: height * 1.1, y: -height * 0.4)
            Image(systemName: recipe.symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .overlay(alignment: .topTrailing) {
            Text("\(recipe.kcal.formatted(.number.locale(Lingo.shared.language.locale))) kcal")
                .font(.fredoka(12, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(10)
        }
    }
}

extension Recipe.Category {
    /// Fixed playful gradients, independent of the accent so the shelf stays colorful.
    var gradient: [Color] {
        switch self {
        case .breakfast: return [Color(hex: "F5B84B"), Color(hex: "EE8A3C")]
        case .main: return [Color(hex: "5FB87A"), Color(hex: "3D9268")]
        case .soup: return [Color(hex: "F08160"), Color(hex: "D95B45")]
        case .sweet: return [Color(hex: "E88BB4"), Color(hex: "C95E92")]
        }
    }
}
