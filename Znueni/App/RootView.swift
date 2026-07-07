import SwiftUI
import SwiftData

/// Debug-only launch arguments used to drive the app from the command line
/// (e.g. simulator screenshots): -seed-profile, -tab <index>.
enum LaunchArgs {
    static var seedProfile: Bool { CommandLine.arguments.contains("-seed-profile") }

    static var initialTab: Int {
        guard let flagIndex = CommandLine.arguments.firstIndex(of: "-tab"),
              CommandLine.arguments.indices.contains(flagIndex + 1),
              let tab = Int(CommandLine.arguments[flagIndex + 1]) else { return 0 }
        return tab
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            if profiles.isEmpty && LaunchArgs.seedProfile {
                context.insert(UserProfile(name: "Test", sex: .male, age: 30, heightCm: 178,
                                           weightKg: 78, activity: .moderate, goal: .lose))
                for week in 0..<9 {
                    if let date = Calendar.current.date(byAdding: .weekOfYear, value: -week, to: .now) {
                        context.insert(WeightEntry(date: date, weightKg: 78 + Double(week) * 0.45))
                    }
                }
            }
        }
    }
}

struct MainTabView: View {
    let profile: UserProfile

    @State private var selection = LaunchArgs.initialTab

    var body: some View {
        TabView(selection: $selection) {
            DiaryView(profile: profile)
                .tabItem { Label("Tagebuch", systemImage: "book.fill") }
                .tag(0)
            ScannerScreen(profile: profile)
                .tabItem { Label("Scannen", systemImage: "barcode.viewfinder") }
                .tag(1)
            CalculatorsView(profile: profile)
                .tabItem { Label("Rechner", systemImage: "function") }
                .tag(2)
            ProfileView(profile: profile)
                .tabItem { Label("Profil", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(.appAccent)
    }
}

extension Color {
    static let appAccent = Color(red: 0.15, green: 0.68, blue: 0.38)
}
