// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI
import SwiftData

struct BattlesScreen: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Challenge.createdAt, order: .reverse) private var challenges: [Challenge]
    @Query private var foodEntries: [FoodEntry]
    @Query private var manualEntries: [BattleManualEntry]

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var debugOpenedChallenge: Challenge?
    @State private var availabilityError: BattleSyncError?
    @State private var syncError: String?
    @State private var isRefreshing = false

    private var active: [Challenge] { challenges.filter(\.isActive) }
    private var finished: [Challenge] { challenges.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let availabilityError {
                        noticeCard(icon: "icloud.slash",
                                   text: availabilityError.errorDescription ?? "")
                    } else if let syncError {
                        noticeCard(icon: "exclamationmark.triangle", text: syncError)
                    }
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
                JoinChallengeSheet(profile: profile)
                    .presentationDetents([.medium])
            }
            .task {
                // Debug: exercises the real create path (publish to CloudKit,
                // store only on success) without UI driving; used to bootstrap
                // the CloudKit schema and to smoke-test the round trip from the
                // command line. LaunchArgs is empty in release builds.
                if LaunchArgs.all.contains("-create-battle"),
                   !challenges.contains(where: { $0.code != Challenge.demoCode }) {
                    do {
                        let start = Calendar.current.startOfDay(for: .now)
                        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
                        let code = try await ChallengeSyncService.shared.publishNewChallenge(
                            name: "CloudKit-Test", metric: .steps, start: start, end: end)
                        context.insert(Challenge.mine(code: code, name: "CloudKit-Test", metric: .steps,
                                                      startDay: start, endDay: end, profile: profile))
                    } catch {
                        syncError = BattleSyncError.message(for: error)
                    }
                }
                await refreshAll()
                // Set-only: an unconditional write here would dismiss a sheet
                // the user opened while refreshAll was still awaiting.
                if LaunchArgs.all.contains("-open-battle") {
                    debugOpenedChallenge = active.first
                }
                if LaunchArgs.all.contains("-open-create") {
                    showCreate = true
                }
                if LaunchArgs.all.contains("-open-join") {
                    showJoin = true
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

    private func noticeCard(icon: String, text: String) -> some View {
        Card {
            Label {
                Text(text)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        // Concurrent runs (the .task plus a pull-to-refresh) would interleave
        // read-modify-write cycles on challenge.participants and lose writes.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // My own score comes from the diary and Apple Health, so it stays
        // current even with no iCloud account; only sharing it needs the network.
        let calories = BattleScoreEngine.caloriesByDay(foodEntries)
        let manualSteps = BattleScoreEngine.manualStepsByDay(manualEntries)
        for challenge in active {
            await BattleScoreEngine.updateMyScores(for: challenge, profile: profile,
                                                   caloriesByDay: calories,
                                                   manualStepsByDay: manualSteps)
        }

        syncError = nil
        availabilityError = await ChallengeSyncService.shared.availability()
        guard availabilityError == nil else { return }

        // The seeded demo battle shares its code with every seeded install and
        // must never touch the real database.
        for challenge in active where challenge.code != Challenge.demoCode {
            do {
                try await ChallengeSyncService.shared.refresh(challenge)
            } catch {
                // One bad challenge shouldn't stop the others from syncing.
                syncError = BattleSyncError.message(for: error)
            }
        }
    }
}

#endif
