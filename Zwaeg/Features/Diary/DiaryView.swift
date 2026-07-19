import SwiftUI
import SwiftData
import WidgetKit

struct DiaryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]
    @Query private var dayNotes: [DayNote]
    @Query(sort: \FastingSession.start, order: .reverse) private var fastingSessions: [FastingSession]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    /// One route enum so the stack has exactly one navigationDestination;
    /// several stacked destination modifiers broke touch delivery on iOS 17.
    private enum Route: Hashable, Identifiable {
        case meal(MealType)
        case details
        case reminders
        case challenges
        case recipe(Recipe)

        var id: Self { self }
    }

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var route: Route?
    @State private var showCalendar = false
    @State private var activity = HealthKitService.DayActivity()
    @State private var weekSteps: [Int] = []
    @State private var weightSaveTask: Task<Void, Never>?
    @State private var confettiTrigger = 0
    @State private var buddyBounced = false

    private var health: HealthKitService { HealthKitService.shared }

    private var dayEntries: [FoodEntry] {
        allEntries.filter { $0.day == selectedDay }
    }

    private var consumed: Int {
        dayEntries.totalCalories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if Self.milestones.contains(streak) {
                        milestoneCard
                    }
                    if streakWasFrozen {
                        streakFrozenCard
                    }
                    summaryCard
                    HStack(spacing: 16) {
                        stepsCard
                        weightCard
                    }
                    ForEach(visibleMeals) { meal in
                        mealCard(meal)
                    }
                    if !recipeSuggestions.isEmpty {
                        suggestionsCard
                    }
                    waterCard
                    moodCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
            .background(Theme.background)
            .tabBarClearance()
            .overlay {
                ConfettiBurst(trigger: confettiTrigger)
                    .allowsHitTesting(false)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { route in
                switch route {
                case .meal(let meal):
                    AddFoodView(day: selectedDay, meal: meal)
                case .details:
                    DayDetailView(day: selectedDay, profile: profile)
                case .reminders:
                    RemindersView()
                case .challenges:
                    ChallengesView(profile: profile)
                case .recipe(let recipe):
                    RecipeDetailView(recipe: recipe)
                }
            }
            .sheet(isPresented: $showCalendar) {
                CalendarSheet(selectedDay: $selectedDay)
            }
            .task(id: selectedDay) {
                await refreshActivity()
                syncLiveActivity()
            }
            .onChange(of: allEntries.count) {
                syncLiveActivity()
            }
            .onChange(of: fastingSessions.filter(\.isActive).count) {
                syncLiveActivity()
            }
            .onAppear {
                if let flagIndex = LaunchArgs.all.firstIndex(of: "-add-food") {
                    let next = LaunchArgs.all.indices.contains(flagIndex + 1)
                        ? LaunchArgs.all[flagIndex + 1] : ""
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        route = .meal(MealType(rawValue: next) ?? .breakfast)
                    }
                }
                if LaunchArgs.all.contains("-open-challenges") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        route = .challenges
                    }
                }
                if LaunchArgs.all.contains("-open-calendar") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        showCalendar = true
                    }
                }
                if LaunchArgs.all.contains("-open-details") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        route = .details
                    }
                }
                celebrateStreakIfNeeded()
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
            ZStack(alignment: .bottomTrailing) {
                BuddyPoseView(buddy: profile.buddy, size: 46, pose: buddyPose)
                if let mood = buddyMood {
                    Image(systemName: mood.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(mood.color)
                        .frame(width: 18, height: 18)
                        .background(Theme.card, in: Circle())
                        .shadow(color: Theme.shadow.opacity(0.15), radius: 2, y: 1)
                        .offset(x: 3, y: 3)
                }
            }
            .scaleEffect(buddyBounced ? 1 : 0.6)
            .rotationEffect(.degrees(buddyBounced ? 0 : -14))
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.15)) {
                    buddyBounced = true
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                Text(profile.name.isEmpty ? "Hallo!".loc : profile.name)
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button {
                route = .challenges
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(Color.appAccent)
                    Text("\(streak)")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    if streakFreezes > 0 {
                        Image(systemName: "snowflake")
                            .font(.fredoka(12, .semibold))
                            .foregroundStyle(Theme.freezeBlue)
                            .padding(.leading, 3)
                        Text("\(streakFreezes)")
                            .font(.fredoka(14, .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 42)
                .background(Theme.card, in: Capsule())
                .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            Button {
                showCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            Button {
                route = .reminders
            } label: {
                Image(systemName: "bell")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Streak milestones

    private static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]

    @AppStorage("celebratedStreak") private var celebratedStreak = 0
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""

    private var milestoneCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.fredoka(21, .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("%d Tage am Stück!".loc(streak))
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.white)
                Text("Tage-Streak".loc)
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            BuddyPoseView(buddy: profile.buddy, size: 44, pose: .party)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.accentLight, Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 5)
    }

    /// Shown while yesterday hangs on a freeze: the streak survived, and
    /// logging today keeps it going.
    private var streakFrozenCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake")
                .font(.fredoka(21, .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Streak gerettet!".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(.white)
                Text("Ein Freeze hat gestern überbrückt. Iss heute etwas, damit es weitergeht.".loc)
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.freezeBlue, Color(red: 0.2, green: 0.5, blue: 0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.freezeBlue.opacity(0.35), radius: 12, y: 5)
    }

    /// Fires confetti once per newly reached milestone.
    private func celebrateStreakIfNeeded() {
        guard let reached = Self.milestones.last(where: { streak >= $0 }),
              reached > celebratedStreak else { return }
        celebratedStreak = reached
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            confettiTrigger += 1
        }
    }

    /// Motion pose of the header buddy for the selected day.
    private var buddyPose: BuddyPose {
        if dayEntries.isEmpty { return .sleeping }
        if remaining >= 0 { return .happy }
        return .over
    }

    /// Badge on the header buddy reacting to the selected day:
    /// sleeping while nothing is logged, thumbs up on track, alert when over.
    private var buddyMood: (symbol: String, color: Color)? {
        if dayEntries.isEmpty { return ("zzz", Color(.systemGray)) }
        if remaining >= 0 { return ("hand.thumbsup.fill", Theme.positive) }
        return ("exclamationmark", Color.appAccent)
    }

    private var loggedDays: Set<Date> {
        Set(allEntries.map(\.day))
    }

    /// Consecutive days with at least one logged food, ending today or
    /// yesterday; banked freezes bridge missed days.
    private var streak: Int {
        Streak.current(loggedDays: loggedDays)
    }

    private var streakFreezes: Int {
        Streak.availableFreezes(loggedDays: loggedDays)
    }

    /// Yesterday was only survived thanks to a freeze; worth a banner.
    private var streakWasFrozen: Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                                    to: Calendar.current.startOfDay(for: .now))
        else { return false }
        return Streak.frozenDays().contains(yesterday)
    }

    // MARK: - Summary (peach card: eaten, remaining ring, burned, macro bars)

    private var progress: Double {
        guard profile.dailyCalorieTarget > 0 else { return 0 }
        return min(1, Double(consumed) / Double(profile.dailyCalorieTarget))
    }

    private var remaining: Int {
        profile.dailyCalorieTarget - consumed
    }

    /// Gram targets from the profile's energy split (4/4/9 kcal per gram).
    private var macroTargets: (carbs: Int, protein: Int, fat: Int) {
        let kcal = Double(profile.dailyCalorieTarget)
        return (Int((kcal * Double(profile.carbSharePercent) / 100 / 4).rounded()),
                Int((kcal * Double(profile.proteinSharePercent) / 100 / 4).rounded()),
                Int((kcal * Double(profile.fatSharePercent) / 100 / 9).rounded()))
    }

    // MARK: - Recipe suggestions

    /// Up to three recipes that still fit today's remaining calories, leaning
    /// high-protein while the protein target is far away. Stable per day (the
    /// score carries a date-seeded jitter), so the card doesn't reshuffle.
    private var recipeSuggestions: [Recipe] {
        guard selectedDay == Calendar.current.startOfDay(for: .now),
              Calendar.current.component(.hour, from: .now) >= 11
                || LaunchArgs.all.contains("-demo-suggestions"),
              remaining >= 150 else { return [] }
        let target = Double(remaining)
        let proteinEaten = dayEntries.totalProtein
        let needsProtein = Double(macroTargets.protein) - proteinEaten > 20
        let daySeed = UInt64(selectedDay.timeIntervalSince1970)
        func score(_ recipe: Recipe) -> Double {
            // A meal that uses the budget well beats a token snack.
            var value = -abs(Double(recipe.kcal) - target * 0.8)
            if needsProtein && recipe.isHighProtein { value += 150 }
            value += Double((Self.stableHash(recipe.id) ^ daySeed) % 60)
            return value
        }
        return Array(RecipeStore.all
            .filter { Double($0.kcal) <= target && Double($0.kcal) >= target * 0.3 }
            .sorted { score($0) > score($1) }
            .prefix(3))
    }

    /// String.hashValue changes per launch; day-stable jitter needs this.
    private static func stableHash(_ string: String) -> UInt64 {
        string.unicodeScalars.reduce(5381 as UInt64) { ($0 &<< 5) &+ $0 &+ UInt64($1.value) }
    }

    private var suggestionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color(red: 0.98, green: 0.55, blue: 0.2).gradient,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Was passt heute noch?".loc)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Noch %d kcal frei".loc(remaining))
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recipeSuggestions) { recipe in
                            suggestionTile(recipe)
                        }
                    }
                }
            }
        }
    }

    private func suggestionTile(_ recipe: Recipe) -> some View {
        Button {
            route = .recipe(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let photo = recipe.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(recipe.emoji)
                            .font(.system(size: 40))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.field.opacity(0.6))
                    }
                }
                .frame(width: 148, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(recipe.name)
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text("%d kcal · %d Min.".loc(recipe.kcal, recipe.minutes))
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 148, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        let carbs = dayEntries.totalCarbs
        let protein = dayEntries.totalProtein
        let fat = dayEntries.totalFat
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
                Button {
                    route = .details
                } label: {
                    HStack(spacing: 3) {
                        Text("Details".loc)
                            .font(.fredoka(13, .semibold))
                        Image(systemName: "chevron.forward")
                            .font(.fredoka(11, .semibold))
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
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
                         color: Theme.purple)
                macroBar("Fett".loc, eaten: fat, target: targets.fat,
                         color: Color(red: 0.45, green: 0.76, blue: 0.42))
            }
        }
        .padding(16)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.accentSoft)
                Circle()
                    .fill(Theme.decorStrong)
                    .frame(width: 190, height: 190)
                    .offset(x: 70, y: -80)
                Circle()
                    .fill(Theme.decorSoft)
                    .frame(width: 90, height: 90)
                    .offset(x: -230, y: 150)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // clipShape only clips drawing, not hit testing: the circle overflowing
            // the card top would otherwise swallow taps on the header buttons above.
            .allowsHitTesting(false)
        }
    }

    private var remainingRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 11)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Theme.accentLight, Theme.accent],
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
                    Capsule().fill(Theme.track)
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
                    .background(Theme.deepPurple.gradient,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                if health.isConnected {
                    Text("\(activity.steps)")
                        .font(.fredoka(22, .semibold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("Schritte heute".loc)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                    stepsChart
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

    /// Mini week chart like the Health app, today highlighted.
    @ViewBuilder
    private var stepsChart: some View {
        if weekSteps.count == 7 {
            let top = max(1, weekSteps.max() ?? 1)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weekSteps.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == 6 ? Theme.deepPurple
                                         : Theme.deepPurple.opacity(0.30))
                        .frame(height: max(4, 26 * CGFloat(value) / CGFloat(top)))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 26, alignment: .bottom)
            .padding(.top, 2)
        }
    }

    private var waterEntry: WaterDay? {
        waterDays.first { $0.day == selectedDay }
    }

    private var waterCard: some View {
        let glasses = waterEntry?.glasses ?? 0
        let goal = max(1, profile.waterGoalGlasses)
        let blue = Theme.blue
        let columns = [GridItem(.adaptive(minimum: 36), spacing: 8)]
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(blue.gradient,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", Double(glasses) * 0.25))
                                .font(.fredoka(19, .semibold))
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())
                            Text("l")
                                .font(.fredoka(13))
                                .foregroundStyle(.secondary)
                        }
                        Text("Ziel: %@ Liter".loc(String(format: "%.1f", Double(goal) * 0.25)))
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        addWater(-1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.fredoka(13, .semibold))
                            .frame(width: 32, height: 32)
                            .background(Theme.field, in: Circle())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(glasses == 0)
                    Button {
                        addWater(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.fredoka(13, .semibold))
                            .frame(width: 32, height: 32)
                            .background(Theme.accent, in: Circle())
                            .foregroundStyle(Theme.onAccent)
                    }
                    .buttonStyle(.plain)
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<max(goal, glasses), id: \.self) { index in
                        Button {
                            setWater(index < glasses ? index : index + 1)
                        } label: {
                            Image(systemName: index < glasses ? "drop.fill" : "drop")
                                .font(.fredoka(24, .semibold))
                                .foregroundStyle(index < glasses ? blue : Color(.systemGray4))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background((index < glasses ? blue.opacity(0.10) : Theme.field.opacity(0.4)),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        addWater(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(blue)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(blue.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addWater(_ delta: Int) {
        setWater(max(0, (waterEntry?.glasses ?? 0) + delta))
    }

    /// Tapping the nth glass fills up to n; tapping the last filled one empties it again.
    private func setWater(_ glasses: Int) {
        let previous = waterEntry?.glasses ?? 0
        if previous < profile.waterGoalGlasses && glasses >= profile.waterGoalGlasses {
            confettiTrigger += 1
        }
        withAnimation(.snappy) {
            if let entry = waterEntry {
                entry.glasses = max(0, glasses)
            } else if glasses > 0 {
                context.insert(WaterDay(day: selectedDay, glasses: glasses))
            }
        }
        // A freshly inserted WaterDay is not in the @Query array yet, so
        // pass today's count along instead of re-reading it.
        let isToday = selectedDay == Calendar.current.startOfDay(for: .now)
        syncLiveActivity(todayGlasses: isToday ? max(0, glasses) : nil)
    }

    // MARK: - Meals

    private func mealGradient(_ meal: MealType) -> LinearGradient {
        let colors: [Color]
        switch meal {
        case .breakfast: colors = [Color(red: 1.0, green: 0.72, blue: 0.4), Color(red: 0.99, green: 0.85, blue: 0.55)]
        case .lunch: colors = [Color(red: 0.55, green: 0.83, blue: 0.5), Color(red: 0.73, green: 0.91, blue: 0.6)]
        case .dinner: colors = [Theme.purple, Color(red: 0.7, green: 0.62, blue: 0.98)]
        case .snack: colors = [Theme.pink, Color(red: 1.0, green: 0.72, blue: 0.68)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The user's chosen meals, plus disabled ones that still hold entries
    /// on the selected day — logged food never disappears.
    private var visibleMeals: [MealType] {
        let enabled = MealPlan.enabled(from: enabledMealsRaw)
        return MealType.allCases.filter { meal in
            enabled.contains(meal) || dayEntries.contains { $0.meal == meal }
        }
    }

    /// Per-meal share of the daily budget, spread over the enabled meals.
    private func mealBudget(_ meal: MealType) -> Int {
        let share = MealPlan.budgetShare(meal, enabled: MealPlan.enabled(from: enabledMealsRaw))
        return Int((Double(profile.dailyCalorieTarget) * share).rounded())
    }

    private func mealCard(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.meal == meal }
        let kcal = entries.totalCalories
        let mealProgress = min(1, Double(kcal) / Double(max(1, mealBudget(meal))))
        let hidden = !MealPlan.enabled(from: enabledMealsRaw).contains(meal)
        return Button {
            route = .meal(meal)
        } label: {
            Card {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Theme.field, lineWidth: 3.5)
                        Circle()
                            .trim(from: 0, to: mealProgress)
                            .stroke(mealGradient(meal),
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.5), value: mealProgress)
                        Image(systemName: meal.symbol)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(mealGradient(meal), in: Circle())
                    }
                    .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(meal.label)
                                .font(.fredoka(17, .semibold))
                                .foregroundStyle(Theme.ink)
                            if hidden {
                                Image(systemName: "eye.slash.fill")
                                    .font(.fredoka(11, .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        // A meal turned off in the settings stays visible on
                        // days that still hold entries; say so instead of a
                        // budget it no longer has.
                        Text(hidden ? "Ausgeblendet — Tag hat noch Einträge".loc
                                    : "\(kcal) / \(mealBudget(meal)) kcal")
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                        if !entries.isEmpty {
                            Text(entries.map(\.name).joined(separator: ", "))
                                .font(.fredoka(11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.fredoka(16, .semibold))
                        .frame(width: 38, height: 38)
                        .background(Theme.accentSoft, in: Circle())
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(hidden ? 0.72 : 1)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(red: 0.55, green: 0.78, blue: 0.45).gradient,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer()
                    Button {
                        adjustWeight(-0.1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.fredoka(12, .semibold))
                            .frame(width: 26, height: 26)
                            .background(Theme.field, in: Circle())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                    Button {
                        adjustWeight(0.1)
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
                    Text(String(format: "%.1f", current))
                        .font(.fredoka(22, .semibold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
                Text(weightDeltaLabel)
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

    private var moodCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Theme.pink.gradient,
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
        weekSteps = await health.weekSteps(endingAt: selectedDay)
    }

    /// Mirrors today's numbers onto the lock screen / Dynamic Island.
    private func syncLiveActivity(todayGlasses: Int? = nil) {
        let today = Calendar.current.startOfDay(for: .now)
        let todayEntries = allEntries.filter { $0.day == today }
        DayActivityController.sync(
            consumed: todayEntries.totalCalories,
            target: profile.dailyCalorieTarget,
            burned: selectedDay == today ? activity.activeKcal : 0,
            glasses: todayGlasses ?? waterDays.first { $0.day == today }?.glasses ?? 0,
            waterGoal: profile.waterGoalGlasses,
            fastingEnd: fastingSessions.first { $0.isActive }?.goalEnd)
        // Outside DayActivityController.sync: that bails when Live
        // Activities are off, and the streak widget must update anyway.
        StreakSnapshotStore.save(.init(
            days: streak,
            freezes: streakFreezes,
            loggedToday: !todayEntries.isEmpty,
            label: "Tage-Streak".loc,
            midnight: Themer.shared.look == .midnight))
        WidgetCenter.shared.reloadTimelines(ofKind: "ZwaegStreakWidget")
        // Mirror eaten totals into Apple Health; the edited day too, in
        // case an older diary day was just changed.
        let syncDays = Set([today, selectedDay])
        let entriesByDay = allEntries.reduce(into: [Date: [FoodEntry]]()) {
            $0[$1.day, default: []].append($1)
        }
        Task {
            for day in syncDays {
                let entries = entriesByDay[day] ?? []
                await HealthKitService.shared.saveNutrition(
                    day: day,
                    kcal: Double(entries.totalCalories),
                    proteinG: entries.totalProtein,
                    carbsG: entries.totalCarbs,
                    fatG: entries.totalFat)
            }
        }
    }
}

/// Month calendar to jump to any diary day; picking a date closes the sheet.
private struct CalendarSheet: View {
    @Binding var selectedDay: Date

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Theme.field)
                .frame(width: 44, height: 5)
                .padding(.top, 10)
            Text("Kalender".loc)
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
            DatePicker("", selection: Binding(
                get: { selectedDay },
                set: { newValue in
                    selectedDay = Calendar.current.startOfDay(for: newValue)
                    dismiss()
                }), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.appAccent)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .background(Theme.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
