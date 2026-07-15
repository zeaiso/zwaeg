import SwiftUI
import SwiftData

struct JoinChallengeSheet: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var challenges: [Challenge]

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// Codes become CloudKit record names, so keep them to the strict A–Z/0–9
    /// alphabet they are generated from.
    private var isCodeValid: Bool {
        trimmedCode.count == 6 && trimmedCode.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
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
                        .disabled(!isCodeValid)
                    }
                }
            }
        }
    }

    private func join() async {
        let joinCode = trimmedCode
        guard isCodeValid else {
            errorMessage = BattleSyncError.challengeNotFound(joinCode).errorDescription
            return
        }
        // Challenge.code is unique, so re-inserting would quietly overwrite the
        // local row and wipe my recorded scores for it.
        guard !challenges.contains(where: { $0.code == joinCode }) else {
            errorMessage = "Bei dieser Challenge machst du schon mit.".loc
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let found = try await ChallengeSyncService.shared.fetchChallenge(code: joinCode)
            let challenge = Challenge(
                code: joinCode, name: found.name, metric: found.metric,
                startDay: found.start, endDay: found.end,
                participants: [ParticipantScore(
                    id: PlayerIdentity.myID, name: profile.battleName, isMe: true, scores: [:])])
            context.insert(challenge)
            // Best effort: the challenge is already joined, and the next refresh
            // on the battles screen will fill in everyone's scores anyway.
            try? await ChallengeSyncService.shared.refresh(challenge)
            dismiss()
        } catch {
            errorMessage = (error as? BattleSyncError ?? .failed).errorDescription
        }
    }
}
