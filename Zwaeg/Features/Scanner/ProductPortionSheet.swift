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

    /// Grams behind one serving; database items default to 100 g.
    private var servingGrams: Double {
        product.servingGrams ?? 100
    }

    private var totalGrams: Double {
        servingGrams * servings
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
                    mealChips
                }
                .padding(20)
            }
            addButton
        }
        .background(Theme.background)
        .onAppear {
            meal = initialMeal ?? Self.defaultMeal()
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
        parts.append(product.source == .openFoodFacts ? "Open Food Facts" : "Schweizer Lebensmittel".loc)
        parts.append("1 Portion = %d g".loc(Int(servingGrams.rounded())))
        return parts.joined(separator: " · ")
    }

    // MARK: - Servings

    private var servingsRow: some View {
        HStack {
            Text("Portionen".loc)
                .font(.fredoka(17, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                withAnimation(.snappy) { servings = max(0.5, servings - 0.5) }
            } label: {
                Image(systemName: "minus")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.accentSoft, in: Circle())
            }
            .buttonStyle(.plain)
            Text(servingsLabel)
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 44)
                .contentTransition(.numericText())
            Button {
                withAnimation(.snappy) { servings = min(10, servings + 0.5) }
            } label: {
                Image(systemName: "plus")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 34, height: 34)
                    .background(Theme.ink, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, y: 3)
    }

    private var servingsLabel: String {
        servings.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(servings))"
            : String(format: "%.1f", servings)
    }

    // MARK: - Calories

    private var calorieCard: some View {
        VStack(spacing: 4) {
            Text("\(product.kcal(for: servingGrams))")
                .font(.fredoka(50, .semibold))
                .foregroundStyle(.white)
            Text("Kalorien pro Portion".loc)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if servings != 1 {
                Text("%@ Portionen · %d kcal gesamt".loc(servingsLabel, product.kcal(for: totalGrams)))
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
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
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    private func formatGrams(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }

    // MARK: - Meal selection

    private var mealChips: some View {
        HStack(spacing: 8) {
            ForEach(MealType.allCases) { type in
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
                        .foregroundStyle(meal == type ? Theme.onAccent : .secondary)
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
                    LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
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
            fatG: product.fat(for: totalGrams))
        context.insert(entry)
        dismiss()
    }
}
