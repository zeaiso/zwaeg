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
        .preferredColorScheme(Theme.colorScheme)
        .grayscale(Theme.grayscale)
        .onAppear {
            if LaunchArgs.seedProfile && BuddyCloset.load().isEmpty {
                BuddyCloset.add(Buddy(kind: "m", index: 7))
                BuddyCloset.add(Buddy(kind: "f", index: 42))
                BuddyCloset.add(Buddy(kind: "blob", index: 4))
            }
            if profiles.isEmpty && LaunchArgs.seedProfile {
                context.insert(UserProfile(name: "Test", sex: .male, age: 30, heightCm: 178,
                                           weightKg: 78, activity: .moderate, goal: .lose))
                for week in 0..<9 {
                    if let date = Calendar.current.date(byAdding: .weekOfYear, value: -week, to: .now) {
                        context.insert(WeightEntry(date: date, weightKg: 78 + Double(week) * 0.45))
                    }
                }
                if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                    context.insert(FoodEntry(day: yesterday, meal: .breakfast, name: "Birchermüesli",
                                             calories: 320, proteinG: 12, carbsG: 45, fatG: 9))
                    context.insert(FoodEntry(day: yesterday, meal: .breakfast, name: "Kaffee mit Milch",
                                             calories: 40, proteinG: 2, carbsG: 3, fatG: 2))
                }
                context.insert(FoodEntry(day: .now, meal: .breakfast, name: "Birchermüesli",
                                         calories: 320, proteinG: 12, carbsG: 45, fatG: 9))
                context.insert(FoodEntry(day: .now, meal: .breakfast, name: "Kaffee mit Milch",
                                         calories: 40, proteinG: 2, carbsG: 3, fatG: 2))
                context.insert(FoodEntry(day: .now, meal: .lunch, name: "Älplermagronen",
                                         calories: 620, proteinG: 22, carbsG: 68, fatG: 28))
                context.insert(WaterDay(day: .now, glasses: 3))
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

/// Shared tab selection so any screen (e.g. the add-food scan banner) can switch tabs.
@Observable
final class TabRouter {
    static let shared = TabRouter()
    var selection = LaunchArgs.initialTab
}

struct MainTabView: View {
    let profile: UserProfile

    @State private var router = TabRouter.shared

    private var selection: Int { router.selection }

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

            ZwaegTabBar(router: router)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(.appAccent)
    }
}

/// Floating pill tab bar, icon only: active tab in a coral circle, dark scan button.
struct ZwaegTabBar: View {
    @Bindable var router: TabRouter

    var body: some View {
        HStack(spacing: 0) {
            tabButton(0, symbol: "house.fill")
            tabButton(1, symbol: "flame.fill")
            scanButton
            tabButton(3, symbol: "chart.bar.fill")
            tabButton(4, symbol: "person.fill")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.card, in: Capsule())
        .shadow(color: Theme.shadow.opacity(0.10), radius: 16, y: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private func tabButton(_ index: Int, symbol: String) -> some View {
        Button {
            router.selection = index
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(router.selection == index ? Theme.onAccent : Color(.systemGray2))
                .frame(width: 46, height: 46)
                .background(router.selection == index ? AnyShapeStyle(Theme.accent.gradient)
                                                      : AnyShapeStyle(.clear),
                            in: Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var scanButton: some View {
        Button {
            router.selection = 2
        } label: {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(router.selection == 2 ? Theme.onAccent : Color.appAccent)
                .frame(width: 56, height: 56)
                .background(Theme.ink, in: Circle())
                .shadow(color: Theme.shadow.opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .offset(y: -16)
        .frame(maxWidth: .infinity)
    }
}
