import SwiftData
import SwiftUI

/// One trackable achievement with a point reward.
struct ChallengeState: Identifiable {
    let id: String
    let emoji: String
    let symbol: String
    let title: String
    let points: Int
    let progress: Int
    let target: Int

    var done: Bool { progress >= target }
}

/// Item sets in the buddy studios that unlock with challenge points.
enum UnlockSet: Int {
    case neonHair = 40
    case specialExtras = 60
    case piratLook = 80
    case ninjaLook = 100
    case monsterSpecials = 150

    var requiredPoints: Int { rawValue }
}

/// Computes challenges and points live from the logged data, so they are
/// always consistent and never need separate persistence.
enum ChallengeEngine {
    static func evaluate(entries: [FoodEntry], fasts: [FastingSession],
                         waterDays: [WaterDay], weights: [WeightEntry],
                         notes: [DayNote], profile: UserProfile) -> [ChallengeState] {
        let streak = longestStreak(entries: entries)
        let entryCount = entries.count
        let goodFasts = fasts.filter { session in
            guard let end = session.endedAt else { return false }
            return end >= session.goalEnd
        }.count
        let waterGoalDays = waterDays.filter { $0.glasses >= profile.waterGoalGlasses }.count
        let customBuddy = ["custom", "monster"].contains(profile.buddy.kind) ? 1 : 0

        return [
            ChallengeState(id: "first-entry", emoji: "🎉", symbol: "fork.knife",
                           title: "Ersten Eintrag loggen".loc, points: 10,
                           progress: min(entryCount, 1), target: 1),
            ChallengeState(id: "entries-50", emoji: "📝", symbol: "list.bullet",
                           title: "%d Einträge loggen".loc(50), points: 25,
                           progress: entryCount, target: 50),
            ChallengeState(id: "entries-200", emoji: "🗂️", symbol: "tray.full.fill",
                           title: "%d Einträge loggen".loc(200), points: 50,
                           progress: entryCount, target: 200),
            ChallengeState(id: "entries-500", emoji: "💪", symbol: "trophy.fill",
                           title: "%d Einträge loggen".loc(500), points: 100,
                           progress: entryCount, target: 500),
            ChallengeState(id: "streak-3", emoji: "🔥", symbol: "flame.fill",
                           title: "%d-Tage-Streak".loc(3), points: 15,
                           progress: streak, target: 3),
            ChallengeState(id: "streak-7", emoji: "🔥", symbol: "flame.fill",
                           title: "%d-Tage-Streak".loc(7), points: 25,
                           progress: streak, target: 7),
            ChallengeState(id: "streak-30", emoji: "🔥", symbol: "flame.fill",
                           title: "%d-Tage-Streak".loc(30), points: 75,
                           progress: streak, target: 30),
            ChallengeState(id: "streak-100", emoji: "🏆", symbol: "crown.fill",
                           title: "%d-Tage-Streak".loc(100), points: 150,
                           progress: streak, target: 100),
            ChallengeState(id: "fast-1", emoji: "⏱️", symbol: "timer",
                           title: "Erstes Fasten schaffen".loc, points: 20,
                           progress: goodFasts, target: 1),
            ChallengeState(id: "fast-5", emoji: "🦊", symbol: "timer",
                           title: "%d Fasten schaffen".loc(5), points: 40,
                           progress: goodFasts, target: 5),
            ChallengeState(id: "fast-20", emoji: "🧘", symbol: "timer",
                           title: "%d Fasten schaffen".loc(20), points: 80,
                           progress: goodFasts, target: 20),
            ChallengeState(id: "water-10", emoji: "💧", symbol: "drop.fill",
                           title: "%d× Wasserziel erreichen".loc(10), points: 30,
                           progress: waterGoalDays, target: 10),
            ChallengeState(id: "weight-10", emoji: "⚖️", symbol: "scalemass.fill",
                           title: "%d× Gewicht loggen".loc(10), points: 25,
                           progress: weights.count, target: 10),
            ChallengeState(id: "mood-7", emoji: "😊", symbol: "face.smiling.inverse",
                           title: "%d× Stimmung festhalten".loc(7), points: 20,
                           progress: notes.count, target: 7),
            ChallengeState(id: "buddy-custom", emoji: "🎨", symbol: "paintbrush.fill",
                           title: "Eigenen Buddy gestalten".loc, points: 15,
                           progress: customBuddy, target: 1),
        ]
    }

    static func totalPoints(_ challenges: [ChallengeState]) -> Int {
        challenges.filter(\.done).reduce(0) { $0 + $1.points }
    }

    /// Points computed straight from the store, for views without queries.
    @MainActor
    static func points(in context: ModelContext, profile: UserProfile) -> Int {
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let fasts = (try? context.fetch(FetchDescriptor<FastingSession>())) ?? []
        let water = (try? context.fetch(FetchDescriptor<WaterDay>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<DayNote>())) ?? []
        return totalPoints(evaluate(entries: entries, fasts: fasts, waterDays: water,
                                    weights: weights, notes: notes, profile: profile))
    }

    /// Longest run of consecutive days with at least one logged food.
    static func longestStreak(entries: [FoodEntry]) -> Int {
        let days = Set(entries.map(\.day)).sorted()
        let calendar = Calendar.current
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

/// Achievements list with the point total and unlock hint.
struct ChallengesView: View {
    let profile: UserProfile

    @Query private var entries: [FoodEntry]
    @Query private var fasts: [FastingSession]
    @Query private var waterDays: [WaterDay]
    @Query private var weights: [WeightEntry]
    @Query private var notes: [DayNote]

    var body: some View {
        let challenges = ChallengeEngine.evaluate(entries: entries, fasts: fasts,
                                                  waterDays: waterDays, weights: weights,
                                                  notes: notes, profile: profile)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Challenges", subtitle: "Damit schaltest du neue Styles im Studio frei".loc)
                pointsCard(total: ChallengeEngine.totalPoints(challenges))
                ForEach(challenges) { challenge in
                    challengeRow(challenge)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func pointsCard(total: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 54, height: 54)
                .background(Theme.accent.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("%d Punkte".loc(total))
                    .font(.fredoka(24, .semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("Gesammelt aus Challenges".loc)
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 22))
    }

    private func challengeRow(_ challenge: ChallengeState) -> some View {
        Card {
            HStack(spacing: 14) {
                EmojiOrSymbol(emoji: challenge.emoji, symbol: challenge.symbol, size: 24)
                    .frame(width: 46, height: 46)
                    .background(Theme.field.opacity(0.6), in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title)
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.track.opacity(0.6))
                            Capsule()
                                .fill(challenge.done ? AnyShapeStyle(Theme.accent.gradient)
                                                     : AnyShapeStyle(Theme.accent.opacity(0.5)))
                                .frame(width: geometry.size.width
                                    * min(1, Double(challenge.progress) / Double(challenge.target)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(min(challenge.progress, challenge.target).formatted(.number.locale(Lingo.shared.language.locale))) / \(challenge.target.formatted(.number.locale(Lingo.shared.language.locale)))")
                        .font(.fredoka(11))
                        .foregroundStyle(.tertiary)
                }
                if challenge.done {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.3, green: 0.65, blue: 0.35))
                } else {
                    Text("+\(challenge.points) P")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }
        }
    }
}
