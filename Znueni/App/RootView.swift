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
                let start = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
                let end = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
                context.insert(Challenge(
                    code: "DEMO42", name: "Wochenbattle", metric: .steps,
                    startDay: start, endDay: end,
                    participants: [
                        ParticipantScore(id: PlayerIdentity.myID, name: "Test", isMe: true,
                                         scores: ["seed": 24500]),
                        ParticipantScore(id: "bot-Luca", name: "Luca", isMe: false, scores: [:]),
                        ParticipantScore(id: "bot-Mia", name: "Mia", isMe: false, scores: [:]),
                    ]))
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
            BattlesScreen(profile: profile)
                .tabItem { Label("Battles", systemImage: "trophy.fill") }
                .tag(2)
            CalculatorsView(profile: profile)
                .tabItem { Label("Rechner", systemImage: "function") }
                .tag(3)
            ProfileView(profile: profile)
                .tabItem { Label("Profil", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(.appAccent)
    }
}

extension Color {
    static let appAccent = Color(red: 0.15, green: 0.68, blue: 0.38)
}
