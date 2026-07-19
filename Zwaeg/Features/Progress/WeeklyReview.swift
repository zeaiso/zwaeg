import SwiftUI
import SwiftData

/// The week the Wochenrückblick covers and the numbers on it. On Sunday the
/// current week (it ends tonight, matching the Sunday-evening notification),
/// otherwise the last completed one. Weeks always run Monday to Sunday, no
/// matter the locale.
struct WeeklyReviewStats {
    var interval: DateInterval
    var loggedDays: Int
    var daysOnTarget: Int
    var averageCalories: Int
    var averageGlasses: Int
    /// Last minus first weigh-in of the week; nil under two weigh-ins.
    var weightDelta: Double?
    /// The logged day that landed closest under the calorie target.
    var bestDay: Date?
    var entryCount: Int

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func reviewInterval(now: Date = .now) -> DateInterval {
        let calendar = Self.calendar
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: now, duration: 7 * 86_400)
        if calendar.component(.weekday, from: now) == 1 {
            return thisWeek
        }
        return calendar.dateInterval(of: .weekOfYear,
                                     for: thisWeek.start.addingTimeInterval(-86_400)) ?? thisWeek
    }

    static func compute(entries: [FoodEntry], waterDays: [WaterDay],
                        weights: [WeightEntry], target: Int,
                        now: Date = .now) -> WeeklyReviewStats {
        let interval = reviewInterval(now: now)
        func inWeek(_ date: Date) -> Bool {
            date >= interval.start && date < interval.end
        }

        let byDay = Dictionary(grouping: entries.filter { inWeek($0.day) }, by: \.day)
        let daysOnTarget = byDay.values.filter { $0.totalCalories <= target }.count
        let averageCalories = byDay.isEmpty ? 0
            : byDay.values.map(\.totalCalories).reduce(0, +) / byDay.count

        let glasses = waterDays.filter { inWeek($0.day) }.map(\.glasses)
        let averageGlasses = glasses.isEmpty ? 0
            : Int((Double(glasses.reduce(0, +)) / Double(glasses.count)).rounded())

        let weekWeights = weights.filter { inWeek($0.date) }.sorted { $0.date < $1.date }
        let weightDelta = weekWeights.count >= 2
            ? weekWeights.last!.weightKg - weekWeights.first!.weightKg : nil

        // Closest under target wins; when every day overshot, the smallest
        // overshoot is still the best day.
        let bestDay = byDay.min { lhs, rhs in
            score(lhs.value.totalCalories, target: target)
                < score(rhs.value.totalCalories, target: target)
        }?.key

        return WeeklyReviewStats(interval: interval,
                                 loggedDays: byDay.count,
                                 daysOnTarget: daysOnTarget,
                                 averageCalories: averageCalories,
                                 averageGlasses: averageGlasses,
                                 weightDelta: weightDelta,
                                 bestDay: bestDay,
                                 entryCount: byDay.values.map(\.count).reduce(0, +))
    }

    private static func score(_ consumed: Int, target: Int) -> Int {
        consumed <= target ? target - consumed : 10_000 + consumed - target
    }

    var rangeLabel: String {
        let locale = Lingo.shared.language.locale
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale)
        let lastDay = interval.end.addingTimeInterval(-1)
        return "\(interval.start.formatted(style)) – \(lastDay.formatted(style))"
    }
}

/// Teaser card on the progress screen; opens the full review sheet.
struct WeeklyReviewCard: View {
    let stats: WeeklyReviewStats
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wochenrückblick".loc)
                        .font(.fredoka(16, .semibold))
                    Text("%d/7 Tage im Kalorienziel".loc(stats.daysOnTarget))
                        .font(.fredoka(13))
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .bold))
                    .opacity(0.8)
            }
            .foregroundStyle(Theme.onAccent)
            .padding(14)
            .background(
                LinearGradient(colors: [Theme.accent, Theme.accentLight],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            WeeklyReviewSheet(stats: stats)
        }
        .onAppear {
            if LaunchArgs.all.contains("-open-review") {
                showSheet = true
            }
        }
    }
}

struct WeeklyReviewSheet: View {
    let stats: WeeklyReviewStats

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WeeklyReviewPoster(stats: stats)
                statRows
                shareButton
            }
            .padding(16)
        }
        .background(Theme.background)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .presentationDetents([.large])
    }

    private var statRows: some View {
        Card {
            VStack(spacing: 12) {
                statRow("flame.fill", Color.appAccent, "Ø Kalorien pro Tag".loc,
                        stats.loggedDays > 0 ? "\(stats.averageCalories.formatted(.number.locale(Lingo.shared.language.locale))) kcal" : "–")
                Divider()
                statRow("drop.fill", Theme.blue, "Ø Gläser Wasser".loc,
                        "\(stats.averageGlasses)")
                Divider()
                statRow("scalemass.fill", Theme.green, "Gewicht diese Woche".loc,
                        weightLabel)
                Divider()
                statRow("star.fill", Theme.amber, "Bester Tag".loc, bestDayLabel)
                Divider()
                statRow("square.and.pencil", Theme.purple, "Einträge".loc,
                        "\(stats.entryCount)")
            }
        }
    }

    private var weightLabel: String {
        guard let delta = stats.weightDelta else { return "–" }
        let number = abs(delta).formatted(.number.precision(.fractionLength(1))
            .locale(Lingo.shared.language.locale))
        if abs(delta) < 0.05 { return "±0 kg" }
        return delta < 0 ? "-\(number) kg" : "+\(number) kg"
    }

    private var bestDayLabel: String {
        guard let day = stats.bestDay else { return "–" }
        return day.formatted(.dateTime.weekday(.wide).locale(Lingo.shared.language.locale))
    }

    private func statRow(_ symbol: String, _ color: Color,
                         _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title)
                .font(.fredoka(14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.fredoka(16, .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    /// Renders the poster into an image so it can be shared anywhere.
    private var shareButton: some View {
        let renderer = ImageRenderer(content: WeeklyReviewPoster(stats: stats)
            .frame(width: 360))
        renderer.scale = 3
        return Group {
            if let image = renderer.uiImage {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview("Wochenrückblick".loc,
                                                image: Image(uiImage: image))) {
                    Label("Teilen".loc, systemImage: "square.and.arrow.up")
                        .font(.fredoka(16, .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accent.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The shareable hero: week range, days on target, the one-line story.
struct WeeklyReviewPoster: View {
    let stats: WeeklyReviewStats

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Zwäg 🧡")
                    .font(.fredoka(14, .semibold))
                Spacer()
                Text(stats.rangeLabel)
                    .font(.fredoka(13))
                    .opacity(0.85)
            }
            Spacer(minLength: 8)
            Text("\(stats.daysOnTarget)/7")
                .font(.fredoka(64, .semibold))
            Text("Tage im Kalorienziel".loc)
                .font(.fredoka(15))
                .opacity(0.9)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                posterStat("\(stats.loggedDays)", "Tage geloggt".loc)
                posterStat("\(stats.entryCount)", "Einträge".loc)
                posterStat("\(stats.averageGlasses)", "Gläser Ø".loc)
            }
        }
        .foregroundStyle(Theme.onAccent)
        .padding(20)
        .frame(minHeight: 300)
        .background(
            LinearGradient(colors: [Theme.accent, Theme.accentLight],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func posterStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.fredoka(20, .semibold))
            Text(label)
                .font(.fredoka(11))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
