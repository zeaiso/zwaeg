import SwiftData
import SwiftUI

/// DiceBear throttles bursts (style rack plus preview load together),
/// so failed loads retry with a growing delay instead of giving up.
struct StudioAsyncImage: View {
    let url: URL?

    @State private var attempt = 0

    var body: some View {
        AsyncImage(url: retryURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                if attempt < 4 {
                    ProgressView().tint(Color.appAccent)
                        .task {
                            try? await Task.sleep(for: .seconds(Double(attempt) * 0.8 + 0.6))
                            attempt += 1
                        }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.secondary)
                        Text("Vorschau braucht Internet".loc)
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            default:
                ProgressView().tint(Color.appAccent)
            }
        }
    }

    private var retryURL: URL? {
        guard let url, attempt > 0 else { return url }
        return url.appending(queryItems: [URLQueryItem(name: "r", value: "\(attempt)")])
    }
}

/// The wardrobe: pick hair, colors, outfit, glasses and beard piece by
/// piece with a live preview. Saving downloads the final image once,
/// so the custom buddy works offline afterwards.
struct BuddyStudioView: View {
    let sex: Sex
    let initialTraits: AvatarTraits?
    let initialStyled: StyledTraits?
    let onSave: (Buddy) -> Void

    /// The bespoke avataaars editor with bundled thumbnails.
    private static let classicStyle = "avataaars"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var traits: AvatarTraits
    @State private var selectedStyle: String
    @State private var styleTraits: [String: StyledTraits] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var points = 0
    @State private var lockHint: Int?

    init(sex: Sex, initialTraits: AvatarTraits?, initialStyled: StyledTraits? = nil,
         onSave: @escaping (Buddy) -> Void) {
        self.sex = sex
        self.initialTraits = initialTraits
        self.initialStyled = initialStyled
        self.onSave = onSave
        _traits = State(initialValue: initialTraits ?? .starter(for: sex))
        _selectedStyle = State(initialValue: initialStyled?.style ?? Self.classicStyle)
        if let initialStyled {
            _styleTraits = State(initialValue: [initialStyled.style: initialStyled])
        }
    }

    /// Working traits for the selected catalog style.
    private var currentStyled: StyledTraits? {
        guard selectedStyle != Self.classicStyle,
              let spec = StyleCatalog.style(selectedStyle) else { return nil }
        return styleTraits[selectedStyle] ?? .starter(for: spec)
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
            pinnedPreview
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    styleRack
                    if let styled = currentStyled, let spec = StyleCatalog.style(selectedStyle) {
                        styledSections(styled: styled, spec: spec)
                    } else {
                        classicSections
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
            if let flagIndex = CommandLine.arguments.firstIndex(of: "-studio-style"),
               CommandLine.arguments.indices.contains(flagIndex + 1),
               let spec = StyleCatalog.style(CommandLine.arguments[flagIndex + 1]) {
                selectedStyle = spec.id
                if styleTraits[spec.id] == nil {
                    styleTraits[spec.id] = .starter(for: spec)
                }
            }
        }
    }

    /// The avatar stays visible above the racks, so every pick shows
    /// its effect without scrolling back up.
    private var pinnedPreview: some View {
        VStack(spacing: 3) {
            StudioAsyncImage(url: currentStyled?.previewURL ?? traits.previewURL)
                .frame(width: 132, height: 132)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: Theme.shadow.opacity(0.08), radius: 12, y: 5)
                .id(currentStyled?.previewURL?.absoluteString ?? traits.previewURL?.absoluteString ?? "")
            if let spec = StyleCatalog.style(selectedStyle) {
                Text(spec.credit)
                    .font(.fredoka(10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Style rack

    private var styleRack: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Stil".loc)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    styleThumb(id: Self.classicStyle, name: "Klassisch".loc,
                               url: AvatarTraits.starter(for: sex).previewURL)
                    ForEach(StyleCatalog.styles) { style in
                        styleThumb(id: style.id, name: style.name,
                                   url: StyledTraits.starter(for: style).previewURL)
                    }
                }
            }
        }
    }

    private func styleThumb(id: String, name: String, url: URL?) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedStyle = id
                if id != Self.classicStyle, styleTraits[id] == nil,
                   let spec = StyleCatalog.style(id) {
                    styleTraits[id] = .starter(for: spec)
                }
            }
        } label: {
            VStack(spacing: 5) {
                StudioAsyncImage(url: url)
                    .frame(width: 58, height: 58)
                .background(Theme.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(selectedStyle == id ? Theme.ink : .clear, lineWidth: 2.5))
                Text(name)
                    .font(.fredoka(11, .medium))
                    .foregroundStyle(selectedStyle == id ? Theme.ink : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Catalog style sections

    @ViewBuilder
    private func styledSections(styled: StyledTraits, spec: AvatarStyle) -> some View {
        ForEach(spec.colors) { color in
            colorSection(color.title, options: color.presets,
                         selected: styled.colors[color.param] ?? color.presets.first ?? "") { hex in
                update(styled) { $0.colors[color.param] = hex }
            }
        }
        ForEach(spec.options) { option in
            valueChipSection(option, styled: styled)
        }
    }

    private func valueChipSection(_ option: StyleOption, styled: StyledTraits) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(option.title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if option.optional {
                        valueChip("–", isSelected: styled.variants[option.param] == nil) {
                            update(styled) { $0.variants.removeValue(forKey: option.param) }
                        }
                    }
                    ForEach(option.values, id: \.self) { value in
                        valueChip(chipLabel(value), isSelected: styled.variants[option.param] == value) {
                            update(styled) { $0.variants[option.param] = value }
                        }
                    }
                }
            }
        }
    }

    private func valueChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(label)
                .font(.fredoka(13, .medium))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Theme.ink : .clear, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Raw API values become readable, localized labels.
    private func chipLabel(_ value: String) -> String {
        StyleValueNames.label(value)
    }

    private func update(_ styled: StyledTraits, _ change: (inout StyledTraits) -> Void) {
        var copy = styled
        change(&copy)
        styleTraits[selectedStyle] = copy
    }

    // MARK: - Classic avataaars sections

    @ViewBuilder
    private var classicSections: some View {
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
        let styled = currentStyled
        guard let url = styled?.previewURL ?? traits.previewURL else { return }
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
                if let styled {
                    onSave(Buddy.styled(traits: styled, file: filename))
                } else {
                    onSave(Buddy.custom(traits: traits, file: filename))
                }
                dismiss()
            } catch {
                errorMessage = "Zum Speichern brauchst du kurz Internet. Bitte nochmals versuchen.".loc
            }
        }
    }
}
