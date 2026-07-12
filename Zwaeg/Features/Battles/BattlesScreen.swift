import SwiftUI
import SwiftData

struct BattlesScreen: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Challenge.createdAt, order: .reverse) private var challenges: [Challenge]
    @Query private var foodEntries: [FoodEntry]

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var debugOpenedChallenge: Challenge?

    private var active: [Challenge] { challenges.filter(\.isActive) }
    private var finished: [Challenge] { challenges.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if challenges.isEmpty {
                        emptyState
                    }
                    ForEach(active) { challenge in
                        challengeCard(challenge)
                    }
                    if !finished.isEmpty {
                        Text("Beendet".loc)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(finished) { challenge in
                            challengeCard(challenge)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .tabBarClearance()
            .navigationTitle("Battles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showJoin = true
                    } label: {
                        Label("Beitreten".loc, systemImage: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Neue Challenge".loc, systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateChallengeSheet(profile: profile)
            }
            .sheet(isPresented: $showJoin) {
                JoinChallengeSheet()
                    .presentationDetents([.medium])
            }
            .task {
                await refreshAll()
                if LaunchArgs.all.contains("-open-battle") {
                    debugOpenedChallenge = active.first
                }
            }
            .refreshable {
                await refreshAll()
            }
            .navigationDestination(item: $debugOpenedChallenge) { challenge in
                ChallengeDetailView(challenge: challenge, profile: profile)
            }
        }
    }

    private var emptyState: some View {
        Card {
            VStack(spacing: 12) {
                BuddyView(buddy: profile.buddy, size: 84)
                Text("Noch keine Battles".loc)
                    .font(.fredoka(17, .semibold))
                Text("Fordere Freunde heraus: Wer macht mehr Schritte, verbrennt mehr Kalorien oder spart am meisten ein?".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showCreate = true
                } label: {
                    Text("Challenge starten".loc)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func challengeCard(_ challenge: Challenge) -> some View {
        NavigationLink {
            ChallengeDetailView(challenge: challenge, profile: profile)
        } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: challenge.metric.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(challenge.isActive ? Color.appAccent.gradient : Color.gray.gradient,
                                    in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(challenge.name)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(.primary)
                        Text(challenge.isActive
                             ? (challenge.daysLeft == 1 ? "%@ · noch %d Tag" : "%@ · noch %d Tage")
                                 .loc(challenge.metric.label, challenge.daysLeft)
                             : "%@ · beendet".loc(challenge.metric.label))
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let rank = challenge.myRank {
                        VStack(spacing: 2) {
                            RankBadge(rank: rank)
                            Text("Platz %d".loc(rank))
                                .font(.fredoka(11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "chevron.forward")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func refreshAll() async {
        for challenge in active {
            await updateMyScores(challenge)
            await ChallengeSync.live.refresh(challenge)
        }
    }

    /// Recomputes my score for every elapsed challenge day from diary and Health data.
    private func updateMyScores(_ challenge: Challenge) async {
        var participants = challenge.participants
        guard let myIndex = participants.firstIndex(where: \.isMe) else { return }
        for dayKey in challenge.elapsedDayKeys {
            guard let day = BattleDay.date(for: dayKey) else { continue }
            let consumed = foodEntries
                .filter { $0.day == day }
                .reduce(0) { $0 + $1.calories }
            let activity = HealthKitService.shared.isConnected
                ? await HealthKitService.shared.activity(for: day)
                : HealthKitService.DayActivity()
            participants[myIndex].scores[dayKey] = BattleScoreEngine.myScore(
                metric: challenge.metric, profile: profile,
                consumedKcal: consumed, activity: activity)
        }
        challenge.participants = participants
    }
}
