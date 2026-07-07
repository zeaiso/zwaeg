import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            MainTabView(profile: profile)
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    let profile: UserProfile

    var body: some View {
        TabView {
            DiaryView(profile: profile)
                .tabItem { Label("Tagebuch", systemImage: "book.fill") }
            CalculatorsView(profile: profile)
                .tabItem { Label("Rechner", systemImage: "function") }
            ProfileView(profile: profile)
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(.appAccent)
    }
}

extension Color {
    static let appAccent = Color(red: 0.15, green: 0.68, blue: 0.38)
}
