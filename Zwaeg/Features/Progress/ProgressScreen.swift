import SwiftUI
import SwiftData
import Charts

/// Munch-style activity screen: colored stat tiles, rounded calorie bars,
/// clean weight line.
struct ProgressScreen: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodEntries: [FoodEntry]

    @State private var range: RangeOption = .week

    enum RangeOption: String, CaseIterable, Identifiable {
        case week
        case month
        case threeMonths
        case all

        var id: String { rawValue }

        var label: String {
            switch self {
            case .week: return "Letzte 7 Tage".loc
            case .month: return "Letzter Monat".loc
            case .threeMonths: return "Letzte 3 Monate".loc
            case .all: return "Alles".loc
            }
        }

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .all: return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statTiles
                caloriesCard
                weightCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text("Meine Aktivität".loc)
                    .font(.fredoka(22, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Diese Woche".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Stat tiles

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
            statTile(value: "\(weeklyAverage)",
                     label: "kcal Ø / Tag".loc,
                     background: AnyShapeStyle(LinearGradient(
                        colors: [Theme.accentLight, Theme.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
            statTile(value: monthWeightDelta.map { String(format: "%+.1f", $0) } ?? "–",
                     label: "kg diesen Monat".loc,
                     background: AnyShapeStyle(Theme.ink), foreground: Theme.onInk)
        }
    }

    private func statTile(value: String, label: String, background: AnyShapeStyle,
                          foreground: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.fredoka(27, .semibold))
                .foregroundStyle(foreground)
                .contentTransition(.numericText())
            Text(label)
                .font(.fredoka(12, .semibold))
                .foregroundStyle(foreground.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.10), radius: 10, y: 4)
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
                    Text("Kalorien".loc)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("Ziel %@".loc(profile.dailyCalorieTarget.formatted()))
                        .font(.fredoka(12, .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(days) { item in
                        let isToday = item.day == today
                        let fraction = max(0.08, Double(item.kcal) / Double(maxValue))
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                VStack(spacing: 6) {
                                    Spacer(minLength: 0)
                                    if isToday && item.kcal > 0 {
                                        Text("\(Int((Double(item.kcal) / Double(target) * 100).rounded()))%")
                                            .font(.fredoka(10, .semibold))
                                            .foregroundStyle(Theme.onInk)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.ink, in: Capsule())
                                            .fixedSize()
                                            .frame(maxWidth: .infinity)
                                    }
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isToday
                                              ? AnyShapeStyle(LinearGradient(
                                                    colors: [Theme.accentLight, Theme.accent],
                                                    startPoint: .top, endPoint: .bottom))
                                              : AnyShapeStyle(Theme.accentSoft))
                                        .frame(height: max(16, geo.size.height * fraction))
                                }
                            }
                            Text(item.day.formatted(.dateTime.weekday(.narrow)))
                                .font(.fredoka(12, .semibold))
                                .foregroundStyle(isToday ? Color.appAccent : .secondary)
                        }
                    }
                }
                .frame(height: 170)
            }
        }
    }

    // MARK: - Weight journey (clean line)

    private var filteredWeights: [WeightEntry] {
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else {
            return weights
        }
        return weights.filter { $0.date >= cutoff }
    }

    private var weightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Gewichtsverlauf".loc)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Menu {
                        ForEach(RangeOption.allCases) { option in
                            Button(option.label) {
                                withAnimation(.snappy) { range = option }
                            }
                        }
                    } label: {
                        Text(range.label)
                            .font(.fredoka(12, .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }

                if filteredWeights.count < 2 {
                    Text("Trage regelmäßig dein Gewicht im Profil ein, um den Verlauf zu sehen.".loc)
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    weightChart
                }
            }
        }
    }

    private var weightChart: some View {
        let values = filteredWeights.map(\.weightKg)
        let minY = (values.min() ?? 0) - 1
        let maxY = (values.max() ?? 100) + 1
        return Chart {
            ForEach(filteredWeights) { entry in
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
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: minY...maxY)
        .frame(height: 110)
    }
}
