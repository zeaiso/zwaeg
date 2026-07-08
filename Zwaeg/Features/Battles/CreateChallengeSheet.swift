import SwiftUI
import SwiftData

struct CreateChallengeSheet: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var metric: BattleMetric = .steps
    @State private var durationDays = 7
    @State private var botCount = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Wochenbattle", text: $name)
                }

                Section("Disziplin") {
                    ForEach(BattleMetric.allCases) { option in
                        Button {
                            metric = option
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.symbol)
                                    .foregroundStyle(metric == option ? Color.appAccent : .secondary)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .foregroundStyle(.primary)
                                    Text(option.detail)
                                        .font(.fredoka(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if metric == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                    }
                }

                Section("Dauer") {
                    Picker("Dauer", selection: $durationDays) {
                        Text("3 Tage").tag(3)
                        Text("7 Tage").tag(7)
                        Text("14 Tage").tag(14)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Stepper("Demo-Gegner: \(botCount)", value: $botCount, in: 1...3)
                } footer: {
                    Text("Solange iCloud noch nicht aktiviert ist, trittst du gegen Demo-Gegner an. Echte Battles mit Freunden folgen mit dem Apple Developer Konto.")
                }
            }
            .navigationTitle("Neue Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Starten") { create() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func create() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: durationDays - 1, to: start) ?? start
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        var participants = [ParticipantScore(
            id: PlayerIdentity.myID,
            name: profile.name.isEmpty ? "Du" : profile.name,
            isMe: true,
            scores: [:])]
        for bot in BattleScoreEngine.botNames.prefix(botCount) {
            participants.append(ParticipantScore(id: "bot-\(bot)", name: bot, isMe: false, scores: [:]))
        }

        let challenge = Challenge(
            code: BattleScoreEngine.makeCode(),
            name: trimmedName.isEmpty ? "\(metric.label)-Battle" : trimmedName,
            metric: metric,
            startDay: start,
            endDay: end,
            participants: participants)
        context.insert(challenge)

        Task {
            await ChallengeSync.live.refresh(challenge)
            if AppConfig.cloudKitEnabled {
                try? await CloudKitChallengeService().publish(challenge)
            }
        }
        dismiss()
    }
}

enum PlayerIdentity {
    private static let key = "playerIdentity"

    /// Stable anonymous id for score records, created once per install.
    static var myID: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
