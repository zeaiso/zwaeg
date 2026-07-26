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
    /// Every day with at least one objection, revoked or still pending.
    @State private var disputes: [DisputeItem] = []
    /// Participants who marked their lost stake as paid.
    @State private var paidPayerIDs: Set<String> = []

    /// One participant-day under objection, for the Einsprüche card.
    struct DisputeItem: Identifiable {
        let participantID: String
        let name: String
        let dayKey: String
        let votes: Int
        let voterPool: Int
        let revoked: Bool

        var id: String { "\(participantID)-\(dayKey)" }
    }

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
                stakeCard
                leaderboardCard
                disputesCard
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
                NotificationService.cancelBattleStake(code: target.code)
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
                NotificationService.cancelBattleStake(code: target.code)
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
        .sheet(item: $proofParticipant, onDismiss: {
            // An objection raised in the gallery must survive the dismissal;
            // without this the leaderboard kept its stale, un-revoked totals.
            Task { await loadRevocations() }
        }) { participant in
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
                        .background(Theme.green.gradient,
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
                    if challenge.stakeChf > 0 {
                        Text("Einsatz: %d CHF · TWINT".loc(challenge.stakeChf))
                            .font(.fredoka(13, .semibold))
                            .foregroundStyle(Theme.green)
                    }
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
                            .foregroundStyle(cameraTint(participant.id))
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

    /// Red once a day is revoked, amber while an objection is pending.
    private func cameraTint(_ participantID: String) -> Color {
        if revokedSteps[participantID] != nil { return .red }
        if disputes.contains(where: { $0.participantID == participantID }) { return Theme.amber }
        return Color(.secondaryLabel)
    }

    /// Winner by revocation-adjusted totals; nil while the battle runs or
    /// when the top spot is shared (nobody pays on a draw).
    private var stakeWinner: ParticipantScore? {
        guard !challenge.isActive, challenge.participants.count > 1,
              let first = displayRanking.first else { return nil }
        if displayRanking.count > 1, displayTotal(displayRanking[1]) == displayTotal(first) {
            return nil
        }
        return first
    }

    /// Splitwise for the battle stake: once the battle ends, this says who
    /// owes whom. Losers mark their TWINT payment; the winner sees the
    /// checkmarks come in. No money moves through the app.
    @ViewBuilder
    private var stakeCard: some View {
        if challenge.stakeChf > 0, !challenge.isActive {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Einsatz".loc)
                            .font(.fredoka(17, .semibold))
                        Spacer()
                        Text("\(challenge.stakeChf) CHF")
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(Theme.green)
                    }
                    if let winner = stakeWinner {
                        if winner.isMe {
                            Text("Du hast gewonnen — der Einsatz gehört dir!".loc)
                                .font(.fredoka(14))
                                .foregroundStyle(Theme.ink)
                            ForEach(challenge.participants.filter { $0.id != winner.id }) { loser in
                                HStack {
                                    Text("%@ schuldet dir %d CHF".loc(loser.name, challenge.stakeChf))
                                        .font(.fredoka(14, .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    if paidPayerIDs.contains(loser.id) {
                                        Label("Bezahlt".loc, systemImage: "checkmark.circle.fill")
                                            .font(.fredoka(12, .semibold))
                                            .foregroundStyle(Theme.green)
                                    } else {
                                        Text("Offen".loc)
                                            .font(.fredoka(12, .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("%@ hat gewonnen. Du schuldest %d CHF — ab in die TWINT-App!".loc(
                                winner.name, challenge.stakeChf))
                                .font(.fredoka(14))
                                .foregroundStyle(Theme.ink)
                            if challenge.stakePaidByMe {
                                Label("Bezahlt".loc, systemImage: "checkmark.circle.fill")
                                    .font(.fredoka(14, .semibold))
                                    .foregroundStyle(Theme.green)
                            } else {
                                Button {
                                    markStakePaid()
                                } label: {
                                    Text("Ich habe per TWINT bezahlt".loc)
                                        .font(.fredoka(14, .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.green.gradient, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("Unentschieden — jeder behält seinen Einsatz.".loc)
                            .font(.fredoka(14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func markStakePaid() {
        withAnimation(.snappy) { challenge.stakePaidByMe = true }
        guard challenge.code != Challenge.demoCode else { return }
        // Best effort: refresh() re-pushes the idempotent record until it lands.
        Task { try? await ChallengeSyncService.shared.pushStakePaid(challenge) }
    }

    /// Every dispute in the battle, one glance: who, which day, how many
    /// votes, already revoked or still pending. Rows open the proof gallery.
    @ViewBuilder
    private var disputesCard: some View {
        if !disputes.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Einsprüche".loc)
                        .font(.fredoka(17, .semibold))
                    ForEach(disputes) { dispute in
                        Button {
                            proofParticipant = challenge.participants
                                .first { $0.id == dispute.participantID }
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(dispute.name) · \(dayLabel(dispute.dayKey))")
                                        .font(.fredoka(14, .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("%d von %d Einsprüchen".loc(dispute.votes, dispute.voterPool))
                                        .font(.fredoka(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(dispute.revoked ? "Aberkannt".loc : "Einspruch läuft".loc)
                                    .font(.fredoka(11, .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(dispute.revoked
                                                ? AnyShapeStyle(Color.red.gradient)
                                                : AnyShapeStyle(Theme.amber.gradient),
                                                in: Capsule())
                                Image(systemName: "chevron.forward")
                                    .font(.fredoka(12, .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func dayLabel(_ dayKey: String) -> String {
        BattleDay.date(for: dayKey)?
            .formatted(.dateTime.weekday(.wide).day().month()
                .locale(Lingo.shared.language.locale)) ?? dayKey
    }

    /// Objection majorities revoke a day's manual steps for everyone: flags
    /// and proof metadata (no photos) are enough to do the math. Days with
    /// any objection at all additionally surface in the Einsprüche card.
    private func loadRevocations() async {
        if LaunchArgs.all.contains("-demo-disputes"),
           let accused = challenge.participants.first(where: { !$0.isMe }) {
            let today = BattleDay.key(for: .now)
            let yesterday = BattleDay.key(for: .now.addingTimeInterval(-86_400))
            disputes = [
                .init(participantID: accused.id, name: accused.name, dayKey: today,
                      votes: 1, voterPool: 3, revoked: false),
                .init(participantID: accused.id, name: accused.name, dayKey: yesterday,
                      votes: 2, voterPool: 3, revoked: true),
            ]
            revokedSteps = [accused.id: 4000]
            paidPayerIDs = [accused.id]
            return
        }
        guard challenge.code != Challenge.demoCode else { return }
        if challenge.stakeChf > 0, !challenge.isActive,
           let settled = try? await ChallengeSyncService.shared.fetchSettlements(challenge: challenge) {
            paidPayerIDs = settled
        }
        guard let flags = try? await ChallengeSyncService.shared.fetchFlags(challenge: challenge),
              let proofs = try? await ChallengeSyncService.shared.fetchProofs(
                challenge: challenge, includePhotos: false) else { return }
        let participantIDs = Set(challenge.participants.map(\.id))
        var revoked: [String: Double] = [:]
        var found: [DisputeItem] = []
        for participant in challenge.participants {
            let others = max(1, challenge.participants.count - 1)
            let days = Set(proofs.filter { $0.participantID == participant.id }.map(\.dayKey))
            for day in days {
                let voters = Set(flags
                    .filter { $0.targetID == participant.id && $0.dayKey == day }
                    .map(\.voterID))
                    .intersection(participantIDs)
                    .subtracting([participant.id])
                guard !voters.isEmpty else { continue }
                let isRevoked = voters.count * 2 > others
                found.append(DisputeItem(
                    participantID: participant.id, name: participant.name, dayKey: day,
                    votes: voters.count, voterPool: others, revoked: isRevoked))
                guard isRevoked else { continue }
                let steps = proofs
                    .filter { $0.participantID == participant.id && $0.dayKey == day }
                    .reduce(0) { $0 + $1.steps }
                revoked[participant.id, default: 0] += Double(steps)
            }
        }
        withAnimation(.snappy) {
            revokedSteps = revoked
            disputes = found.sorted { ($0.dayKey, $0.name) > ($1.dayKey, $1.name) }
        }
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
