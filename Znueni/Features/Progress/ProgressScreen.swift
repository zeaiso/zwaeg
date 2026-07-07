import SwiftUI
import SwiftData
import Charts

/// Weight trend and last-week calorie overview.
struct ProgressScreen: View {
    let profile: UserProfile

    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodEntries: [FoodEntry]

    @State private var range: RangeOption = .threeMonths

    enum RangeOption: String, CaseIterable, Identifiable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case all = "Alle"

        var id: String { rawValue }

        var months: Int? {
            switch self {
            case .month: return 1
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .all: return nil
            }
        }
    }

    private var filteredWeights: [WeightEntry] {
        guard let months = range.months,
              let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: .now) else {
            return weights
        }
        return weights.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weightCard
                calorieCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Weight

    private var weightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Gewicht")
                        .font(.headline)
                    Spacer()
                    Picker("Zeitraum", selection: $range) {
                        ForEach(RangeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                if filteredWeights.isEmpty {
                    Text("Noch keine Einträge. Trage dein Gewicht im Profil ein.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    weightStats
                    weightChart
                }
            }
        }
    }

    private var weightStats: some View {
        let current = filteredWeights.last?.weightKg ?? 0
        let first = filteredWeights.first?.weightKg ?? 0
        let delta = current - first
        return HStack(spacing: 20) {
            stat("Aktuell", String(format: "%.1f kg", current))
            stat("Veränderung", String(format: "%+.1f kg", delta),
                 color: delta <= 0 ? .appAccent : .orange)
            stat("BMI", String(format: "%.1f", CalorieMath.bmi(weightKg: current, heightCm: profile.heightCm)))
        }
    }

    private func stat(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weightChart: some View {
        let values = filteredWeights.map(\.weightKg)
        let minY = (values.min() ?? 0) - 2
        let maxY = (values.max() ?? 100) + 2
        return Chart(filteredWeights) { entry in
            AreaMark(
                x: .value("Datum", entry.date),
                yStart: .value("Basis", minY),
                yEnd: .value("Gewicht", entry.weightKg))
                .foregroundStyle(
                    LinearGradient(colors: [Color.appAccent.opacity(0.25), .clear],
                                   startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(
                x: .value("Datum", entry.date),
                y: .value("Gewicht", entry.weightKg))
                .foregroundStyle(Color.appAccent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
            if filteredWeights.count <= 30 {
                PointMark(
                    x: .value("Datum", entry.date),
                    y: .value("Gewicht", entry.weightKg))
                    .foregroundStyle(Color.appAccent)
                    .symbolSize(30)
            }
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
    }

    // MARK: - Calories last 7 days

    private struct DayCalories: Identifiable {
        let id: Date
        let day: Date
        let kcal: Int
    }

    private var last7Days: [DayCalories] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let kcal = foodEntries.filter { $0.day == day }.reduce(0) { $0 + $1.calories }
            return DayCalories(id: day, day: day, kcal: kcal)
        }
    }

    private var calorieCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Kalorien: letzte 7 Tage")
                    .font(.headline)
                Chart(last7Days) { item in
                    BarMark(
                        x: .value("Tag", item.day, unit: .day),
                        y: .value("kcal", item.kcal))
                        .foregroundStyle(item.kcal > profile.dailyCalorieTarget
                                         ? Color.orange.gradient
                                         : Color.appAccent.gradient)
                        .cornerRadius(5)
                    RuleMark(y: .value("Ziel", profile.dailyCalorieTarget))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 160)
                Text("Gestrichelte Linie: dein Tagesziel (\(profile.dailyCalorieTarget) kcal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
