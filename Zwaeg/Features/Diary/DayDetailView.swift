import SwiftData
import SwiftUI

/// Full nutrition detail of one diary day: energy balance, macro split
/// against the goal, nutrition facts and every logged food.
struct DayDetailView: View {
    let day: Date
    let profile: UserProfile

    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]

    @State private var activity = HealthKitService.DayActivity()

    private var entries: [FoodEntry] {
        allEntries.filter { $0.day == day }
    }

    private var consumed: Int { entries.totalCalories }
    private var carbs: Double { entries.totalCarbs }
    private var protein: Double { entries.totalProtein }
    private var fat: Double { entries.totalFat }

    private var glasses: Int {
        waterDays.first { $0.day == day }?.glasses ?? 0
    }

    private var tdee: Int {
        Int(CalorieMath.tdee(sex: profile.sex, weightKg: profile.weightKg,
                             heightCm: profile.heightCm, age: profile.age,
                             activity: profile.activity).rounded())
    }

    /// Energy balance against the total daily expenditure; negative = deficit.
    private var balance: Int { consumed - tdee }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(title: "Details".loc,
                             subtitle: day.formatted(.dateTime.weekday(.wide).day().month(.wide).year()
                                 .locale(Lingo.shared.language.locale)))
                balanceCard
                macroCard
                factsCard
                if !entries.isEmpty {
                    foodsCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard HealthKitService.shared.isConnected else { return }
            activity = await HealthKitService.shared.activity(for: day)
        }
    }

    // MARK: - Balance

    private var balanceCard: some View {
        let fatKg = Double(balance) / 7700
        return VStack(spacing: 12) {
            balanceRow("Gegessen".loc, "\(consumed) kcal")
            balanceRow("Verbrannt".loc, "\(activity.activeKcal) kcal")
            balanceRow("Gesamtumsatz".loc, "\(tdee) kcal")
            Divider()
            HStack {
                Text("Bilanz".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(String(format: "%+d kcal", balance))
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(balance <= 0 ? Theme.positive
                                                  : Color.appAccent)
                    .contentTransition(.numericText())
            }
            Text("Das entspricht etwa %@ kg Körperfett.".loc(String(format: "%+.2f", fatKg)))
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func balanceRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.fredoka(14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.fredoka(14, .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - Macro distribution

    private struct MacroShare: Identifiable {
        let id: String
        let label: String
        let current: Double
        let goal: Double
        let color: Color
    }

    private var macroShares: [MacroShare] {
        let energy = max(1, carbs * 4 + protein * 4 + fat * 9)
        return [
            MacroShare(id: "carbs", label: "Kohlenhydrate".loc,
                       current: carbs * 4 / energy, goal: 0.45,
                       color: Color(red: 0.98, green: 0.62, blue: 0.24)),
            MacroShare(id: "protein", label: "Protein".loc,
                       current: protein * 4 / energy, goal: 0.25,
                       color: Theme.purple),
            MacroShare(id: "fat", label: "Fett".loc,
                       current: fat * 9 / energy, goal: 0.30,
                       color: Color(red: 0.45, green: 0.76, blue: 0.42)),
        ]
    }

    private var macroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Makroverteilung".loc)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    legendDot(Color.appAccent, "Aktuell".loc)
                    legendDot(Color(.systemGray4), "Ziel".loc)
                }
                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(macroShares) { share in
                        VStack(spacing: 6) {
                            HStack(alignment: .bottom, spacing: 5) {
                                bar(height: share.current, color: share.color)
                                bar(height: share.goal, color: Color(.systemGray5))
                            }
                            Text(share.label)
                                .font(.fredoka(11, .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(Int((share.current * 100).rounded()))% / \(Int(share.goal * 100))%")
                                .font(.fredoka(11, .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.fredoka(11))
                .foregroundStyle(.secondary)
        }
    }

    private func bar(height fraction: Double, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: 22, height: max(8, 110 * fraction))
    }

    // MARK: - Nutrition facts

    private var factsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nährwerte".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                factRow("Kalorien".loc, "\(consumed) kcal")
                Divider()
                factRow("Protein".loc, gram(protein))
                Divider()
                factRow("Kohlenhydrate".loc, gram(carbs))
                Divider()
                factRow("Fett".loc, gram(fat))
                Divider()
                extraFactRows
                factRow("Wasser".loc, String(format: "%.2f l", Double(glasses) * 0.25))
                Divider()
                factRow("Tagesziel".loc, "\(profile.dailyCalorieTarget) kcal")
            }
        }
    }

    private func gram(_ value: Double) -> String {
        String(format: "%.1f g", value)
    }

    /// Sugar, salt and fiber rows; only entries from Open Food Facts carry them.
    @ViewBuilder
    private var extraFactRows: some View {
        let sugar = entries.compactMap(\.sugarG)
        let salt = entries.compactMap(\.saltG)
        let fiber = entries.compactMap(\.fiberG)
        if !sugar.isEmpty {
            factRow("Zucker".loc, gram(sugar.reduce(0, +)))
            Divider()
        }
        if !salt.isEmpty {
            factRow("Salz".loc, gram(salt.reduce(0, +)))
            Divider()
        }
        if !fiber.isEmpty {
            factRow("Ballaststoffe".loc, gram(fiber.reduce(0, +)))
            Divider()
        }
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.fredoka(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - Logged foods

    private func mealColor(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: return Color(red: 1.0, green: 0.72, blue: 0.4)
        case .lunch: return Color(red: 0.55, green: 0.83, blue: 0.5)
        case .dinner: return Theme.purple
        case .snack: return Theme.pink
        }
    }

    private var foodsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mahlzeiten".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.meal.symbol)
                            .font(.fredoka(12, .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(mealColor(entry.meal).gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name)
                                .font(.fredoka(14, .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(entry.meal.label)
                                .font(.fredoka(11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.calories) kcal")
                            .font(.fredoka(13, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }
}
