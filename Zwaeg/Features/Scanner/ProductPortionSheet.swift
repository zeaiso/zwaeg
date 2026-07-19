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
    @State private var pieces = 1
    @State private var meal: MealType = .breakfast
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""
    /// Last chosen unit sticks across products for people who always think
    /// in grams (or pieces).
    @AppStorage("amountUnit") private var unitRaw = AmountUnit.portion.rawValue
    @State private var unit: AmountUnit = .portion
    @State private var grams = 100.0
    @FocusState private var gramsFocused: Bool

    enum AmountUnit: String, CaseIterable, Identifiable {
        case portion, gramm, piece

        var id: String { rawValue }

        var label: String {
            switch self {
            case .portion: return "Portionen".loc
            case .gramm: return "Gramm".loc
            case .piece: return "Stück".loc
            }
        }
    }

    private let gramChips: [Double] = [50, 100, 150, 200, 300]
    /// Typing 4 digits tops out here; far below FoodProduct.maxServingGrams.
    private let maxGrams = 5000.0

    /// Grams behind one serving; database items default to 100 g.
    private var servingGrams: Double {
        product.servingGrams ?? 100
    }

    private var totalGrams: Double {
        switch unit {
        case .portion: return servingGrams * servings
        case .piece: return servingGrams * Double(pieces)
        case .gramm: return grams
        }
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
            unit = AmountUnit(rawValue: unitRaw) ?? .portion
            if LaunchArgs.all.contains("-demo-grams") {
                unit = .gramm
            }
        }
        .toolbar {
            // The number pad has no return key; without this the keyboard
            // would be stuck (the mood-note lesson).
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig".loc) { gramsFocused = false }
                    .font(.fredoka(15, .semibold))
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
        parts.append(unit == .piece ? "1 Stück = %d g".loc(Int(servingGrams.rounded()))
                                    : "1 Portion = %d g".loc(Int(servingGrams.rounded())))
        return parts.joined(separator: " · ")
    }

    // MARK: - Amount

    private var servingsRow: some View {
        VStack(spacing: 12) {
            HStack {
                unitMenu
                Spacer()
                stepButton("minus", prominent: false) {
                    switch unit {
                    case .portion: servings = max(0.5, servings - 0.5)
                    case .piece: pieces = max(1, pieces - 1)
                    case .gramm: grams = max(0, grams - 5)
                    }
                }
                amountValue
                stepButton("plus", prominent: true) {
                    switch unit {
                    case .portion: servings = min(10, servings + 0.5)
                    case .piece: pieces = min(20, pieces + 1)
                    case .gramm: grams = min(maxGrams, grams + 5)
                    }
                }
            }
            if unit == .gramm {
                HStack(spacing: 8) {
                    ForEach(gramChips, id: \.self) { value in
                        Button {
                            withAnimation(.snappy) { grams = value }
                            gramsFocused = false
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

    private var unitMenu: some View {
        Menu {
            ForEach(AmountUnit.allCases) { target in
                Button {
                    switchUnit(to: target)
                } label: {
                    if unit == target {
                        Label(target.label, systemImage: "checkmark")
                    } else {
                        Text(target.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(unit.label)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.fredoka(11, .semibold))
            }
            .font(.fredoka(14, .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.ink, in: Capsule())
            .foregroundStyle(Theme.onInk)
        }
        .buttonStyle(.plain)
    }

    /// The value between the steppers: text for portions and pieces, a
    /// type-anything field for grams.
    @ViewBuilder
    private var amountValue: some View {
        switch unit {
        case .portion:
            Text(servingsLabel)
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 44)
                .contentTransition(.numericText())
        case .piece:
            Text("\(pieces)")
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 44)
                .contentTransition(.numericText())
        case .gramm:
            HStack(spacing: 3) {
                TextField("0", text: gramsText)
                    .keyboardType(.numberPad)
                    .focused($gramsFocused)
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(width: 58)
                    .padding(.vertical, 4)
                    .background(Theme.field.opacity(gramsFocused ? 0.8 : 0.5),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("g")
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Bridges the gram amount to the text field, digits only, clamped.
    private var gramsText: Binding<String> {
        Binding(
            get: { "\(Int(grams))" },
            set: { grams = min(maxGrams, Double($0.filter(\.isNumber)) ?? 0) })
    }

    /// Switching units keeps the chosen amount: portions and pieces convert
    /// to their grams, grams to the nearest half portion or whole piece.
    private func switchUnit(to target: AmountUnit) {
        guard target != unit else { return }
        let total = totalGrams
        gramsFocused = false
        withAnimation(.snappy) {
            switch target {
            case .gramm: grams = min(maxGrams, max(5, (total / 5).rounded() * 5))
            case .portion: servings = min(10, max(0.5, (total / servingGrams * 2).rounded() / 2))
            case .piece: pieces = min(20, max(1, Int((total / servingGrams).rounded())))
            }
            unit = target
            unitRaw = target.rawValue
        }
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


    private var servingsLabel: String {
        servings.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(servings))"
            : String(format: "%.1f", servings)
    }

    // MARK: - Calories

    private var calorieCard: some View {
        VStack(spacing: 4) {
            Text("\(product.kcal(for: unit == .gramm ? grams : servingGrams))")
                .font(.fredoka(50, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(calorieCaption)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if let total = calorieTotalLine {
                Text(total)
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

    private var calorieCaption: String {
        switch unit {
        case .portion: return "Kalorien pro Portion".loc
        case .piece: return "Kalorien pro Stück".loc
        case .gramm: return "Kalorien für %d g".loc(Int(grams))
        }
    }

    private var calorieTotalLine: String? {
        switch unit {
        case .portion where servings != 1:
            return "%@ Portionen · %d kcal gesamt".loc(servingsLabel, product.kcal(for: totalGrams))
        case .piece where pieces != 1:
            return "%d Stück · %d kcal gesamt".loc(pieces, product.kcal(for: totalGrams))
        default:
            return nil
        }
    }

    // MARK: - Macros

    private var macroTiles: some View {
        HStack(spacing: 12) {
            macroTile(product.protein(for: totalGrams), "Protein".loc, Theme.accent)
            macroTile(product.carbs(for: totalGrams), "Kohlenhydrate".loc, Theme.amber)
            macroTile(product.fat(for: totalGrams), "Fett".loc, Theme.purple)
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
        .disabled(totalGrams <= 0)
        .opacity(totalGrams <= 0 ? 0.5 : 1)
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
