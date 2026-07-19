import SwiftUI
import SwiftData

/// A badge on the Erfolge screen. Everything is derived from local data;
/// only the unlock dates are persisted, so a badge once earned survives a
/// broken streak or deleted entries.
struct Achievement: Identifiable {
    let id: String
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String
}

enum Achievements {
    static var all: [Achievement] {
        var list: [Achievement] = [
            Achievement(id: "first-entry", symbol: "fork.knife", color: Color.appAccent,
                        title: "Erster Eintrag".loc, subtitle: "Logge deine erste Mahlzeit".loc),
            Achievement(id: "entries-100", symbol: "square.and.pencil", color: Theme.purple,
                        title: "100 Einträge".loc, subtitle: "100 Mahlzeiten geloggt".loc),
            Achievement(id: "entries-500", symbol: "medal.fill", color: Theme.deepPurple,
                        title: "500 Einträge".loc, subtitle: "500 Mahlzeiten geloggt".loc),
            Achievement(id: "streak-7", symbol: "flame.fill", color: Color.appAccent,
                        title: "Wochen-Streak".loc, subtitle: "7 Tage am Stück geloggt".loc),
            Achievement(id: "streak-30", symbol: "flame.fill", color: Theme.amber,
                        title: "Monats-Streak".loc, subtitle: "30 Tage am Stück geloggt".loc),
            Achievement(id: "streak-100", symbol: "crown.fill", color: Theme.amber,
                        title: "100er-Streak".loc, subtitle: "100 Tage am Stück geloggt".loc),
            Achievement(id: "fast-first", symbol: "timer", color: Theme.purple,
                        title: "Erstes Fasten".loc, subtitle: "Ein Fastenfenster geschafft".loc),
            Achievement(id: "fast-10", symbol: "moon.stars.fill", color: Theme.deepPurple,
                        title: "Fasten-Profi".loc, subtitle: "10 Fastenfenster geschafft".loc),
            Achievement(id: "water-week", symbol: "drop.fill", color: Theme.blue,
                        title: "Wasser-Woche".loc, subtitle: "7 Tage am Stück das Wasserziel erreicht".loc),
            Achievement(id: "photo-first", symbol: "camera.fill", color: Theme.pink,
                        title: "Erstes Foto".loc, subtitle: "Ein Fortschrittsfoto hinzugefügt".loc),
            Achievement(id: "weigh-10", symbol: "scalemass.fill", color: Theme.green,
                        title: "Auf der Waage".loc, subtitle: "10 Gewichte geloggt".loc),
            Achievement(id: "custom-first", symbol: "carrot.fill", color: Theme.green,
                        title: "Eigenes Lebensmittel".loc, subtitle: "Ein eigenes Lebensmittel angelegt".loc),
            Achievement(id: "favorites-5", symbol: "heart.fill", color: Theme.pink,
                        title: "Rezept-Fan".loc, subtitle: "5 Lieblingsrezepte markiert".loc),
        ]
        #if ZWAEG_BATTLES
        list.append(Achievement(id: "battle-first", symbol: "trophy.fill", color: Theme.amber,
                                title: "Erstes Battle".loc, subtitle: "Einem Battle beigetreten".loc))
        #endif
        return list
    }

    struct Facts {
        var entryCount = 0
        var currentStreak = 0
        var completedFasts = 0
        var weighCount = 0
        var photoCount = 0
        var favoriteCount = 0
        var customFoodCount = 0
        var waterWeek = false
        var battleCount = 0
    }

    static func unlockedIds(_ facts: Facts) -> Set<String> {
        var ids: Set<String> = []
        if facts.entryCount >= 1 { ids.insert("first-entry") }
        if facts.entryCount >= 100 { ids.insert("entries-100") }
        if facts.entryCount >= 500 { ids.insert("entries-500") }
        if facts.currentStreak >= 7 { ids.insert("streak-7") }
        if facts.currentStreak >= 30 { ids.insert("streak-30") }
        if facts.currentStreak >= 100 { ids.insert("streak-100") }
        if facts.completedFasts >= 1 { ids.insert("fast-first") }
        if facts.completedFasts >= 10 { ids.insert("fast-10") }
        if facts.waterWeek { ids.insert("water-week") }
        if facts.photoCount >= 1 { ids.insert("photo-first") }
        if facts.weighCount >= 10 { ids.insert("weigh-10") }
        if facts.customFoodCount >= 1 { ids.insert("custom-first") }
        if facts.favoriteCount >= 5 { ids.insert("favorites-5") }
        if facts.battleCount >= 1 { ids.insert("battle-first") }
        return ids
    }

