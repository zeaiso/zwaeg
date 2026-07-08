import SwiftUI

/// Renders a buddy from the bundled vector set as a rounded chip.
struct BuddyView: View {
    let buddy: Buddy
    var size: CGFloat = 46

    var body: some View {
        Image(buddy.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
