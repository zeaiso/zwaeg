// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI
import SwiftData

struct JoinChallengeSheet: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge-Code".loc) {
                    TextField("z.B. K7M2XA", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.fredoka(13))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Beitreten".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen".loc) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Beitreten".loc) {
                            Task { await join() }
                        }
                        .fontWeight(.semibold)
                        .disabled(!BattleScoreEngine.isValidCode(trimmedCode))
                    }
                }
            }
        }
    }

    private func join() async {
        let joinCode = trimmedCode
        guard BattleScoreEngine.isValidCode(joinCode) else {
            errorMessage = BattleSyncError.challengeNotFound(joinCode).errorDescription
            return
        }
        // Challenge.code is unique, so re-inserting would quietly overwrite the
        // local row and wipe my recorded scores for it.
        let duplicates = try? context.fetchCount(FetchDescriptor<Challenge>(
            predicate: #Predicate { $0.code == joinCode }))
        guard (duplicates ?? 0) == 0 else {
            errorMessage = "Bei dieser Challenge machst du schon mit.".loc
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let found = try await ChallengeSyncService.shared.fetchChallenge(code: joinCode)
            let challenge = Challenge.mine(code: joinCode, name: found.name, metric: found.metric,
                                           startDay: found.start, endDay: found.end, profile: profile)
            context.insert(challenge)
            // Compute and push my scores right away: the whole point of joining
            // is that the creator sees me appear on their next refresh. Best
            // effort past this point; the battles screen retries on refresh.
            let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
            await BattleScoreEngine.updateMyScores(
                for: challenge, profile: profile,
                caloriesByDay: BattleScoreEngine.caloriesByDay(entries))
            try? await ChallengeSyncService.shared.refresh(challenge)
            dismiss()
        } catch {
            errorMessage = BattleSyncError.message(for: error)
        }
    }
}

#endif
