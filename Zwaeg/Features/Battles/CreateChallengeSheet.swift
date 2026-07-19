// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI
import SwiftData

struct CreateChallengeSheet: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var metric: BattleMetric = .steps
    @State private var durationDays = 7
    @State private var errorMessage: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name".loc) {
                    TextField("z.B. Wochenbattle".loc, text: $name)
                }

                Section("Disziplin".loc) {
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

                Section("Dauer".loc) {
                    Picker("Dauer".loc, selection: $durationDays) {
                        Text("3 Tage".loc).tag(3)
                        Text("7 Tage".loc).tag(7)
                        Text("14 Tage".loc).tag(14)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.fredoka(13))
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Du bekommst einen Code zum Teilen. Wer ihn eingibt, tritt gegen dich an.".loc)
                }
            }
            .navigationTitle("Neue Challenge".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen".loc) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Starten".loc) {
                            Task { await create() }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    /// Publishes first and only stores the challenge once CloudKit has accepted
    /// it: a challenge that exists on this device but not in iCloud would hand
    /// out a join code that nobody can ever redeem.
    private func create() async {
        isCreating = true
        defer { isCreating = false }
        errorMessage = nil

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: durationDays - 1, to: start) ?? start
        let trimmedName = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
        let finalName = trimmedName.isEmpty ? "%@-Battle".loc(metric.label) : trimmedName

        do {
            let code = try await ChallengeSyncService.shared.publishNewChallenge(
                name: finalName, metric: metric, start: start, end: end)
            context.insert(Challenge.mine(code: code, name: finalName, metric: metric,
                                          startDay: start, endDay: end, profile: profile, isCreator: true))
            dismiss()
        } catch {
            errorMessage = BattleSyncError.message(for: error)
        }
    }
}

#endif
