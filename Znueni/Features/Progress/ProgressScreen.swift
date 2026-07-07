import SwiftUI
import SwiftData
import Charts

/// Munch-style activity screen: weekly stats, rounded calorie bars, weight line.
struct ProgressScreen: View {
    let profile: UserProfile

    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodEntries: [FoodEntry]

    @State private var range: RangeOption = .month

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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statTiles
                caloriesCard
                weightCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Weekly stats

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

    private var weeklyAverage: Int {
        let logged = last7Days.filter { $0.kcal > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.kcal } / logged.count
    }

    private var monthWeightDelta: Double? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) else { return nil }
        let window = weights.filter { $0.date >= cutoff }
        guard let first = window.first, let last = window.last, window.count >= 2 else { return nil }
        return last.weightKg - first.weightKg
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            statTile("\(weeklyAverage)", "kcal Ø / Tag", detail: "diese Woche")
            statTile(monthWeightDelta.map { String(format: "%+.1f", $0) } ?? "–",
                     "kg diesen Monat",
                     detail: monthWeightDelta.map { $0 <= 0 ? "weiter so!" : "dranbleiben" } ?? "zu wenig Daten")
        }
    }

    private func statTile(_ value: String, _ label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Calories (rounded bars)

    private var caloriesCard: some View {
        let days = last7Days
        let target = max(1, profile.dailyCalorieTarget)
        let maxValue = max(days.map(\.kcal).max() ?? 0, target)
        let today = Calendar.current.startOfDay(for: .now)

        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Kalorien")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("Ziel \(profile.dailyCalorieTarget)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(days) { item in
                        let isToday = item.day == today
                        let fraction = max(0.06, Double(item.kcal) / Double(maxValue))
                        VStack(spacing: 6) {
                            if isToday && item.kcal > 0 {
                                Text("\(Int((Double(item.kcal) / Double(target) * 100).rounded()))%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.onAccent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Theme.ink, in: Capsule())
                            }
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    Capsule()
                                        .fill(isToday
                                              ? AnyShapeStyle(LinearGradient(
                                                    colors: [Theme.accent, Color(red: 1.0, green: 0.57, blue: 0.36)],
                                                    startPoint: .top, endPoint: .bottom))
                                              : AnyShapeStyle(Theme.field))
                                        .frame(height: max(12, geo.size.height * fraction))
                                }
                            }
                            Text(item.day.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isToday ? Theme.ink : .secondary)
                        }
                    }
                }
                .frame(height: 170)
            }
        }
    }

    // MARK: - Weight journey

    private var filteredWeights: [WeightEntry] {
        guard let months = range.months,
              let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: .now) else {
            return weights
        }
        return weights.filter { $0.date >= cutoff }
    }

    private var weightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gewichtsverlauf")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text(rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    rangeChips
                }

                if filteredWeights.count < 2 {
                    Text("Trage regelmässig dein Gewicht im Profil ein, um den Verlauf zu sehen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    weightStats
                    weightChart
                }
            }
        }
    }

    private var rangeLabel: String {
        switch range {
        case .month: return "Letzter Monat"
        case .threeMonths: return "Letzte 3 Monate"
        case .sixMonths: return "Letzte 6 Monate"
        case .all: return "Gesamter Verlauf"
        }
    }

    private var rangeChips: some View {
        HStack(spacing: 6) {
            ForEach(RangeOption.allCases) { option in
                Button(option.rawValue) {
                    withAnimation(.snappy) { range = option }
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(range == option ? Theme.accent : Theme.field, in: Capsule())
                .foregroundStyle(range == option ? Theme.onAccent : .secondary)
                .buttonStyle(.plain)
            }
        }
    }

    private var weightStats: some View {
        let current = filteredWeights.last?.weightKg ?? 0
        let first = filteredWeights.first?.weightKg ?? 0
        let delta = current - first
        return HStack(spacing: 20) {
            weightStat("Aktuell", String(format: "%.1f kg", current))
            weightStat("Veränderung", String(format: "%+.1f kg", delta),
                       color: delta <= 0 ? Color.appAccent : .orange)
            weightStat("BMI", String(format: "%.1f", CalorieMath.bmi(weightKg: current, heightCm: profile.heightCm)))
        }
    }

    private func weightStat(_ title: String, _ value: String, color: Color = Theme.ink) -> some View {
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
        let minY = (values.min() ?? 0) - 1.5
        let maxY = (values.max() ?? 100) + 1.5
        return Chart {
            ForEach(filteredWeights) { entry in
                AreaMark(
                    x: .value("Datum", entry.date),
                    yStart: .value("Basis", minY),
                    yEnd: .value("Gewicht", entry.weightKg))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent.opacity(0.22), .clear],
                                       startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Datum", entry.date),
                    y: .value("Gewicht", entry.weightKg))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = filteredWeights.last {
                PointMark(
                    x: .value("Datum", last.date),
                    y: .value("Gewicht", last.weightKg))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(140)
                PointMark(
                    x: .value("Datum", last.date),
                    y: .value("Gewicht", last.weightKg))
                    .foregroundStyle(Theme.card)
                    .symbolSize(50)
            }
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 190)
    }
}
