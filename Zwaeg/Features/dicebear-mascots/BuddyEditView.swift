import SwiftUI

/// Change your buddy any time; picks save immediately.
struct BuddyEditView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                BuddyPickerView(buddy: Binding(
                    get: { profile.buddy },
                    set: { profile.buddy = $0 }),
                    sex: profile.sex)
                Text("Dein Buddy begleitet dich im Tagebuch, im Profil und in Battles.")
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Mein Buddy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
