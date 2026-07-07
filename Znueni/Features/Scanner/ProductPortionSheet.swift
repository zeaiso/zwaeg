import SwiftUI
import SwiftData

/// Portion picker for a looked-up product; saves a FoodEntry into today's diary.
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    portionCard
                    mealPicker
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(product.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(product.source == .openFoodFacts ? "Open Food Facts" : "Schweizer Lebensmittel",
                          systemImage: product.source == .openFoodFacts ? "barcode" : "mountain.2.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.appAccent)
                    Text("\(Int(product.kcalPer100g.rounded())) kcal / 100 g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(product.kcal(for: grams))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        macroLine("Protein", product.protein(for: grams))
                        macroLine("Kohlenhydrate", product.carbs(for: grams))
                        macroLine("Fett", product.fat(for: grams))
                    }
                }
                ValueField(title: "Menge", value: $grams, range: 5...500, step: 5, unit: "g")
                HStack(spacing: 8) {
                    ForEach([25.0, 50, 100, 150, 200, 300], id: \.self) { amount in
                        Button("\(Int(amount))") {
                            withAnimation { grams = amount }
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(grams == amount ? Color.appAccent.opacity(0.15)
                                                    : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(grams == amount ? Color.appAccent : .primary)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func macroLine(_ label: String, _ value: Double) -> some View {
        Text("\(label): \(String(format: "%.1f", value)) g")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var mealPicker: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mahlzeit")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(MealType.allCases) { type in
                        Button {
                            meal = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.symbol)
                                Text(type.label)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(meal == type ? Color.appAccent.opacity(0.15)
                                                     : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(meal == type ? Color.appAccent : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
