import SwiftUI
import SwiftData

/// Sheet that creates a reusable own product with values per 100 g.
/// Opens from add food and from the scanner when a barcode is unknown;
/// the created product flows straight into the portion sheet.
struct CustomFoodForm: View {
    var barcode: String?
    /// Values read off a nutrition label by the scanner; prefilled once.
    var prefill: NutritionFacts? = nil
    var onCreated: (FoodProduct) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var portionGrams = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (Self.number(kcal) ?? -1) >= 0
    }

    /// Accepts decimal comma and decimal point.
    private static func number(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    field("Name (z.B. Zopf mit Butter)".loc, text: $name)
                    field("Marke (optional)".loc, text: $brand)
                    sectionLabel("Nährwerte pro 100 g".loc)
                    field("Kalorien".loc, text: $kcal, numeric: true)
                    HStack(spacing: 10) {
                        field("Protein".loc, text: $protein, numeric: true)
                        field("Kohlenhydrate".loc, text: $carbs, numeric: true)
                        field("Fett".loc, text: $fat, numeric: true)
                    }
                    field("Portion (g, optional)".loc, text: $portionGrams, numeric: true)
                    if let barcode {
                        HStack(spacing: 8) {
                            Image(systemName: "barcode")
                            Text(barcode)
                        }
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    }
                }
                .padding(20)
            }
            saveButton
        }
        .background(Theme.background)
        .onAppear {
            guard let prefill, kcal.isEmpty else { return }
            kcal = Self.fieldText(prefill.kcal)
            protein = Self.fieldText(prefill.protein)
            carbs = Self.fieldText(prefill.carbs)
            fat = Self.fieldText(prefill.fat)
        }
    }

    private static func fieldText(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value)) : String(value)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(Theme.field)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text("Eigenes Lebensmittel".loc)
                .font(.fredoka(24, .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.fredoka(12, .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func field(_ prompt: String, text: Binding<String>, numeric: Bool = false) -> some View {
        TextField(prompt, text: text)
            .keyboardType(numeric ? .decimalPad : .default)
            .font(.fredoka(15))
            .padding(13)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Speichern".loc)
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
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Theme.background)
    }

    private func save() {
        guard let kcalValue = Self.number(kcal) else { return }
        func clamped(_ text: String, max maxValue: Double) -> Double {
            min(maxValue, Swift.max(0, Self.number(text) ?? 0))
        }
        let food = CustomFood(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            kcalPer100g: min(900, max(0, kcalValue)),
            proteinPer100g: clamped(protein, max: 100),
            carbsPer100g: clamped(carbs, max: 100),
            fatPer100g: clamped(fat, max: 100),
            barcode: barcode,
            servingGrams: Self.number(portionGrams).flatMap { $0 > 0 ? $0 : nil })
        context.insert(food)
        onCreated(food.asProduct)
        dismiss()
    }
}
