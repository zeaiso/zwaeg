// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI

/// A participant's treadmill proofs, grouped by day, with the battle's
/// objection voting: when more than half of the other participants object to
/// a day, its manual steps are revoked from the leaderboard everywhere.
/// Objecting is also the report mechanism for a photo that doesn't belong.
struct ProofGalleryView: View {
    let challenge: Challenge
    let participant: ParticipantScore

    @Environment(\.dismiss) private var dismiss
    @State private var proofs: [ChallengeSyncService.ProofItem] = []
    @State private var flags: [ChallengeSyncService.FlagItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var myID: String { PlayerIdentity.myID }

    /// Voters that still are in the battle, excluding the accused.
    private var othersCount: Int {
        max(1, challenge.participants.count - 1)
    }

    private var days: [String] {
        Array(Set(proofs.map(\.dayKey))).sorted(by: >)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if loadFailed {
                        Text("Das hat nicht geklappt. Versuch es später nochmal.".loc)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    } else if days.isEmpty {
                        Text("Noch keine Foto-Belege.".loc)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(days, id: \.self) { dayKey in
                        daySection(dayKey)
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.background)
        .task { await load() }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(Theme.field)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text("Foto-Belege".loc)
                .font(.fredoka(24, .semibold))
                .foregroundStyle(Theme.ink)
            Text(participant.name)
                .font(.fredoka(14))
                .foregroundStyle(.secondary)
        }
    }

    private func daySection(_ dayKey: String) -> some View {
        let dayProofs = proofs.filter { $0.dayKey == dayKey }
            .sorted { $0.capturedAt < $1.capturedAt }
        let objections = objectionCount(dayKey)
        let revoked = objections * 2 > othersCount
        let mine = myFlagRaised(dayKey)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(BattleDay.date(for: dayKey)?
                        .formatted(.dateTime.weekday(.wide).day().month()
                            .locale(Lingo.shared.language.locale)) ?? dayKey)
                        .font(.fredoka(16, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if revoked {
                        Text("Aberkannt".loc)
                            .font(.fredoka(11, .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.red.gradient, in: Capsule())
                    }
                }
                ForEach(dayProofs) { proof in
                    proofRow(proof)
                }
                if participant.id != myID {
                    HStack {
                        Button {
                            Task { await toggleFlag(dayKey, raise: !mine) }
                        } label: {
                            Label(mine ? "Einspruch zurückziehen".loc : "Einspruch erheben".loc,
                                  systemImage: mine ? "hand.raised.slash" : "hand.raised.fill")
                                .font(.fredoka(13, .semibold))
                                .foregroundStyle(mine ? .secondary : Color.appAccent)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text("%d von %d Einsprüchen".loc(objections, othersCount))
                            .font(.fredoka(12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func proofRow(_ proof: ChallengeSyncService.ProofItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = proof.imageURL, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("%@ Uhr · %@ km · %d Schritte".loc(
                proof.capturedAt.formatted(.dateTime.hour().minute()
                    .locale(Lingo.shared.language.locale)),
                proof.distanceKm.formatted(.number.precision(.fractionLength(0...1))),
                proof.steps))
                .font(.fredoka(12, .semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Flags

    private func objectionCount(_ dayKey: String) -> Int {
        let validVoters = Set(challenge.participants.map(\.id)).subtracting([participant.id])
        return Set(flags
            .filter { $0.targetID == participant.id && $0.dayKey == dayKey }
            .map(\.voterID))
            .intersection(validVoters)
            .count
    }

    private func myFlagRaised(_ dayKey: String) -> Bool {
        flags.contains { $0.voterID == myID && $0.targetID == participant.id && $0.dayKey == dayKey }
    }

    private func toggleFlag(_ dayKey: String, raise: Bool) async {
        // Optimistic: the record write is idempotent either way.
        withAnimation(.snappy) {
            if raise {
                flags.append(.init(voterID: myID, targetID: participant.id, dayKey: dayKey))
            } else {
                flags.removeAll {
                    $0.voterID == myID && $0.targetID == participant.id && $0.dayKey == dayKey
                }
            }
        }
        guard challenge.code != Challenge.demoCode else { return }
        try? await ChallengeSyncService.shared.setFlag(
            raise, challenge: challenge, targetID: participant.id, dayKey: dayKey)
    }

    private func load() async {
        // Demo fixture: gallery without CloudKit, for the simulator.
        if LaunchArgs.all.contains("-demo-proofs") {
            let today = BattleDay.key(for: .now)
            proofs = [
                .init(recordName: "demo-proof-1", participantID: participant.id, dayKey: today,
                      steps: 3900, distanceKm: 3,
                      capturedAt: .now.addingTimeInterval(-10_800),
                      imageURL: ProgressPhotos.imageURL(name: "battle-proof-test-1.jpg")),
                .init(recordName: "demo-proof-2", participantID: participant.id, dayKey: today,
                      steps: 6500, distanceKm: 5,
                      capturedAt: .now.addingTimeInterval(-2_400),
                      imageURL: ProgressPhotos.imageURL(name: "battle-proof-test-2.jpg")),
            ]
            flags = [.init(voterID: "demo-mia", targetID: participant.id, dayKey: today)]
            isLoading = false
            return
        }
        guard challenge.code != Challenge.demoCode else {
            isLoading = false
            return
        }
        do {
            proofs = try await ChallengeSyncService.shared.fetchProofs(
                challenge: challenge, participantID: participant.id, includePhotos: true)
            flags = try await ChallengeSyncService.shared.fetchFlags(challenge: challenge)
            isLoading = false
        } catch {
            isLoading = false
            loadFailed = true
        }
    }
}

#endif
