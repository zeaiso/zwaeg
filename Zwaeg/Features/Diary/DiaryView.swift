import SwiftUI
import SwiftData

struct DiaryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]
    @Query private var dayNotes: [DayNote]
    @Query(sort: \FastingSession.start, order: .reverse) private var fastingSessions: [FastingSession]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var openMeal: MealType?
    @State private var openFasting = false
    @State private var activity = HealthKitService.DayActivity()
    @State private var weightSaveTask: Task<Void, Never>?

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
                    summaryCard
                    HStack(spacing: 16) {
                        stepsCard
                        waterCard
                    }
                    weekStrip
                    ForEach(MealType.allCases) { meal in
                        mealCard(meal)
                    }
                    fastingCard
                    weightCard
                    moodCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .defaultScrollAnchor(CommandLine.arguments.contains("-scroll-bottom") ? .bottom : .top)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openMeal) { meal in
                AddFoodView(day: selectedDay, meal: meal)
            }
            .navigationDestination(isPresented: $openFasting) {
                FastingView()
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
                if CommandLine.arguments.contains("-open-fasting") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        openFasting = true
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return "Guten Morgen".loc
        case 11..<18: return "Guten Tag".loc
        default: return "Guten Abend".loc
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BuddyView(buddy: profile.buddy, size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                Text(profile.name.isEmpty ? "Hallo!".loc : "\("Hallo".loc) \(profile.name)")
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(Color.appAccent)
                Text("\(streak)")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Theme.card, in: Capsule())
            .shadow(color: Theme.ink.opacity(0.05), radius: 6, y: 2)
            NavigationLink {
                RemindersView()
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

    // MARK: - Summary (peach card: eaten, remaining ring, burned, macro bars)

    private var progress: Double {
        guard profile.dailyCalorieTarget > 0 else { return 0 }
        return min(1, Double(consumed) / Double(profile.dailyCalorieTarget))
    }

    private var remaining: Int {
        profile.dailyCalorieTarget - consumed
    }

    /// 45/25/30 carb/protein/fat energy split (4/4/9 kcal per gram).
    private var macroTargets: (carbs: Int, protein: Int, fat: Int) {
        let kcal = Double(profile.dailyCalorieTarget)
        return (Int((kcal * 0.45 / 4).rounded()),
                Int((kcal * 0.25 / 4).rounded()),
                Int((kcal * 0.30 / 9).rounded()))
    }

    private var summaryCard: some View {
        let carbs = dayEntries.reduce(0.0) { $0 + $1.carbsG }
        let protein = dayEntries.reduce(0.0) { $0 + $1.proteinG }
        let fat = dayEntries.reduce(0.0) { $0 + $1.fatG }
        let targets = macroTargets
        return VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.pie.fill")
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 34, height: 34)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text("Tagesbilanz".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Ziel %@ kcal".loc(profile.dailyCalorieTarget.formatted()))
                    .font(.fredoka(12, .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                summaryStat(consumed, label: "Gegessen".loc, symbol: "fork.knife",
                            color: Color.appAccent)
                Spacer()
                remainingRing
                Spacer()
                summaryStat(activity.activeKcal, label: "Verbrannt".loc, symbol: "flame.fill",
                            color: Color(red: 0.98, green: 0.55, blue: 0.2))
            }

            HStack(spacing: 12) {
                macroBar("Kohlenhydrate".loc, eaten: carbs, target: targets.carbs,
                         color: Color(red: 0.98, green: 0.62, blue: 0.24))
                macroBar("Protein".loc, eaten: protein, target: targets.protein,
                         color: Color(red: 0.52, green: 0.48, blue: 0.95))
                macroBar("Fett".loc, eaten: fat, target: targets.fat,
                         color: Color(red: 0.45, green: 0.76, blue: 0.42))
            }
        }
        .padding(16)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var remainingRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 11)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.35), Theme.accent],
                                   startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
            VStack(spacing: 1) {
                Text("\(abs(remaining))")
                    .font(.fredoka(26, .semibold))
                    .foregroundStyle(remaining < 0 ? Color.appAccent : Theme.ink)
                    .contentTransition(.numericText())
                Text(remaining < 0 ? "kcal über".loc : "kcal übrig".loc)
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 118, height: 118)
    }

    private func summaryStat(_ value: Int, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.fredoka(12, .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(Theme.card, in: Circle())
            Text("\(value)")
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 64)
    }

    private func macroBar(_ label: String, eaten: Double, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.fredoka(11, .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.7))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * min(1, eaten / Double(max(1, target)))))
                        .animation(.snappy, value: eaten)
                }
            }
            .frame(height: 6)
            Text("\(Int(eaten.rounded())) / \(target) g")
                .font(.fredoka(11, .semibold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("Schritte heute".loc)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                } else if HealthKitService.isAvailable {
                    Button {
                        Task {
                            await health.requestAuthorization()
                            await refreshActivity()
                        }
                    } label: {
                        Text("Verbinden".loc)
                            .font(.fredoka(12, .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.accentSoft, in: Capsule())
                            .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    Text("Schritte aus Health".loc)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("–")
                        .font(.fredoka(22, .semibold))
                    Text("Schritte".loc)
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
                    Text("/ \(profile.waterGoalGlasses) \("Glas".loc)")
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.field)
                        Capsule()
                            .fill(Color(red: 0.24, green: 0.64, blue: 1.0))
                            .frame(width: max(0, geo.size.width * min(1, Double(glasses) / Double(max(1, profile.waterGoalGlasses)))))
                            .animation(.snappy, value: glasses)
                    }
                }
                .frame(height: 6)
                Text("Ziel: %@ Liter".loc(String(format: "%.1f", Double(profile.waterGoalGlasses) * 0.25)))
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

    // MARK: - Fasting

    private var activeFast: FastingSession? {
        fastingSessions.first { $0.isActive }
    }

    private var fastingCard: some View {
        Button {
            openFasting = true
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color(red: 0.2, green: 0.68, blue: 0.62).gradient,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fasten".loc)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        if let fast = activeFast {
                            Text("Läuft bis %@ · %@".loc(
                                fast.goalEnd.formatted(date: .omitted, time: .shortened),
                                fast.plan.label))
                                .font(.fredoka(12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Intervallfasten starten".loc)
                                .font(.fredoka(12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if activeFast != nil {
                        Text("Läuft".loc)
                            .font(.fredoka(15, .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Theme.accent.gradient, in: Capsule())
                            .foregroundStyle(Theme.onAccent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.fredoka(14, .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weight quick log

    private var latestWeight: WeightEntry? {
        weights.last
    }

    private var weightDeltaLabel: String {
        guard weights.count >= 2 else { return "Kurz antippen zum Loggen".loc }
        let delta = weights[weights.count - 1].weightKg - weights[weights.count - 2].weightKg
        if abs(delta) < 0.05 { return "Unverändert seit letztem Mal".loc }
        return "%@ kg seit letztem Mal".loc(String(format: "%+.1f", delta))
    }

    private var weightCard: some View {
        let current = latestWeight?.weightKg ?? profile.weightKg
        return Card {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color(red: 0.55, green: 0.78, blue: 0.45).gradient,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", current))
                            .font(.fredoka(19, .semibold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("kg")
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    Text(weightDeltaLabel)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    adjustWeight(-0.1)
                } label: {
                    Image(systemName: "minus")
                        .font(.fredoka(13, .semibold))
                        .frame(width: 32, height: 32)
                        .background(Theme.field, in: Circle())
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                Button {
                    adjustWeight(0.1)
                } label: {
                    Image(systemName: "plus")
                        .font(.fredoka(13, .semibold))
                        .frame(width: 32, height: 32)
                        .background(Theme.accent, in: Circle())
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Steps today's weight by a tenth of a kilo; the HealthKit write is
    /// debounced so tapping five times saves one sample, not five.
    private func adjustWeight(_ delta: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let newValue = min(300, max(30, (latestWeight?.weightKg ?? profile.weightKg) + delta))
        withAnimation(.snappy) {
            if let entry = latestWeight, calendar.startOfDay(for: entry.date) == today {
                entry.weightKg = newValue
            } else {
                context.insert(WeightEntry(weightKg: newValue))
            }
            profile.weightKg = newValue
            profile.recalculateTarget()
        }
        weightSaveTask?.cancel()
        weightSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await HealthKitService.shared.saveWeight(newValue)
        }
    }

    // MARK: - Mood note

    private var dayNote: DayNote? {
        dayNotes.first { $0.day == selectedDay }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { dayNote?.text ?? "" },
            set: { newValue in dayNote?.text = newValue })
    }

    private var moodCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color(red: 1.0, green: 0.55, blue: 0.62).gradient,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wie war dein Tag?".loc)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Stimmung festhalten".loc)
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Mood.allCases) { mood in
                        moodButton(mood)
                    }
                }
                if dayNote?.mood != nil {
                    TextField("Notiz zum Tag (optional)".loc, text: noteBinding, axis: .vertical)
                        .font(.fredoka(14))
                        .padding(12)
                        .background(Theme.field.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        let isSelected = dayNote?.mood == mood
        return Button {
            setMood(mood)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mood.symbol)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(isSelected ? Theme.onAccent : Color(.systemGray))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? AnyShapeStyle(Theme.accent.gradient)
                                           : AnyShapeStyle(Theme.field.opacity(0.6)),
                                in: Circle())
                Text(mood.label)
                    .font(.fredoka(10, isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.appAccent : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func setMood(_ mood: Mood) {
        withAnimation(.snappy) {
            if let note = dayNote {
                note.mood = note.mood == mood ? nil : mood
            } else {
                context.insert(DayNote(day: selectedDay, mood: mood))
            }
        }
    }

    private func refreshActivity() async {
        guard health.isConnected else { return }
        activity = await health.activity(for: selectedDay)
    }
}
