import SwiftData
import SwiftUI

/// A little robot monster built from DiceBear bottts parts (CC0).
struct MonsterTraits: Codable, Equatable, Hashable {
    var baseColor: String
    var eyes: String
    var mouth: String
    var top: String?
    var sides: String?

    static let eyesList = ["glow", "round", "happy", "hearts", "bulging", "dizzy", "eva",
                           "frame1", "frame2", "robocop", "roundFrame01", "sensor", "shade01"]
    static let mouthList = ["smile01", "smile02", "bite", "grill01", "grill02", "grill03",
                            "diagram", "square01", "square02"]
    static let topList = ["antenna", "antennaCrooked", "bulb01", "lights", "pyramid", "radar",
                          "horns", "glowingBulb01", "glowingBulb02"]
    static let sidesList = ["antenna01", "antenna02", "cables01", "cables02", "round",
                            "square", "squareAssymetric"]

    /// Tops gated behind challenge points.
    static let specialTops = ["horns", "glowingBulb01", "glowingBulb02"]

    static let baseColors = ["ff5c5c", "fe9441", "ffd23e", "9bcc4f", "3fbf7f", "62c1da",
                             "5199e4", "9583f5", "fe61de", "fe538e", "8d99ae", "525a63"]

    static let starter = MonsterTraits(baseColor: "62c1da", eyes: "glow", mouth: "smile01",
                                       top: "antenna", sides: "round")

    /// Live preview through the DiceBear 10.x bottts style.
    var previewURL: URL? {
        var components = URLComponents(string: "https://api.dicebear.com/10.x/bottts/png")
        var items = [
            URLQueryItem(name: "seed", value: "zwaeg"),
            URLQueryItem(name: "size", value: "256"),
            URLQueryItem(name: "backgroundColor", value: "F3ECE7"),
            URLQueryItem(name: "baseColor", value: baseColor),
            URLQueryItem(name: "eyesVariant", value: eyes),
            URLQueryItem(name: "mouthVariant", value: mouth),
            URLQueryItem(name: "mouthProbability", value: "100"),
            URLQueryItem(name: "textureProbability", value: "0"),
        ]
        if let top {
            items.append(URLQueryItem(name: "topVariant", value: top))
            items.append(URLQueryItem(name: "topProbability", value: "100"))
        } else {
            items.append(URLQueryItem(name: "topProbability", value: "0"))
        }
        if let sides {
            items.append(URLQueryItem(name: "sidesVariant", value: sides))
            items.append(URLQueryItem(name: "sidesProbability", value: "100"))
        } else {
            items.append(URLQueryItem(name: "sidesProbability", value: "0"))
        }
        components?.queryItems = items
        return components?.url
    }
}

/// Studio for monsters: base color, eyes, mouth, top and side parts.
struct MonsterStudioView: View {
    let initialTraits: MonsterTraits?
    let onSave: (Buddy) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var traits: MonsterTraits
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var points = 0
    @State private var lockHint: Int?

    init(initialTraits: MonsterTraits?, onSave: @escaping (Buddy) -> Void) {
        self.initialTraits = initialTraits
        self.onSave = onSave
        _traits = State(initialValue: initialTraits ?? .starter)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    colorSection
                    partSection("Augen".loc, options: MonsterTraits.eyesList,
                                selected: traits.eyes) { traits.eyes = $0 ?? traits.eyes }
                    partSection("Mund".loc, options: MonsterTraits.mouthList,
                                selected: traits.mouth) { traits.mouth = $0 ?? traits.mouth }
                    partSection("Oben".loc, options: MonsterTraits.topList,
                                selected: traits.top, allowsNone: true,
                                lockedOptions: unlocked ? [] : MonsterTraits.specialTops) { traits.top = $0 }
                    partSection("Seiten".loc, options: MonsterTraits.sidesList,
                                selected: traits.sides, allowsNone: true) { traits.sides = $0 }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.slash")
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            saveButton
        }
        .background(Theme.background)
        .onAppear {
            if let profile = profiles.first {
                points = ChallengeEngine.points(in: context, profile: profile)
            }
        }
    }

    private var unlocked: Bool {
        points >= UnlockSet.monsterSpecials.requiredPoints
    }

    // MARK: - Header & preview

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.fredoka(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Monster-Studio".loc)
                .font(.fredoka(19, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var preview: some View {
        AsyncImage(url: traits.previewURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit().padding(14)
            case .failure:
                VStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Text("Vorschau braucht Internet".loc)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
            default:
                ProgressView().tint(Color.appAccent)
            }
        }
        .frame(width: 168, height: 168)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.08), radius: 12, y: 5)
        .frame(maxWidth: .infinity)
        .id(traits)
    }

    // MARK: - Sections

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Basisfarbe".loc)
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                if let lockHint {
                    Text("Ab %d Punkten".loc(lockHint))
                        .font(.fredoka(12, .medium))
                        .foregroundStyle(Color.appAccent)
                        .transition(.opacity)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: traits.baseColor) },
                        set: { traits.baseColor = $0.hexString ?? traits.baseColor }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 34, height: 34)
                    ForEach(MonsterTraits.baseColors, id: \.self) { hex in
                        Button {
                            withAnimation(.snappy) { traits.baseColor = hex }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(
                                    Theme.ink.opacity(traits.baseColor == hex ? 0.85 : 0.1),
                                    lineWidth: traits.baseColor == hex ? 2.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func partSection(_ title: String, options: [String], selected: String?,
                             allowsNone: Bool = false, lockedOptions: [String] = [],
                             pick: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if allowsNone {
                        chip(label: "–", isSelected: selected == nil, locked: false) { pick(nil) }
                    }
                    ForEach(options, id: \.self) { option in
                        let locked = lockedOptions.contains(option)
                        chip(label: option, isSelected: selected == option, locked: locked) {
                            if locked {
                                showLockHint()
                            } else {
                                pick(option)
                            }
                        }
                    }
                }
            }
        }
    }

    private func chip(label: String, isSelected: Bool, locked: Bool,
                      action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(label)
                .font(.fredoka(13, .medium))
                .foregroundStyle(locked ? .secondary : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Theme.ink : .clear, lineWidth: 2.5))
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(4)
                            .background(Theme.accent, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func showLockHint() {
        withAnimation(.snappy(duration: 0.2)) {
            lockHint = UnlockSet.monsterSpecials.requiredPoints
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { lockHint = nil }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().tint(Theme.onAccent)
                }
                Text(isSaving ? "Wird gespeichert...".loc : "Speichern".loc)
                    .font(.fredoka(17, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Theme.accentLight, Theme.accent],
                               startPoint: .leading, endPoint: .trailing),
                in: Capsule())
            .foregroundStyle(Theme.onAccent)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.background)
    }

    private func save() {
        guard let url = traits.previewURL else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard UIImage(data: data) != nil else {
                    throw URLError(.cannotDecodeContentData)
                }
                let filename = "custom-buddy-\(UUID().uuidString).png"
                let folder = try FileManager.default.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil, create: true)
                try data.write(to: folder.appendingPathComponent(filename))
                onSave(Buddy.monster(traits: traits, file: filename))
                dismiss()
            } catch {
                errorMessage = "Zum Speichern brauchst du kurz Internet. Bitte nochmals versuchen.".loc
            }
        }
    }
}
