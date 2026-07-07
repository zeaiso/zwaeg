import SwiftUI
import SwiftData

struct AddFoodView: View {
    let day: Date
    let meal: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]

    @State private var name = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

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
            if result.count == 8 { break }
        }
        return result
    }

    private var calories: Int? { Int(caloriesText) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lebensmittel") {
                    TextField("Name (z.B. Zopf mit Butter)", text: $name)
                    TextField("Kalorien (kcal)", text: $caloriesText)
                        .keyboardType(.numberPad)
                }
                Section("Makros (optional)") {
                    TextField("Protein (g)", text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField("Kohlenhydrate (g)", text: $carbsText)
                        .keyboardType(.decimalPad)
                    TextField("Fett (g)", text: $fatText)
                        .keyboardType(.decimalPad)
                }
                if !recentFoods.isEmpty {
                    Section("Zuletzt geloggt") {
                        ForEach(recentFoods) { food in
                            Button {
                                name = food.name
                                caloriesText = "\(food.calories)"
                                proteinText = food.proteinG > 0 ? String(format: "%.0f", food.proteinG) : ""
                                carbsText = food.carbsG > 0 ? String(format: "%.0f", food.carbsG) : ""
                                fatText = food.fatG > 0 ? String(format: "%.0f", food.fatG) : ""
                            } label: {
                                HStack {
                                    Text(food.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(food.calories) kcal")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(meal.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || calories == nil)
                }
            }
        }
    }

    private func save() {
        guard let kcal = calories else { return }
        let entry = FoodEntry(
            day: day, meal: meal,
            name: name.trimmingCharacters(in: .whitespaces),
            calories: kcal,
            proteinG: Double(proteinText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            carbsG: Double(carbsText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            fatG: Double(fatText.replacingOccurrences(of: ",", with: ".")) ?? 0)
        context.insert(entry)
        dismiss()
    }
}
