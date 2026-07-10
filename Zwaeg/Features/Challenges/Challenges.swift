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
/// always consistent and never need separate persistence. Challenges are
/// endless ladders: finishing a tier reveals the next one.
enum ChallengeEngine {
    private struct Ladder {
        let id: String
        let emoji: String
        let symbol: String
        let title: (Int) -> String
        let tiers: [(target: Int, points: Int)]
    }

    private static let ladders: [Ladder] = [
        Ladder(id: "entries", emoji: "📝", symbol: "list.bullet",
               title: { $0 == 1 ? "Ersten Eintrag loggen".loc : "%d Einträge loggen".loc($0) },
               tiers: [(1, 10), (50, 25), (200, 50), (500, 100), (1000, 150),
                       (2500, 250), (5000, 400), (10000, 600)]),
        Ladder(id: "streak", emoji: "🔥", symbol: "flame.fill",
               title: { "%d-Tage-Streak".loc($0) },
               tiers: [(3, 15), (7, 25), (14, 40), (30, 75), (50, 100),
                       (100, 150), (200, 250), (365, 400)]),
        Ladder(id: "fast", emoji: "⏱️", symbol: "timer",
               title: { $0 == 1 ? "Erstes Fasten schaffen".loc : "%d Fasten schaffen".loc($0) },
               tiers: [(1, 20), (5, 40), (20, 80), (50, 150), (100, 250), (250, 400)]),
        Ladder(id: "water", emoji: "💧", symbol: "drop.fill",
               title: { "%d× Wasserziel erreichen".loc($0) },
               tiers: [(10, 30), (25, 50), (50, 100), (100, 150), (250, 250), (500, 400)]),
        Ladder(id: "weight", emoji: "⚖️", symbol: "scalemass.fill",
               title: { "%d× Gewicht loggen".loc($0) },
               tiers: [(10, 25), (25, 50), (50, 100), (100, 150), (250, 250)]),
        Ladder(id: "mood", emoji: "😊", symbol: "face.smiling.inverse",
               title: { "%d× Stimmung festhalten".loc($0) },
               tiers: [(7, 20), (30, 50), (100, 100), (365, 250)]),
        Ladder(id: "buddy", emoji: "🎨", symbol: "paintbrush.fill",
               title: { _ in "Eigenen Buddy gestalten".loc },
               tiers: [(1, 15)]),
    ]

    /// Every completed tier plus the first open tier of each ladder.
    static func evaluate(entries: [FoodEntry], fasts: [FastingSession],
                         waterDays: [WaterDay], weights: [WeightEntry],
                         notes: [DayNote], profile: UserProfile) -> [ChallengeState] {
        let goodFasts = fasts.filter { session in
            guard let end = session.endedAt else { return false }
            return end >= session.goalEnd
        }.count
        let progressByLadder: [String: Int] = [
            "entries": entries.count,
            "streak": longestStreak(entries: entries),
            "fast": goodFasts,
            "water": waterDays.filter { $0.glasses >= profile.waterGoalGlasses }.count,
            "weight": weights.count,
            "mood": notes.count,
            "buddy": ["custom", "monster", "styled"].contains(profile.buddy.kind) ? 1 : 0,
        ]

        var states: [ChallengeState] = []
        for ladder in ladders {
            let progress = progressByLadder[ladder.id] ?? 0
            for tier in ladder.tiers {
                states.append(ChallengeState(id: "\(ladder.id)-\(tier.target)",
                                             emoji: ladder.emoji, symbol: ladder.symbol,
                                             title: ladder.title(tier.target),
                                             points: tier.points,
                                             progress: progress, target: tier.target))
                if progress < tier.target {
                    break
                }
            }
        }
        return states
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
    @State private var showDone = false

    var body: some View {
        let challenges = ChallengeEngine.evaluate(entries: entries, fasts: fasts,
                                                  waterDays: waterDays, weights: weights,
                                                  notes: notes, profile: profile)
        let open = challenges.filter { !$0.done }
        let done = challenges.filter(\.done)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Challenges", subtitle: "Damit schaltest du neue Styles im Studio frei".loc)
                pointsCard(total: ChallengeEngine.totalPoints(challenges))
                tabSwitch(openCount: open.count, doneCount: done.count)
                if showDone {
                    if done.isEmpty {
                        emptyDone
                    }
                    ForEach(done.reversed()) { challenge in
                        challengeRow(challenge)
                    }
                } else {
                    ForEach(open) { challenge in
                        challengeRow(challenge)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tabSwitch(openCount: Int, doneCount: Int) -> some View {
        HStack(spacing: 4) {
            tabSegment("\("Jetzt".loc) · \(openCount)", isActive: !showDone) { showDone = false }
            tabSegment("\("Erledigt".loc) · \(doneCount)", isActive: showDone) { showDone = true }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
        .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
        .frame(maxWidth: .infinity)
    }

    private func tabSegment(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Text(label)
                .font(.fredoka(14, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isActive ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(.clear), in: Capsule())
                .foregroundStyle(isActive ? Theme.onInk : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var emptyDone: some View {
        VStack(spacing: 8) {
            EmojiOrSymbol(emoji: "🏆", symbol: "trophy", size: 36)
            Text("Noch nichts geschafft? Bleib dran!".loc)
                .font(.fredoka(14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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
