import SwiftUI
import SwiftData

/// Munch-style add-food page: search, meal filter chips, scan banner,
/// what is already logged in the meal, recents with quick add.
/// Manual entry is a fallback for foods that cannot be scanned.
struct AddFoodView: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]

    @State private var meal: MealType
    @State private var query = ""
    @State private var justAdded: String?
    @State private var showManual = false

    @State private var manualName = ""
    @State private var manualKcal = ""

    init(day: Date, meal: MealType) {
        self.day = day
        _meal = State(initialValue: meal)
    }

    private var searchResults: [FoodProduct] {
        Array(SwissFoodDatabase.shared.search(query).prefix(8))
    }

    /// Entries already logged for this day and the selected meal.
    private var mealEntries: [FoodEntry] {
        allEntries.filter { $0.day == day && $0.meal == meal }
    }

    /// Most recent unique foods for one-tap re-logging.
    private var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in allEntries {
            let key = entry.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(entry)
            }
            if result.count == 6 { break }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                searchField
                mealChips
                scanBanner
                loggedSection
                if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                    sectionLabel("ERGEBNISSE")
                    if searchResults.isEmpty {
                        Text("Nichts gefunden. Scanne den Barcode oder trage es als eigenes Lebensmittel ein.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(searchResults) { product in
                        productRow(product)
                    }
                } else if !recentFoods.isEmpty {
                    sectionLabel("ZULETZT")
                    ForEach(recentFoods) { food in
                        recentRow(food)
                    }
                }
                manualFallback
            }
            .padding(20)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header & search

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.ink.opacity(0.05), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            Text("Essen hinzufügen")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Lebensmittel suchen...", text: $query)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    private var mealChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { meal = type }
                    } label: {
                        Text(type.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(meal == type ? Theme.ink : Theme.card, in: Capsule())
                            .foregroundStyle(meal == type ? Theme.onAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Scan banner

    private var scanBanner: some View {
        Button {
            dismiss()
            TabRouter.shared.selection = 2
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanne dein Essen")
                        .font(.headline)
                    Text("Barcode scannen, in Sekunden geloggt")
                        .font(.caption)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(
                LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Already logged in this meal

    @ViewBuilder
    private var loggedSection: some View {
        if !mealEntries.isEmpty {
            let total = mealEntries.reduce(0) { $0 + $1.calories }
            sectionLabel("IN \(meal.label.uppercased()) · \(total) KCAL")
            ForEach(mealEntries) { entry in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(thumbColor(for: entry.name))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(entry.calories) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy) { context.delete(entry) }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Theme.field, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
            }
        }
    }

    // MARK: - Rows

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private static let thumbColors: [Color] = [
        Color(red: 0.99, green: 0.87, blue: 0.6),
        Color(red: 0.78, green: 0.92, blue: 0.66),
        Color(red: 1.0, green: 0.8, blue: 0.79),
        Color(red: 0.75, green: 0.87, blue: 0.99),
        Color(red: 0.93, green: 0.83, blue: 0.99),
    ]

    private func thumbColor(for name: String) -> Color {
        var hash: UInt64 = 5381
        for byte in name.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Self.thumbColors[Int(hash % UInt64(Self.thumbColors.count))]
    }

    private func foodRow(name: String, subtitle: String, added: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(thumbColor(for: name))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: action) {
                Image(systemName: added ? "checkmark" : "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(added ? Theme.onAccent : Color.appAccent)
                    .frame(width: 32, height: 32)
                    .background(added ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accentSoft),
                                in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    private func productRow(_ product: FoodProduct) -> some View {
        foodRow(name: product.name,
                subtitle: "100 g · \(Int(product.kcalPer100g.rounded())) kcal",
                added: justAdded == product.id) {
            add(name: product.displayName,
                calories: product.kcal(for: 100),
                protein: product.protein(for: 100),
                carbs: product.carbs(for: 100),
                fat: product.fat(for: 100),
                flashID: product.id)
        }
    }

    private func recentRow(_ food: FoodEntry) -> some View {
        foodRow(name: food.name,
                subtitle: "\(food.calories) kcal",
                added: justAdded == food.name) {
            add(name: food.name,
                calories: food.calories,
                protein: food.proteinG,
                carbs: food.carbsG,
                fat: food.fatG,
                flashID: food.name)
        }
    }

    // MARK: - Manual entry (fallback when scanning is not possible)

    @ViewBuilder
    private var manualFallback: some View {
        if showManual {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("EIGENES LEBENSMITTEL")
                VStack(spacing: 10) {
                    TextField("Name (z.B. Zopf mit Butter)", text: $manualName)
                        .padding(12)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 10) {
                        TextField("Kalorien", text: $manualKcal)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            addManual()
                        } label: {
                            Text("Hinzufügen")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(Theme.onAccent)
                        }
                        .buttonStyle(.plain)
                        .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty || Int(manualKcal) == nil)
                        .opacity(manualName.trimmingCharacters(in: .whitespaces).isEmpty || Int(manualKcal) == nil ? 0.5 : 1)
                    }
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
            }
        } else {
            Button {
                withAnimation(.snappy) { showManual = true }
            } label: {
                Text("Nicht scannbar? Eigenes Lebensmittel eintragen")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Saving

    private func add(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, flashID: String) {
        let entry = FoodEntry(day: day, meal: meal, name: name, calories: calories,
                              proteinG: protein, carbsG: carbs, fatG: fat)
        context.insert(entry)
        withAnimation(.snappy) { justAdded = flashID }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { justAdded = nil }
        }
    }

    private func addManual() {
        guard let kcal = Int(manualKcal) else { return }
        add(name: manualName.trimmingCharacters(in: .whitespaces),
            calories: kcal, protein: 0, carbs: 0, fat: 0, flashID: "manual")
        manualName = ""
        manualKcal = ""
        withAnimation { showManual = false }
    }
}
