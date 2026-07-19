// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI
import SwiftData

struct ChallengeDetailView: View {
    let challenge: Challenge
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showManualSession = false
    @State private var confirmLeave = false
    @State private var confirmEndForAll = false
    @State private var proofParticipant: ParticipantScore?
    /// Steps revoked by objection majorities, per participant.
    @State private var revokedSteps: [String: Double] = [:]

    private func displayTotal(_ participant: ParticipantScore) -> Double {
        max(0, participant.total - (revokedSteps[participant.id] ?? 0))
    }

    private var displayRanking: [ParticipantScore] {
        challenge.participants.sorted { displayTotal($0) > displayTotal($1) }
    }

    private var maxTotal: Double {
        max(displayRanking.first.map(displayTotal) ?? 1, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                leaderboardCard
                todayCard
                if challenge.metric == .steps, challenge.isActive {
                    manualSessionButton
                }
                fairnessNote
                deleteButton
            }
            .padding(16)
        }
        .confirmationDialog("Battle verlassen?".loc, isPresented: $confirmLeave,
                            titleVisibility: .visible) {
            Button("Verlassen".loc, role: .destructive) {
                let target = challenge
                dismiss()
                // Deleting the model while this view still renders it would
                // crash; let the pop finish first.
                Task { @MainActor in
                    if target.code != Challenge.demoCode {
                        await ChallengeSyncService.shared.leave(target)
                    }
                    try? await Task.sleep(for: .milliseconds(400))
                    context.delete(target)
                }
            }
        } message: {
            Text("Du verschwindest aus der Rangliste der anderen, deine Werte und Foto-Belege werden aus dem Battle gelöscht.".loc)
        }
        .confirmationDialog("Battle für alle beenden?".loc, isPresented: $confirmEndForAll,
                            titleVisibility: .visible) {
            Button("Für alle beenden".loc, role: .destructive) {
                let target = challenge
                dismiss()
                Task { @MainActor in
                    if target.code != Challenge.demoCode {
                        await ChallengeSyncService.shared.endForEveryone(target)
                    }
                    try? await Task.sleep(for: .milliseconds(400))
                    context.delete(target)
                }
            }
        } message: {
            Text("Löscht das Battle mit allen Werten und Foto-Belegen. Bei den anderen erscheint es als beendet.".loc)
        }
        .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
        .background(Theme.background)
        .navigationTitle(challenge.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "Fordere mich heraus bei Zwäg! Challenge \"%@\" (%@), Code: %@".loc(challenge.name, challenge.metric.label, challenge.code)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showManualSession) {
            ManualSessionSheet(challenge: challenge, profile: profile)
                .presentationDetents([.large])
        }
        .sheet(item: $proofParticipant) { participant in
            ProofGalleryView(challenge: challenge, participant: participant)
                .presentationDetents([.large])
        }
        .task { await loadRevocations() }
        .onAppear {
            // Like the recipe detail: bottom content beats the floating bar.
            TabRouter.shared.tabBarHidden = true
            if LaunchArgs.all.contains("-open-manual-session") {
                showManualSession = true
            }
            if LaunchArgs.all.contains("-open-proof-gallery") {
                proofParticipant = challenge.participants.first { !$0.manualDays.isEmpty }
            }
        }
        .onDisappear {
            TabRouter.shared.tabBarHidden = false
        }
    }

    private var manualSessionButton: some View {
        Button {
            showManualSession = true
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.fredoka(16, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color(red: 0.13, green: 0.66, blue: 0.42).gradient,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Training nachtragen".loc)
                            .font(.fredoka(16, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Laufband & Co. — mit Foto-Beleg".loc)
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        VStack(spacing: 10) {
            Button(role: .destructive) {
                confirmLeave = true
            } label: {
                Text("Battle verlassen".loc)
                    .font(.fredoka(14, .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.card, in: Capsule())
            }
            .buttonStyle(.plain)
            if challenge.isCreator {
                Button(role: .destructive) {
                    confirmEndForAll = true
                } label: {
                    Text("Battle für alle beenden".loc)
                        .font(.fredoka(14, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Says out loud what keeps the leaderboard honest.
    private var fairnessNote: some View {
        Text(challenge.metric == .deficit
             ? "Aktivkalorien zählen nur vom Gerät gemessen — von Hand in Health eingetragene Werte nicht.".loc
             : "Es zählen nur vom Gerät gemessene Werte — von Hand in Health eingetragene nicht. Tippe aufs Kamera-Symbol für die Foto-Belege; erhebt die Mehrheit Einspruch, wird der Tag aberkannt.".loc)
            .font(.fredoka(12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCard: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: challenge.metric.symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.appAccent.gradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.metric.label)
                        .font(.fredoka(17, .semibold))
                    Text(challenge.isActive
                         ? (challenge.daysLeft == 1 ? "Noch %d Tag" : "Noch %d Tage").loc(challenge.daysLeft)
                         : "Beendet".loc)
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(challenge.code)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    Text("Code")
                        .font(.fredoka(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var leaderboardCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rangliste".loc)
                    .font(.fredoka(17, .semibold))
                ForEach(Array(displayRanking.enumerated()), id: \.element.id) { index, participant in
                    leaderboardRow(rank: index + 1, participant: participant)
                }
            }
        }
    }

    private func leaderboardRow(rank: Int, participant: ParticipantScore) -> some View {
        VStack(spacing: 6) {
            HStack {
                RankBadge(rank: rank)
                    .frame(width: 30, alignment: .leading)
                BuddyView(buddy: participant.isMe ? profile.buddy : Buddy.seeded(participant.id), size: 30)
                Text(participant.name)
                    .fontWeight(participant.isMe ? .bold : .regular)
                if !participant.manualDays.isEmpty {
                    Button {
                        proofParticipant = participant
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.fredoka(11, .semibold))
                            .foregroundStyle(revokedSteps[participant.id] != nil
                                             ? Color.red : .secondary)
                            .frame(width: 26, height: 26)
                            .background(Theme.field.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                if participant.isMe {
                    Text("Du".loc)
                        .font(.fredoka(11, .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appAccent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Text(formatted(displayTotal(participant)))
                    .font(.fredoka(15, .semibold))
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(participant.isMe ? Color.appAccent.gradient : Color.gray.gradient)
                        .frame(width: max(6, geo.size.width * progressFraction(participant)))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 2)
    }

    private func progressFraction(_ participant: ParticipantScore) -> Double {
        max(0, min(1, displayTotal(participant) / maxTotal))
    }

    /// Objection majorities revoke a day's manual steps for everyone: flags
    /// and proof metadata (no photos) are enough to do the math.
    private func loadRevocations() async {
        guard challenge.code != Challenge.demoCode else { return }
        guard let flags = try? await ChallengeSyncService.shared.fetchFlags(challenge: challenge),
              let proofs = try? await ChallengeSyncService.shared.fetchProofs(
                challenge: challenge, includePhotos: false) else { return }
        let participantIDs = Set(challenge.participants.map(\.id))
        var revoked: [String: Double] = [:]
        for participant in challenge.participants {
            let others = max(1, challenge.participants.count - 1)
            let days = Set(proofs.filter { $0.participantID == participant.id }.map(\.dayKey))
            for day in days {
                let voters = Set(flags
                    .filter { $0.targetID == participant.id && $0.dayKey == day }
                    .map(\.voterID))
                    .intersection(participantIDs)
                    .subtracting([participant.id])
                guard voters.count * 2 > others else { continue }
                let steps = proofs
                    .filter { $0.participantID == participant.id && $0.dayKey == day }
                    .reduce(0) { $0 + $1.steps }
                revoked[participant.id, default: 0] += Double(steps)
            }
        }
        revokedSteps = revoked
    }

    private var todayCard: some View {
        let todayKey = BattleDay.key(for: .now)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Heute".loc)
                    .font(.fredoka(17, .semibold))
                ForEach(displayRanking) { participant in
                    HStack {
                        Text(participant.name)
                            .font(.fredoka(15))
                            .foregroundStyle(participant.isMe ? .primary : .secondary)
                        Spacer()
                        Text(formatted(participant.scores[todayKey] ?? 0))
                            .font(.fredoka(15, .medium))
                    }
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        "\(Int(value.rounded())) \(challenge.metric == .steps ? "" : "kcal")"
            .trimmingCharacters(in: .whitespaces)
    }
}

#endif
