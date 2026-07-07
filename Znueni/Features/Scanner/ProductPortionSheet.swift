import SwiftUI
import SwiftData

/// Munch-style meal detail: portion, big calorie number, macro tiles, add button.
struct ProductPortionSheet: View {
    let product: FoodProduct

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var grams = 100.0
    @State private var meal: MealType = ProductPortionSheet.defaultMeal()

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
                VStack(alignment: .leading, spacing: 20) {
                    grabber
                    titleBlock
                    calorieBlock
                    portionBlock
                    macroTiles
                    mealPicker
                }
                .padding(20)
            }
            addButton
        }
        .background(Theme.background)
    }

    private var grabber: some View {
        Capsule()
            .fill(Theme.field)
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.displayName)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Label(product.source == .openFoodFacts ? "Open Food Facts" : "Schweizer Lebensmittel",
                      systemImage: product.source == .openFoodFacts ? "barcode" : "mountain.2.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Color.appAccent)
                Text("\(Int(product.kcalPer100g.rounded())) kcal / 100 g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var calorieBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(product.kcal(for: grams))")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text("Kalorien pro Portion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var portionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Portion")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                ForEach([25.0, 50, 100, 150, 200, 300], id: \.self) { amount in
                    Button("\(Int(amount))") {
                        withAnimation(.snappy) { grams = amount }
                    }
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(grams == amount ? Theme.accent : Theme.card, in: Capsule())
                    .foregroundStyle(grams == amount ? Theme.onAccent : Theme.ink)
                    .buttonStyle(.plain)
                    .shadow(color: Theme.ink.opacity(0.04), radius: 4, y: 2)
                }
            }
            ValueField(title: "Menge", value: $grams, range: 5...1000, step: 5, unit: "g")
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var macroTiles: some View {
        HStack(spacing: 12) {
            macroTile("\(format(product.protein(for: grams)))g", "Protein", Color(red: 1.0, green: 0.42, blue: 0.29))
            macroTile("\(format(product.carbs(for: grams)))g", "Kohlenhydrate", Color(red: 0.42, green: 0.36, blue: 0.91))
            macroTile("\(format(product.fat(for: grams)))g", "Fett", Color(red: 0.24, green: 0.68, blue: 1.0))
        }
    }

    private func format(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }

    private func macroTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mahlzeit")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { meal = type }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.symbol)
                            Text(type.label)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(meal == type ? Theme.accentSoft : Theme.card,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(meal == type ? Color.appAccent : .secondary)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(meal == type ? Color.appAccent.opacity(0.5) : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            save()
        } label: {
            Text(meal.addLabel)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(Theme.onAccent)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Theme.background)
    }

    private func save() {
        let entry = FoodEntry(
            day: .now, meal: meal,
            name: product.displayName,
            calories: product.kcal(for: grams),
            proteinG: product.protein(for: grams),
            carbsG: product.carbs(for: grams),
            fatG: product.fat(for: grams))
        context.insert(entry)
        dismiss()
    }
}
