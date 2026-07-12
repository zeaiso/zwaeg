import SwiftUI
import PhotosUI

/// Buddy picker: hero preview, pool switch, dice and studio actions,
/// and the closet of saved looks with visible delete badges.
struct BuddyPickerView: View {
    @Binding var buddy: Buddy
    var sex: Sex

    @State private var showStudio = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var saved: [Buddy] = BuddyCloset.load()

    private var debugOpensStudio: Bool {
        LaunchArgs.all.contains("-open-studio")
    }

    private let closetColumns = [GridItem(.adaptive(minimum: 68), spacing: 12)]

    var body: some View {
        VStack(spacing: 22) {
            hero
            poolSwitch
            actionRow
            closet
        }
        .onAppear {
            if debugOpensStudio {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    showStudio = true
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            photoItem = nil
            Task { await applyPhoto(item) }
        }
        .sheet(isPresented: $showStudio) {
            BuddyStudioView(sex: sex, initialTraits: buddy.traits,
                            initialStyled: buddy.styled) { custom in
                buddy = custom
                BuddyCloset.add(custom)
                saved = BuddyCloset.load()
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(buddy.bodyColor.opacity(0.18))
                    .frame(width: 216, height: 216)
                Circle()
                    .fill(Theme.card)
                    .frame(width: 192, height: 192)
                if buddy.kind == "person" {
                    BuddyCharacterView(traits: buddy.person ?? PersonTraits(), factor: 0.35)
                        .frame(height: 172)
                        .shadow(color: buddy.bodyColor.opacity(0.35), radius: 16, y: 8)
                } else {
                    BuddyView(buddy: buddy, size: 164)
                        .shadow(color: buddy.bodyColor.opacity(0.35), radius: 16, y: 8)
                }
            }
            .animation(.snappy, value: buddy)

            Button {
                withAnimation(.snappy) {
                    BuddyCloset.add(buddy)
                    saved = BuddyCloset.load()
                }
            } label: {
                Image(systemName: saved.contains(buddy) ? "bookmark.fill" : "bookmark")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(saved.contains(buddy) ? Color.appAccent : Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pool switch

    private var poolSwitch: some View {
        HStack(spacing: 4) {
            poolSegment("Funky", isActive: !["blob", "person"].contains(buddy.kind)) {
                buddy = .random(for: sex)
            }
            poolSegment("Blob", isActive: buddy.kind == "blob") {
                buddy = .randomBlob()
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
        .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
    }

    private func poolSegment(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(label)
                .font(.fredoka(14, .semibold))
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(isActive ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(.clear), in: Capsule())
                .foregroundStyle(isActive ? Theme.onInk : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            actionCard(symbol: "dice.fill", title: "Würfeln".loc,
                       subtitle: "Zufälliger Look".loc,
                       background: AnyShapeStyle(LinearGradient(
                          colors: [Theme.accentLight, Theme.accent],
                          startPoint: .topLeading, endPoint: .bottomTrailing))) {
                switch buddy.kind {
                case "blob": buddy = .randomBlob()
                case "person": buddy = .randomPerson()
                default: buddy = .random(for: sex)
                }
            }
            actionCard(symbol: "tshirt.fill", title: "Studio",
                       subtitle: "Selbst gestalten".loc,
                       background: AnyShapeStyle(Theme.ink),
                       foreground: Theme.onInk) {
                showStudio = true
            }
            actionCard(symbol: "photo.fill", title: "Foto".loc,
                       subtitle: "Eigenes Bild".loc,
                       background: AnyShapeStyle(Theme.card),
                       foreground: Theme.ink) {
                showPhotoPicker = true
            }
        }
    }

    /// Saves a square, downscaled copy of the picked photo and wears it.
    private func applyPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2,
                          y: (image.size.height - side) / 2,
                          width: side, height: side)
        let target: CGFloat = 512
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
            .image { _ in
                let scale = target / side
                image.draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale,
                                      width: image.size.width * scale,
                                      height: image.size.height * scale))
            }
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85),
              let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let file = "photo-\(UUID().uuidString).jpg"
        try? jpeg.write(to: folder.appendingPathComponent(file))
        withAnimation(.snappy) {
            let look = Buddy.photo(file: file)
            buddy = look
            BuddyCloset.add(look)
            saved = BuddyCloset.load()
        }
    }

    private func actionCard(symbol: String, title: String, subtitle: String,
                            background: AnyShapeStyle, foreground: Color = .white,
                            action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.fredoka(18, .semibold))
                Text(title)
                    .font(.fredoka(17, .semibold))
                Text(subtitle)
                    .font(.fredoka(12))
                    .opacity(0.85)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Theme.shadow.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Closet

    @ViewBuilder
    private var closet: some View {
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gespeicherte Looks".loc)
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(saved.count)/\(BuddyCloset.capacity)")
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: closetColumns, spacing: 14) {
                    ForEach(saved, id: \.self) { look in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                withAnimation(.snappy) { buddy = look }
                            } label: {
                                BuddyView(buddy: look, size: 68)
                                    .overlay(RoundedRectangle(cornerRadius: 68 * 0.3, style: .continuous)
                                        .stroke(buddy == look ? Theme.ink : .clear, lineWidth: 2.5))
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.snappy) {
                                    BuddyCloset.remove(look, keepingFileOf: buddy)
                                    saved = BuddyCloset.load()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 19, height: 19)
                                    .background(Theme.ink.opacity(0.85), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 7, y: -7)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.shadow.opacity(0.05), radius: 8, y: 3)
        }
    }
}
