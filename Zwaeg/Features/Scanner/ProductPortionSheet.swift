import SwiftUI
import SwiftData

/// Munch-style product detail: servings stepper, big calorie card,
/// macro tiles and an add button for the target meal.
struct ProductPortionSheet: View {
    let product: FoodProduct
    var day: Date = Calendar.current.startOfDay(for: .now)
    var initialMeal: MealType?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var servings = 1.0
    @State private var meal: MealType = .breakfast
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""
    /// Amount unit: portions of the serving size, or grams directly.
    @State private var unit: AmountUnit = .portion
    @State private var grams = 100.0

    enum AmountUnit {
        case portion, gramm
    }

    private let gramChips: [Double] = [50, 100, 150, 200, 300]

    /// Grams behind one serving; database items default to 100 g.
    private var servingGrams: Double {
        product.servingGrams ?? 100
    }

    private var totalGrams: Double {
        unit == .portion ? servingGrams * servings : grams
    }

    private static func defaultMeal(now: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: now) {
        case ..<10: return .breakfast
        case ..<14: return .lunch
        case ..<17: return .snack
        case ..<22: return .dinner
        default: return .snack
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    servingsRow
                    calorieCard
                    macroTiles
                    extrasRow
                    mealChips
                }
                .padding(20)
            }
            addButton
        }
        .background(Theme.background)
        .onAppear {
            meal = initialMeal ?? Self.defaultMeal()
            // The time-based default may be a meal the user doesn't eat;
            // an explicit initialMeal (meal card add button) always wins.
            let enabled = MealPlan.enabled(from: enabledMealsRaw)
            if initialMeal == nil, !enabled.contains(meal), let first = enabled.first {
                meal = first
            }
            grams = servingGrams
            if LaunchArgs.all.contains("-demo-grams") {
                unit = .gramm
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(Theme.field)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text(product.name)
                .font(.fredoka(27, .semibold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.fredoka(15))
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let brand = product.brand, !brand.isEmpty {
            parts.append(brand)
        }
        switch product.source {
        case .openFoodFacts: parts.append("Open Food Facts")
        case .swissDatabase: parts.append("Schweizer Lebensmittel".loc)
        case .custom: parts.append("Eigenes Lebensmittel".loc)
        }
        parts.append("1 Portion = %d g".loc(Int(servingGrams.rounded())))
        return parts.joined(separator: " · ")
    }

    // MARK: - Amount

    private var servingsRow: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    unitChip("Portionen".loc, .portion)
                    unitChip("Gramm".loc, .gramm)
                }
                Spacer()
                stepButton("minus", prominent: false) {
                    if unit == .portion {
                        servings = max(0.5, servings - 0.5)
                    } else {
                        grams = max(5, grams - 5)
                    }
                }
                Text(amountLabel)
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 44)
                    .contentTransition(.numericText())
                stepButton("plus", prominent: true) {
                    if unit == .portion {
                        servings = min(10, servings + 0.5)
                    } else {
                        grams = min(1000, grams + 5)
                    }
                }
            }
            if unit == .gramm {
                HStack(spacing: 8) {
                    ForEach(gramChips, id: \.self) { value in
                        Button {
                            withAnimation(.snappy) { grams = value }
                        } label: {
                            Text("\(Int(value)) g")
                                .font(.fredoka(12, .semibold))
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity)
                                .background(grams == value ? Theme.ink : Theme.field.opacity(0.6),
                                            in: Capsule())
                                .foregroundStyle(grams == value ? Theme.onInk : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.04), radius: 8, y: 3)
    }

    /// Switching units keeps the chosen amount: portions convert to their
    /// grams and grams to the nearest half portion.
    private func unitChip(_ title: String, _ target: AmountUnit) -> some View {
        Button {
            guard unit != target else { return }
            withAnimation(.snappy) {
                if target == .gramm {
                    grams = min(1000, max(5, (servingGrams * servings / 5).rounded() * 5))
                } else {
                    servings = min(10, max(0.5, (grams / servingGrams * 2).rounded() / 2))
                }
                unit = target
            }
        } label: {
            Text(title)
                .font(.fredoka(13, .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(unit == target ? Theme.ink : Theme.field.opacity(0.6), in: Capsule())
                .foregroundStyle(unit == target ? Theme.onInk : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
                .frame(width: 34, height: 34)
                .background(prominent ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.accentSoft),
                            in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var amountLabel: String {
        unit == .portion ? servingsLabel : "\(Int(grams))"
    }

    private var servingsLabel: String {
        servings.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(servings))"
            : String(format: "%.1f", servings)
    }

    // MARK: - Calories

    private var calorieCard: some View {
        VStack(spacing: 4) {
            Text("\(product.kcal(for: unit == .portion ? servingGrams : grams))")
                .font(.fredoka(50, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(unit == .portion ? "Kalorien pro Portion".loc : "Kalorien für %d g".loc(Int(grams)))
                .font(.fredoka(15, .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if unit == .portion, servings != 1 {
                Text("%@ Portionen · %d kcal gesamt".loc(servingsLabel, product.kcal(for: totalGrams)))
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(colors: [Theme.accentLight, Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 5)
    }

    // MARK: - Macros

    private var macroTiles: some View {
        HStack(spacing: 12) {
            macroTile(product.protein(for: totalGrams), "Protein".loc, Theme.accent)
            macroTile(product.carbs(for: totalGrams), "Kohlenhydrate".loc, Color(red: 1.0, green: 0.72, blue: 0.25))
            macroTile(product.fat(for: totalGrams), "Fett".loc, Color(red: 0.52, green: 0.48, blue: 0.95))
        }
    }

    /// Sugar, salt and fiber for the chosen amount when the source provides them.
    @ViewBuilder
    private var extrasRow: some View {
        let parts: [String] = [
            product.sugar(for: totalGrams).map { "\("Zucker".loc) \(formatGrams($0)) g" },
            product.salt(for: totalGrams).map { "\("Salz".loc) \(formatGrams($0)) g" },
            product.fiber(for: totalGrams).map { "\("Ballaststoffe".loc) \(formatGrams($0)) g" },
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
        }
    }

    private func macroTile(_ grams: Double, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text("\(formatGrams(grams))g")
                .font(.fredoka(17, .semibold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.fredoka(11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    private func formatGrams(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }

    // MARK: - Meal selection

    private var mealChips: some View {
        HStack(spacing: 8) {
            ForEach(MealPlan.enabled(from: enabledMealsRaw)) { type in
                Button {
                    withAnimation(.snappy) { meal = type }
                } label: {
                    Text(type.label)
                        .font(.fredoka(12, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(meal == type ? Theme.ink : Theme.card, in: Capsule())
                        .foregroundStyle(meal == type ? Theme.onInk : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Add

    private var addButton: some View {
        Button {
            save()
        } label: {
            Text(meal.addLabel)
                .font(.fredoka(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.accentLight, Theme.accent],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule())
                .foregroundStyle(Theme.onAccent)
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Theme.background)
    }

    private func save() {
        let entry = FoodEntry(
            day: day, meal: meal,
            name: product.displayName,
            calories: product.kcal(for: totalGrams),
            proteinG: product.protein(for: totalGrams),
            carbsG: product.carbs(for: totalGrams),
            fatG: product.fat(for: totalGrams),
            sugarG: product.sugar(for: totalGrams),
            saltG: product.salt(for: totalGrams),
            fiberG: product.fiber(for: totalGrams))
        context.insert(entry)
        dismiss()
    }
}
