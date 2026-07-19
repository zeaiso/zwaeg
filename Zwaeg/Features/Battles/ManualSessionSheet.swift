// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import SwiftUI
import SwiftData
import PhotosUI

/// Adds treadmill (or similar) sessions to today's step battle score — but
/// only with a photo of the machine's display as proof. The photos stay on
/// this device; opponents see the day badged as manual. Several sessions a
/// day are fine, each with its own photo.
struct ManualSessionSheet: View {
    let challenge: Challenge
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var manualEntries: [BattleManualEntry]
    @Query private var foodEntries: [FoodEntry]

    @State private var distanceText = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var proofImage: UIImage?
    @State private var proofCapturedAt = Date.now
    @State private var duplicateRejected = false
    @State private var showCamera = false
    @State private var isSaving = false
    @FocusState private var distanceFocused: Bool

    /// Average steps per walked kilometer; a rough everyday value, the
    /// entry is meant for orders of magnitude, not lab precision.
    private static let stepsPerKm = 1300.0
    private static let maxKm = 50.0
    /// 3-4 treadmill runs a day are real; a dozen is somebody testing limits.
    private static let maxEntriesPerDay = 6

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var todayEntries: [BattleManualEntry] {
        manualEntries.filter { $0.day == today }.sorted { $0.createdAt < $1.createdAt }
    }

    private var distanceKm: Double {
        min(Self.maxKm, Double(distanceText.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var steps: Int {
        Int((distanceKm * Self.stepsPerKm).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    if !todayEntries.isEmpty {
                        existingCard(todayEntries)
                    }
                    if todayEntries.count < Self.maxEntriesPerDay {
                        distanceCard
                        proofCard
                    }
                }
                .padding(20)
            }
            if todayEntries.count < Self.maxEntriesPerDay {
                saveButton
            }
        }
        .background(Theme.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig".loc) { distanceFocused = false }
                    .font(.fredoka(15, .semibold))
            }
        }
        .onChange(of: pickedItem) {
            guard let item = pickedItem else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                accept(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ProofCamera { image in
                accept(image)
            }
            .ignoresSafeArea()
        }
    }

    /// A fresh photo passes; one that perceptually matches an earlier proof
    /// is rejected — the same treadmill picture can't score twice.
    private func accept(_ image: UIImage) {
        let hash = ImageHash.dHash(image)
        let reused = manualEntries.contains {
            !$0.photoHash.isEmpty && ImageHash.isNearDuplicate($0.photoHash, hash)
        }
        withAnimation(.snappy) {
            duplicateRejected = reused
            proofImage = reused ? nil : image
            proofCapturedAt = .now
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(Theme.field)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text("Training nachtragen".loc)
                .font(.fredoka(24, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Laufband ohne Handy in der Tasche? Trag die Distanz nach — mit einem Foto vom Display als Beleg. Fair bleibt fair.".loc)
                .font(.fredoka(13))
                .foregroundStyle(.secondary)
        }
    }

    private var distanceCard: some View {
        Card {
            HStack {
                Text("Distanz".loc)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                TextField("0.0", text: $distanceText)
                    .keyboardType(.decimalPad)
                    .focused($distanceFocused)
                    .font(.fredoka(19, .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 76)
                    .padding(.vertical, 5)
                    .background(Theme.field.opacity(distanceFocused ? 0.8 : 0.5),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("km")
                    .font(.fredoka(14))
                    .foregroundStyle(.secondary)
            }
            if steps > 0 {
                Text("≈ %d Schritte".loc(steps))
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentTransition(.numericText())
            }
        }
    }

    private var proofCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Foto-Beleg".loc)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.ink)
                if let proofImage {
                    Image(uiImage: proofImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if duplicateRejected {
                    Text("Dieses Foto wurde schon einmal verwendet. Mach ein frisches Foto.".loc)
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.red)
                }
                if ProofCamera.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        cameraLabel
                    }
                    .buttonStyle(.plain)
                } else {
                    // Simulator has no camera; devices must shoot live.
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        cameraLabel
                    }
                    .buttonStyle(.plain)
                }
                Text("Direkt mit der Kamera aufnehmen — Zeitpunkt wird für alle sichtbar festgehalten. Die anderen im Battle können den Beleg ansehen.".loc)
                    .font(.fredoka(12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func existingCard(_ entries: [BattleManualEntry]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heute schon nachgetragen".loc)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.ink)
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Group {
                            if let url = ProgressPhotos.imageURL(name: entry.photoFile),
                               let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Theme.field
                            }
                        }
                        .frame(width: 46, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("%@ km · %d Schritte".loc(
                            entry.distanceKm.formatted(.number.precision(.fractionLength(0...1))),
                            entry.steps))
                            .font(.fredoka(14, .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button {
                            ProgressPhotos.deleteFile(name: entry.photoFile)
                            context.delete(entry)
                            Task { await resync() }
                        } label: {
                            Image(systemName: "trash")
                                .font(.fredoka(13, .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Theme.field.opacity(0.6), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var cameraLabel: some View {
        Label(proofImage == nil ? "Foto aufnehmen".loc : "Neues Foto aufnehmen".loc,
              systemImage: "camera.fill")
            .font(.fredoka(14, .semibold))
            .foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.accentSoft, in: Capsule())
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Zum Battle hinzufügen".loc)
                .font(.fredoka(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.accentLight, Theme.accent],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule())
                .foregroundStyle(Theme.onAccent)
        }
        .buttonStyle(.plain)
        .disabled(steps <= 0 || proofImage == nil || isSaving)
        .opacity(steps <= 0 || proofImage == nil ? 0.5 : 1)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    private func save() {
        guard let proofImage, steps > 0, !isSaving else { return }
        isSaving = true
        let file = "battle-proof-\(Int(Date.now.timeIntervalSince1970)).jpg"
        guard ProgressPhotos.saveJPEG(proofImage, name: file) else {
            isSaving = false
            return
        }
        context.insert(BattleManualEntry(day: today, steps: steps,
                                         distanceKm: distanceKm, photoFile: file,
                                         capturedAt: proofCapturedAt,
                                         photoHash: ImageHash.dHash(proofImage)))
        distanceText = ""
        self.proofImage = nil
        isSaving = false
        Task { await resync() }
    }

    /// Recomputes and pushes the score so opponents see the new total (and
    /// the manual-day badge) right away.
    private func resync() async {
        let calories = BattleScoreEngine.caloriesByDay(foodEntries)
        let manual = BattleScoreEngine.manualStepsByDay(
            (try? context.fetch(FetchDescriptor<BattleManualEntry>())) ?? [])
        await BattleScoreEngine.updateMyScores(for: challenge, profile: profile,
                                               caloriesByDay: calories,
                                               manualStepsByDay: manual)
        if challenge.code != Challenge.demoCode {
            try? await ChallengeSyncService.shared.refresh(challenge)
            await ChallengeSyncService.shared.pushProofs(
                for: challenge,
                entries: (try? context.fetch(FetchDescriptor<BattleManualEntry>())) ?? [])
        }
    }
}

#endif
