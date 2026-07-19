import SwiftUI

/// Renders a buddy as a rounded chip. Blobs live in the asset catalog,
/// the avatar pools are loose bundled PNGs, so load via UIImage which
/// searches both (and caches).
struct BuddyView: View {
    let buddy: Buddy
    var size: CGFloat = 46

    var body: some View {
        Group {
            if buddy.kind == "person" {
                BuddyCharacterView(traits: buddy.person ?? PersonTraits())
                    .padding(size * 0.04)
            } else if let path = buddy.customImagePath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: buddy.kind == "photo" ? .fill : .fit)
            } else if !buddy.assetName.isEmpty, let image = UIImage(named: buddy.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(Theme.field)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
