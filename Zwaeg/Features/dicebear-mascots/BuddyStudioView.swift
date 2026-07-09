import SwiftUI

/// The wardrobe: pick hair, colors, outfit, glasses and beard piece by
/// piece with a live preview. Saving downloads the final image once,
/// so the custom buddy works offline afterwards.
struct BuddyStudioView: View {
    let sex: Sex
    let initialTraits: AvatarTraits?
    let onSave: (Buddy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var traits: AvatarTraits
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(sex: Sex, initialTraits: AvatarTraits?, onSave: @escaping (Buddy) -> Void) {
        self.sex = sex
        self.initialTraits = initialTraits
        self.onSave = onSave
        _traits = State(initialValue: initialTraits ?? .starter(for: sex))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    thumbSection("Frisur".loc, options: AvatarTraits.tops, prefix: "wardrobe-top",
                                 selected: traits.top) { traits.top = $0 }
                    colorSection("Haarfarbe".loc, options: AvatarTraits.hairColors,
                                 selected: traits.hairColor) { traits.hairColor = $0 }
                    colorSection("Hautfarbe".loc, options: AvatarTraits.skinColors,
                                 selected: traits.skinColor) { traits.skinColor = $0 }
                    thumbSection("Outfit".loc, options: AvatarTraits.clothesList, prefix: "wardrobe-clothes",
                                 selected: traits.clothes) { traits.clothes = $0 }
                    colorSection("Outfit-Farbe".loc, options: AvatarTraits.clothesColors,
                                 selected: traits.clothesColor) { traits.clothesColor = $0 }
                    optionalThumbSection("Brille".loc, options: AvatarTraits.accessories, prefix: "wardrobe-acc",
                                         selected: traits.accessory) { traits.accessory = $0 }
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

    private func thumbSection(_ title: String, options: [String], prefix: String,
                              selected: String, pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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
                                      selected: String?, pick: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    noneThumb(isSelected: selected == nil) { pick(nil) }
                    ForEach(options, id: \.self) { option in
                        thumb(name: "\(prefix)-\(option)", isSelected: selected == option) {
                            pick(option)
                        }
                    }
                }
            }
        }
    }

    private func thumb(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.ink : .clear, lineWidth: 2.5))
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

    private func colorSection(_ title: String, options: [String],
                              selected: String, pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.self) { hex in
                        Button {
                            withAnimation(.snappy) { pick(hex) }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(Theme.ink.opacity(selected == hex ? 0.85 : 0.1),
                                                         lineWidth: selected == hex ? 2.5 : 1))
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
                LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
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
