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
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 1: BattlesScreen(profile: profile)
                case 2: ScannerScreen(profile: profile)
                case 3: CalculatorsView(profile: profile)
                case 4: ProfileView(profile: profile)
                default: DiaryView(profile: profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 66)
            }

            ZnueniTabBar(selection: $selection)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(.appAccent)
    }
}

/// Floating pill tab bar with a raised scan button in the middle.
struct ZnueniTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(0, symbol: "house.fill", label: "Tagebuch")
            tabButton(1, symbol: "flame.fill", label: "Battles")
            scanButton
            tabButton(3, symbol: "chart.bar.fill", label: "Rechner")
            tabButton(4, symbol: "person.fill", label: "Profil")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.card, in: Capsule())
        .shadow(color: Theme.ink.opacity(0.10), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func tabButton(_ index: Int, symbol: String, label: String) -> some View {
        Button {
            selection = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == index ? Color.appAccent : Color(.systemGray))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(selection == index ? Theme.accentSoft : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var scanButton: some View {
        Button {
            selection = 2
        } label: {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 54, height: 54)
                .background(selection == 2 ? Theme.ink : Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .offset(y: -14)
        .frame(maxWidth: .infinity)
    }
}
