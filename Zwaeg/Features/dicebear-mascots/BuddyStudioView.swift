import SwiftData
import SwiftUI

/// The wardrobe: pick hair, colors, outfit, glasses and beard piece by
/// piece with a live preview. Saving downloads the final image once,
/// so the custom buddy works offline afterwards.
struct BuddyStudioView: View {
    let sex: Sex
    let initialTraits: AvatarTraits?
    let onSave: (Buddy) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var traits: AvatarTraits
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var points = 0
    @State private var lockHint: Int?

    init(sex: Sex, initialTraits: AvatarTraits?, onSave: @escaping (Buddy) -> Void) {
        self.sex = sex
        self.initialTraits = initialTraits
        self.onSave = onSave
        _traits = State(initialValue: initialTraits ?? .starter(for: sex))
    }

    /// Fun one-tap looks; some unlock with challenge points.
    private var presets: [(name: String, emoji: String, unlock: UnlockSet?, apply: (inout AvatarTraits) -> Void)] {
        [("Nerd", "🤓", nil, { traits in
            traits.top = "shortFlat"; traits.accessory = "prescription01"
            traits.clothes = "collarAndSweater"; traits.mouth = "smile"
         }),
         ("Rockstar", "🤘", nil, { traits in
            traits.top = "fro"; traits.clothes = "graphicShirt"; traits.clothesColor = "262e33"
            traits.clothesGraphic = "skull"; traits.eyes = "squint"; traits.mouth = "tongue"
         }),
         ("Pirat", "🏴‍☠️", .piratLook, { traits in
            traits.top = "shaggyMullet"; traits.accessory = "eyepatch"
            traits.facialHair = "beardMajestic"; traits.clothes = "shirtVNeck"
            traits.mouth = "grimace"
         }),
         ("Ninja", "🥷", .ninjaLook, { traits in
            traits.top = "turban"; traits.hairColor = "2c1b18"; traits.clothes = "shirtCrewNeck"
            traits.clothesColor = "262e33"; traits.accessory = "sunglasses"
            traits.facialHair = nil; traits.eyes = "default"; traits.mouth = "serious"
         })]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    presetSection
                    thumbSection("Frisur".loc, options: AvatarTraits.tops, prefix: "wardrobe-top",
                                 selected: traits.top, allowsNone: true) { traits.top = $0 ?? "" }
                    colorSection("Haarfarbe".loc, options: AvatarTraits.hairColors,
                                 selected: traits.hairColor,
                                 lockedOptions: unlocked(.neonHair) ? [] : AvatarTraits.neonHairColors,
                                 lockSet: .neonHair) { traits.hairColor = $0 }
                    colorSection("Hautfarbe".loc, options: AvatarTraits.skinColors,
                                 selected: traits.skinColor) { traits.skinColor = $0 }
                    chipSection("Augen".loc, options: AvatarTraits.eyesList,
                                selected: traits.eyes ?? "default") { traits.eyes = $0 }
                    chipSection("Mund".loc, options: AvatarTraits.mouthList,
                                selected: traits.mouth ?? "smile") { traits.mouth = $0 }
                    thumbSection("Outfit".loc, options: AvatarTraits.clothesList, prefix: "wardrobe-clothes",
                                 selected: traits.clothes, allowsNone: false) { traits.clothes = $0 ?? "hoodie" }
                    if traits.clothes == "graphicShirt" {
                        chipSection("Motiv".loc, options: AvatarTraits.clothesGraphics,
                                    selected: traits.clothesGraphic ?? "skull") { traits.clothesGraphic = $0 }
                    }
                    colorSection("Outfit-Farbe".loc, options: AvatarTraits.clothesColors,
                                 selected: traits.clothesColor) { traits.clothesColor = $0 }
                    optionalThumbSection("Brille".loc, options: AvatarTraits.accessories, prefix: "wardrobe-acc",
                                         selected: traits.accessory,
                                         lockedOptions: unlocked(.specialExtras) ? [] : AvatarTraits.specialAccessories,
                                         lockSet: .specialExtras) { traits.accessory = $0 }
                    optionalThumbSection("Bart".loc, options: AvatarTraits.facialHairs, prefix: "wardrobe-beard",
                                         selected: traits.facialHair) { traits.facialHair = $0 }
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

    // MARK: - Unlocks

    private func unlocked(_ set: UnlockSet) -> Bool {
        points >= set.requiredPoints
    }

    private func showLockHint(_ set: UnlockSet) {
        withAnimation(.snappy(duration: 0.2)) {
            lockHint = set.requiredPoints
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { lockHint = nil }
        }
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
            Text("Avatar-Studio")
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
                image.resizable().scaledToFit()
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.fredoka(15, .semibold))
            .foregroundStyle(Theme.ink)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                sectionLabel("Looks")
                if let lockHint {
                    Text("Ab %d Punkten".loc(lockHint))
                        .font(.fredoka(12, .medium))
                        .foregroundStyle(Color.appAccent)
                        .transition(.opacity)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.name) { preset in
                        let locked = preset.unlock.map { !unlocked($0) } ?? false
                        Button {
                            if locked, let set = preset.unlock {
                                showLockHint(set)
                            } else {
                                withAnimation(.snappy) { preset.apply(&traits) }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                EmojiOrSymbol(emoji: preset.emoji, symbol: "person.fill", size: 26)
                                    .opacity(locked ? 0.35 : 1)
                                Text(preset.name)
                                    .font(.fredoka(12, .medium))
                                    .foregroundStyle(locked ? .secondary : Theme.ink)
                            }
                            .frame(width: 74, height: 68)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(alignment: .topTrailing) {
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.onAccent)
                                        .padding(5)
                                        .background(Theme.accent, in: Circle())
                                        .offset(x: -5, y: 5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func chipSection(_ title: String, options: [(id: String, emoji: String)],
                             selected: String, pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.id) { option in
                        Button {
                            withAnimation(.snappy) { pick(option.id) }
                        } label: {
                            Group {
                                if EmojiSupport.available {
                                    Text(option.emoji)
                                        .font(.system(size: 26))
                                } else {
                                    Text(option.id)
                                        .font(.fredoka(11, .medium))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .padding(.horizontal, 4)
                                }
                            }
                            .frame(width: 52, height: 52)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(selected == option.id ? Theme.ink : .clear, lineWidth: 2.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func thumbSection(_ title: String, options: [String], prefix: String,
                              selected: String, allowsNone: Bool,
                              pick: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if allowsNone {
                        noneThumb(isSelected: selected.isEmpty) { pick(nil) }
                    }
                    ForEach(options, id: \.self) { option in
                        thumb(name: "\(prefix)-\(option)", isSelected: selected == option) {
                            pick(option)
                        }
                    }
                }
            }
        }
    }

    private func optionalThumbSection(_ title: String, options: [String], prefix: String,
                                      selected: String?,
                                      lockedOptions: [String] = [], lockSet: UnlockSet? = nil,
                                      pick: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    noneThumb(isSelected: selected == nil) { pick(nil) }
                    ForEach(options, id: \.self) { option in
                        let locked = lockedOptions.contains(option)
                        thumb(name: "\(prefix)-\(option)", isSelected: selected == option,
                              locked: locked) {
                            if locked, let lockSet {
                                showLockHint(lockSet)
                            } else {
                                pick(option)
                            }
                        }
                    }
                }
            }
        }
    }

    private func thumb(name: String, isSelected: Bool, locked: Bool = false,
                       action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .opacity(locked ? 0.35 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.ink : .clear, lineWidth: 2.5))
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(5)
                            .background(Theme.accent, in: Circle())
                            .offset(x: -3, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func noneThumb(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: "slash.circle")
                .font(.fredoka(20))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.ink : .clear, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    private func colorSection(_ title: String, options: [String], selected: String,
                              lockedOptions: [String] = [], lockSet: UnlockSet? = nil,
                              pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Any color at all, like the app accent.
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: selected) },
                        set: { if let hex = $0.hexString { pick(hex) } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 34, height: 34)
                    ForEach(options, id: \.self) { hex in
                        let locked = lockedOptions.contains(hex)
                        Button {
                            if locked, let lockSet {
                                showLockHint(lockSet)
                            } else {
                                withAnimation(.snappy) { pick(hex) }
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .opacity(locked ? 0.4 : 1)
                                .overlay(Circle().stroke(Theme.ink.opacity(selected == hex ? 0.85 : 0.1),
                                                         lineWidth: selected == hex ? 2.5 : 1))
                                .overlay {
                                    if locked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
                onSave(Buddy.custom(traits: traits, file: filename))
                dismiss()
            } catch {
                errorMessage = "Zum Speichern brauchst du kurz Internet. Bitte nochmals versuchen.".loc
            }
        }
    }
}
