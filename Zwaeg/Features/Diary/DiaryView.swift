import SwiftUI
import SwiftData

struct DiaryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var openMeal: MealType?
    @State private var activity = HealthKitService.DayActivity()

    private var health: HealthKitService { HealthKitService.shared }

    private var dayEntries: [FoodEntry] {
        allEntries.filter { $0.day == selectedDay }
    }

    private var consumed: Int {
        dayEntries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    intakeCard
                    HStack(spacing: 16) {
                        stepsCard
                        waterCard
                    }
                    weekStrip
                    ForEach(MealType.allCases) { meal in
                        mealCard(meal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openMeal) { meal in
                AddFoodView(day: selectedDay, meal: meal)
            }
            .task(id: selectedDay) {
                await refreshActivity()
            }
            .onAppear {
                if let flagIndex = CommandLine.arguments.firstIndex(of: "-add-food") {
                    let next = CommandLine.arguments.indices.contains(flagIndex + 1)
                        ? CommandLine.arguments[flagIndex + 1] : ""
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        openMeal = MealType(rawValue: next) ?? .breakfast
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return "Guten Morgen"
        case 11..<18: return "Guten Tag"
        default: return "Guten Abend"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            MascotAvatar(size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                Text(profile.name.isEmpty ? "Hallo!" : "Hallo \(profile.name)")
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            NavigationLink {
                RemindersPlaceholderView()
            } label: {
                Image(systemName: "bell")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.ink.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    /// Consecutive days with at least one logged food, ending today or yesterday.
    private var streak: Int {
        let loggedDays = Set(allEntries.map(\.day))
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        if !loggedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while loggedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Daily intake (peach card, slider look)

    private var progress: Double {
        guard profile.dailyCalorieTarget > 0 else { return 0 }
        return min(1, Double(consumed) / Double(profile.dailyCalorieTarget))
    }

    private var intakeCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "chart.pie.fill")
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 34, height: 34)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text("Tagesbilanz")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Tag \(max(1, streak))")
                    .font(.fredoka(12, .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.ink, in: Capsule())
                    .foregroundStyle(Theme.onAccent)
            }

            HStack {
                Text("Fortschritt")
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(consumed) / \(profile.dailyCalorieTarget) kcal")
                    .font(.fredoka(12, .semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.35), Theme.accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, geo.size.width * progress))
                    Circle()
                        .fill(Theme.card)
                        .stroke(Theme.accent, lineWidth: 5)
                        .frame(width: 19, height: 19)
                        .offset(x: max(0, geo.size.width * progress - 19))
                        .animation(.spring(duration: 0.5), value: progress)
                }
            }
            .frame(height: 14)
        }
        .padding(16)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Steps & water

    private var stepsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(red: 0.48, green: 0.42, blue: 0.93).gradient,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                if health.isConnected {
                    Text("\(activity.steps)")
                        .font(.fredoka(22, .semibold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("Schritte heute")
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                } else if HealthKitService.isAvailable {
                    Button {
                        Task {
                            await health.requestAuthorization()
                            await refreshActivity()
                        }
                    } label: {
                        Text("Verbinden")
                            .font(.fredoka(12, .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.accentSoft, in: Capsule())
                            .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    Text("Schritte aus Health")
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("–")
                        .font(.fredoka(22, .semibold))
                    Text("Schritte")
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var waterEntry: WaterDay? {
        waterDays.first { $0.day == selectedDay }
    }

    private var waterCard: some View {
        let glasses = waterEntry?.glasses ?? 0
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(red: 0.24, green: 0.64, blue: 1.0).gradient,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer()
                    Button {
                        addWater(-1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.fredoka(12, .semibold))
                            .frame(width: 26, height: 26)
                            .background(Theme.field, in: Circle())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(glasses == 0)
                    Button {
                        addWater(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.fredoka(12, .semibold))
                            .frame(width: 26, height: 26)
                            .background(Theme.accent, in: Circle())
                            .foregroundStyle(Theme.onAccent)
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(glasses)")
                        .font(.fredoka(22, .semibold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("Glas")
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
                Text("Wasser trinken")
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addWater(_ delta: Int) {
        withAnimation(.snappy) {
            if let entry = waterEntry {
                entry.glasses = max(0, entry.glasses + delta)
            } else if delta > 0 {
                context.insert(WaterDay(day: selectedDay, glasses: delta))
            }
        }
    }

    // MARK: - Week strip (transparent, selected day in coral square)

    private var lastSevenDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(lastSevenDays, id: \.self) { day in
                let isSelected = day == selectedDay
                Button {
                    withAnimation(.snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.fredoka(12, isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.appAccent : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(isSelected ? Theme.onAccent : Theme.ink)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(.clear),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Meals

    private func mealGradient(_ meal: MealType) -> LinearGradient {
        let colors: [Color]
        switch meal {
        case .breakfast: colors = [Color(red: 1.0, green: 0.72, blue: 0.4), Color(red: 0.99, green: 0.85, blue: 0.55)]
        case .lunch: colors = [Color(red: 0.55, green: 0.83, blue: 0.5), Color(red: 0.73, green: 0.91, blue: 0.6)]
        case .dinner: colors = [Color(red: 0.52, green: 0.48, blue: 0.95), Color(red: 0.7, green: 0.62, blue: 0.98)]
        case .snack: colors = [Color(red: 1.0, green: 0.55, blue: 0.62), Color(red: 1.0, green: 0.72, blue: 0.68)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rough per-meal share of the daily budget, like the mockup's "488 / 536 kcal".
    private func mealBudget(_ meal: MealType) -> Int {
        let share: Double
        switch meal {
        case .breakfast: share = 0.25
        case .lunch: share = 0.35
        case .dinner: share = 0.30
        case .snack: share = 0.10
        }
        return Int((Double(profile.dailyCalorieTarget) * share).rounded())
    }

    private func mealCard(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.meal == meal }
        let kcal = entries.reduce(0) { $0 + $1.calories }
        return Button {
            openMeal = meal
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: meal.symbol)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(mealGradient(meal),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.label)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(kcal) / \(mealBudget(meal)) kcal")
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Text("Add")
                        .font(.fredoka(15, .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.accentSoft, in: Capsule())
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func refreshActivity() async {
        guard health.isConnected else { return }
        activity = await health.activity(for: selectedDay)
    }
}
