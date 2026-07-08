import SwiftUI
import SwiftData

struct ChallengeDetailView: View {
    let challenge: Challenge
    let profile: UserProfile

    private var maxTotal: Double {
        max(challenge.ranking.first?.total ?? 1, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                leaderboardCard
                todayCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(challenge.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "Fordere mich heraus bei Znüni! Challenge \"\(challenge.name)\" (\(challenge.metric.label)), Code: \(challenge.code)") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
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
                         ? "Noch \(challenge.daysLeft) Tag\(challenge.daysLeft == 1 ? "" : "e")"
                         : "Beendet")
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
                Text("Rangliste")
                    .font(.fredoka(17, .semibold))
                ForEach(Array(challenge.ranking.enumerated()), id: \.element.id) { index, participant in
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
                Text(participant.name)
                    .fontWeight(participant.isMe ? .bold : .regular)
                if participant.isMe {
                    Text("Du")
                        .font(.fredoka(11, .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appAccent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Text(formatted(participant.total))
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
        max(0, min(1, participant.total / maxTotal))
    }

    private var todayCard: some View {
        let todayKey = BattleDay.key(for: .now)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Heute")
                    .font(.fredoka(17, .semibold))
                ForEach(challenge.ranking) { participant in
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