    /// Seven consecutive days at or above the water goal.
    static func hasWaterWeek(days: [WaterDay], goal: Int) -> Bool {
        let good = Set(days.filter { $0.glasses >= max(1, goal) }.map(\.day))
        let calendar = Calendar.current
        for day in good {
            var run = 1
            var next = day
            while run < 7,
                  let following = calendar.date(byAdding: .day, value: 1, to: next),
                  good.contains(following) {
                next = following
                run += 1
            }
            if run >= 7 { return true }
        }
        return false
    }

    // MARK: - Persisted unlock dates

    private static let key = "achievementDates"

    static func recorded() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let table = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return table
    }

    /// Records anything newly earned and returns the fresh ids (for confetti).
    @discardableResult
    static func sync(_ facts: Facts) -> [String] {
        var table = recorded()
        let fresh = unlockedIds(facts).filter { table[$0] == nil }
        guard !fresh.isEmpty else { return [] }
        for id in fresh { table[id] = .now }
        if let data = try? JSONEncoder().encode(table) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return Array(fresh)
    }
}

struct AchievementsView: View {
    let profile: UserProfile

    @Query private var foodEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]
    @Query private var weights: [WeightEntry]
    @Query private var fasts: [FastingSession]
    @Query private var customFoods: [CustomFood]
    #if ZWAEG_BATTLES
    @Query private var challenges: [Challenge]
    #endif

    @State private var unlockDates = Achievements.recorded()
    @State private var freshIds: Set<String> = []
    @State private var confetti = 0

    private var facts: Achievements.Facts {
        var facts = Achievements.Facts()
        facts.entryCount = foodEntries.count
        facts.currentStreak = Streak.current(loggedDays: Set(foodEntries.map(\.day)))
        facts.completedFasts = fasts.filter { session in
            session.endedAt.map { $0 >= session.goalEnd } == true
        }.count
        facts.weighCount = weights.count
        facts.photoCount = ProgressPhotos.all().count
        facts.favoriteCount = RecipeFavorites.shared.ids.count
        facts.customFoodCount = customFoods.count
        facts.waterWeek = Achievements.hasWaterWeek(days: waterDays,
                                                    goal: profile.waterGoalGlasses)
        #if ZWAEG_BATTLES
        facts.battleCount = challenges.count
        #endif
        return facts
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("%d von %d freigeschaltet".loc(unlockDates.count, Achievements.all.count))
                    .font(.fredoka(14))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Achievements.all) { achievement in
                        badge(achievement)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Erfolge".loc)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            ConfettiBurst(trigger: confetti)
        }
        .onAppear {
            let fresh = Achievements.sync(facts)
            unlockDates = Achievements.recorded()
            if !fresh.isEmpty {
                freshIds = Set(fresh)
                confetti += 1
            }
        }
    }

    private func badge(_ achievement: Achievement) -> some View {
        let unlockedAt = unlockDates[achievement.id]
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlockedAt != nil ? AnyShapeStyle(achievement.color.gradient)
                                            : AnyShapeStyle(Theme.field))
                    .frame(width: 62, height: 62)
                Image(systemName: unlockedAt != nil ? achievement.symbol : "lock.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(unlockedAt != nil ? .white : Color(.systemGray2))
            }
            .scaleEffect(freshIds.contains(achievement.id) ? 1.08 : 1)
            .animation(.snappy(duration: 0.4), value: freshIds)
            Text(achievement.title)
                .font(.fredoka(13, .semibold))
                .foregroundStyle(unlockedAt != nil ? Theme.ink : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(unlockedAt.map(dateLabel) ?? achievement.subtitle)
                .font(.fredoka(10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(unlockedAt != nil ? 1 : 0.75)
    }

    private func dateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year()
            .locale(Lingo.shared.language.locale))
    }
}
