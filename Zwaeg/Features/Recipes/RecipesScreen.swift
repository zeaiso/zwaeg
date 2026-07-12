import SwiftUI

enum RecipeRoute: Hashable {
    case detail(Recipe)
    case list(String, [Recipe])
}

/// Renders an emoji, or an SF Symbol on runtimes without the emoji font.
struct EmojiOrSymbol: View {
    let emoji: String
    let symbol: String
    var size: CGFloat
    var symbolColor: Color = .appAccent

    var body: some View {
        if EmojiSupport.available {
            Text(emoji).font(.system(size: size))
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.72, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(height: size * 1.2)
        }
    }
}

/// Recipe discovery: search, favorites, emoji category tiles, calorie ranges,
/// diet filters and the Swiss classics shelf. Every recipe logs into the diary.
struct RecipesScreen: View {
    let profile: UserProfile

    @State private var path: [RecipeRoute] = []
    @State private var query = ""
    @State private var favorites = RecipeFavorites.shared
    @State private var showShoppingList = false
    @State private var shoppingList = ShoppingList.shared

    private var searchResults: [Recipe] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        return RecipeStore.all.filter { $0.name.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    searchField
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        discoverSections
                    } else {
                        searchList
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Rezepte".loc)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShoppingList = true
                    } label: {
                        Image(systemName: "basket")
                            .overlay(alignment: .topTrailing) {
                                let open = shoppingList.items.filter { !$0.done }.count
                                if open > 0 {
                                    Text("\(min(open, 99))")
                                        .font(.fredoka(9, .semibold))
                                        .foregroundStyle(Theme.onAccent)
                                        .padding(3)
                                        .background(Theme.accent, in: Circle())
                                        .offset(x: 9, y: -7)
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showShoppingList) {
                ShoppingListView()
                    .presentationDetents([.medium, .large])
            }
            .navigationDestination(for: RecipeRoute.self) { route in
                switch route {
                case .detail(let recipe): RecipeDetailView(recipe: recipe)
                case .list(let title, let recipes): RecipeListView(title: title, recipes: recipes)
                }
            }
            .onAppear {
                if LaunchArgs.all.contains("-open-shopping-list") {
                    if ShoppingList.shared.items.isEmpty, let recipe = RecipeStore.all.first {
                        ShoppingList.shared.add(recipe.ingredients)
                    }
                    showShoppingList = true
                }
                if let flagIndex = LaunchArgs.all.firstIndex(of: "-open-recipe") {
                    let id = LaunchArgs.all.indices.contains(flagIndex + 1)
                        ? LaunchArgs.all[flagIndex + 1] : ""
                    if let recipe = RecipeStore.all.first(where: { $0.id == id }) ?? RecipeStore.all.first {
                        path = [.detail(recipe)]
                    }
                }
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Wonach hast du Lust?".loc, text: $query)
                .font(.fredoka(16))
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var searchList: some View {
        LazyVStack(spacing: 14) {
            if searchResults.isEmpty {
                VStack(spacing: 8) {
                    EmojiOrSymbol(emoji: "🔍", symbol: "magnifyingglass", size: 40)
                    Text("Keine Rezepte gefunden".loc)
                        .font(.fredoka(15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            ForEach(searchResults) { recipe in
                NavigationLink(value: RecipeRoute.detail(recipe)) {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Discover

    @ViewBuilder
    private var discoverSections: some View {
        let favoriteRecipes = RecipeStore.all.filter { favorites.contains($0.id) }
        if !favoriteRecipes.isEmpty {
            section("Favoriten".loc) {
                recipeShelf(favoriteRecipes)
            }
        }
        section("Beliebte Kategorien".loc) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Recipe.Category.allCases) { category in
                        let recipes = RecipeStore.all.filter { $0.category == category }
                        emojiTile(category.emoji, symbol: category.symbol, label: category.label,
                                  route: .list(category.label, recipes))
                    }
                }
            }
            .scrollClipDisabled()
        }
        section("Nach Küche".loc) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Recipe.Cuisine.allCases) { cuisine in
                        let recipes = RecipeStore.all.filter { $0.cuisine == cuisine }
                        if !recipes.isEmpty {
                            emojiTile(cuisine.emoji, symbol: cuisine.symbol, label: cuisine.label,
                                      route: .list(cuisine.label, recipes))
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        section("Nach Kalorien".loc) {
            tileShelf(kcalRanges.map { range in
                (range.emoji, range.symbol, range.label,
                 RecipeRoute.list(range.label, RecipeStore.all.filter(range.matches)))
            })
        }
        section("Nach Ernährung".loc) {
            tileShelf(diets.map { diet in
                (diet.emoji, diet.symbol, diet.label,
                 RecipeRoute.list(diet.label, RecipeStore.all.filter(diet.matches)))
            })
        }
        section("Schweizer Klassiker".loc) {
            recipeShelf(RecipeStore.all.filter(\.swiss))
        }
        NavigationLink(value: RecipeRoute.list("Rezepte".loc, RecipeStore.all)) {
            HStack {
                Text("Alle %d Rezepte".loc(RecipeStore.all.count))
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.fredoka(18, .semibold))
            content()
        }
    }

    private func recipeShelf(_ recipes: [Recipe]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: RecipeRoute.detail(recipe)) {
                        CompactRecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func emojiTile(_ emoji: String, symbol: String, label: String, route: RecipeRoute) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 8) {
                EmojiOrSymbol(emoji: emoji, symbol: symbol, size: 34)
                Text(label)
                    .font(.fredoka(13, .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 96)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func tileShelf(_ tiles: [(emoji: String, symbol: String, label: String, route: RecipeRoute)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tiles, id: \.label) { tile in
                    emojiTile(tile.emoji, symbol: tile.symbol, label: tile.label, route: tile.route)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Filters

    private var kcalRanges: [(emoji: String, symbol: String, label: String, matches: (Recipe) -> Bool)] {
        [("🍉", "leaf.fill", "bis %d kcal".loc(200), { $0.kcal < 200 }),
         ("🥯", "circle.lefthalf.filled", "200-400 kcal", { (200..<400).contains($0.kcal) }),
         ("🍛", "flame.fill", "400-600 kcal", { (400..<600).contains($0.kcal) }),
         ("🍱", "flame.circle.fill", "ab %d kcal".loc(600), { $0.kcal >= 600 })]
            .filter { range in RecipeStore.all.contains(where: range.3) }
            .map { ($0.0, $0.1, $0.2, $0.3) }
    }

    private var diets: [(emoji: String, symbol: String, label: String, matches: (Recipe) -> Bool)] {
        [("🧀", "leaf.fill", "Vegetarisch".loc, { $0.vegetarian }),
         ("🌱", "leaf.circle.fill", "Vegan".loc, { $0.vegan }),
         ("🍳", "bolt.fill", "Proteinreich".loc, { $0.isHighProtein }),
         ("🥑", "arrow.down.circle.fill", "Low Carb", { $0.isLowCarb }),
         ("🥒", "drop.fill", "Fettarm".loc, { $0.fatG <= 10 }),
         ("🍏", "arrow.down.circle", "Kalorienarm".loc, { $0.kcal <= 250 })]
    }
}

/// Plain vertical list of recipe cards for a category, diet or search filter.
struct RecipeListView: View {
    let title: String
    let recipes: [Recipe]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: RecipeRoute.detail(recipe)) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Full-width recipe card: emoji hero band, name and meta below.
struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeHero(recipe: recipe, height: 104, emojiSize: 46)
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    Label("\(recipe.minutes) \("Min".loc)", systemImage: "clock")
                    Label(recipe.category.label, systemImage: "tag")
                    if recipe.vegan {
                        Label("Vegan".loc, systemImage: "leaf.fill")
                    } else if recipe.vegetarian {
                        Label("Vegetarisch".loc, systemImage: "leaf")
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.tertiary)
                }
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.shadow.opacity(0.06), radius: 10, y: 4)
    }
}

/// Small card for horizontal shelves like favorites and Swiss classics.
struct CompactRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeHero(recipe: recipe, height: 76, emojiSize: 34, compact: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.fredoka(14, .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                Text("\(recipe.kcal) kcal · \(recipe.minutes) \("Min".loc)")
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .frame(width: 160)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Theme.shadow.opacity(0.06), radius: 8, y: 3)
    }
}

/// Gradient band with the recipe emoji and a kcal chip; stands in for photos.
struct RecipeHero: View {
    let recipe: Recipe
    var height: CGFloat
    var emojiSize: CGFloat
    var compact = false
    var flat = false

    var body: some View {
        Group {
            if let photo = recipe.photo {
                Color.clear
                    .overlay {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    }
            } else {
                LinearGradient(colors: recipe.category.gradient,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    // Overlays so the oversized decor circles never widen the layout.
                    .overlay {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.14))
                                .frame(width: height * 1.3)
                                .offset(x: -height * 0.9, y: height * 0.35)
                            Circle()
                                .fill(.white.opacity(0.10))
                                .frame(width: height * 0.9)
                                .offset(x: height * 1.1, y: -height * 0.4)
                            EmojiOrSymbol(emoji: recipe.emoji, symbol: recipe.category.symbol,
                                          size: emojiSize, symbolColor: .white)
                        }
                    }
            }
        }
        .frame(height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: flat ? 0 : (compact ? 18 : 22),
                                          topTrailingRadius: flat ? 0 : (compact ? 18 : 22)))
        .overlay(alignment: .topTrailing) {
            // The flat detail hero runs under the status bar and shows kcal below.
            if !compact && !flat {
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
}

extension Recipe.Category {
    /// Fixed playful gradients, independent of the accent so the shelf stays colorful.
    var gradient: [Color] {
        switch self {
        case .breakfast: return [Color(hex: "F5B84B"), Color(hex: "EE8A3C")]
        case .main: return [Color(hex: "5FB87A"), Color(hex: "3D9268")]
        case .soup: return [Color(hex: "F08160"), Color(hex: "D95B45")]
        case .salad: return [Color(hex: "5EC4B0"), Color(hex: "3A9E8C")]
        case .snack: return [Color(hex: "9B8CF0"), Color(hex: "7A66D9")]
        case .sweet: return [Color(hex: "E88BB4"), Color(hex: "C95E92")]
        }
    }
}
