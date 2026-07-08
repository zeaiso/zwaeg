import SwiftUI
import SwiftData

struct JoinChallengeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge-Code") {
                    TextField("z.B. K7M2XA", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                }
                if !AppConfig.cloudKitEnabled {
                    Section {
                        Label {
                            Text("Battles mit echten Freunden brauchen iCloud und kommen mit dem Apple Developer Konto. Bis dahin kannst du Challenges gegen Demo-Gegner starten.")
                        } icon: {
                            Image(systemName: "icloud.slash")
                                .foregroundStyle(.secondary)
                        }
                        .font(.fredoka(13))
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.fredoka(13))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Beitreten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Beitreten") { join() }
                            .fontWeight(.semibold)
                            .disabled(code.trimmingCharacters(in: .whitespaces).count != 6 || !AppConfig.cloudKitEnabled)
                    }
                }
            }
        }
    }

    private func join() {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        isLoading = true
        Task {
            defer { isLoading = false }
            let service = CloudKitChallengeService()
            guard let found = try? await service.fetchChallenge(code: trimmed) else {
                errorMessage = "Challenge \(trimmed) nicht gefunden."
                return
            }
            let challenge = Challenge(
                code: trimmed, name: found.name, metric: found.metric,
                startDay: found.start, endDay: found.end,
                participants: [ParticipantScore(
                    id: PlayerIdentity.myID, name: "Du", isMe: true, scores: [:])])
            context.insert(challenge)
            await service.refresh(challenge)
            dismiss()
        }
    }
}
