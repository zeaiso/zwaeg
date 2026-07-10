import SwiftUI
import SwiftData

/// Debug-only launch arguments used to drive the app from the command line
/// (e.g. simulator screenshots): -seed-profile, -tab <index>.
enum LaunchArgs {
    /// All debug launch arguments; empty in release builds so none of the
    /// development shortcuts (seeds, deep links, style overrides) exist there.
    static let all: [String] = {
        #if DEBUG
        CommandLine.arguments
        #else
        []
        #endif
    }()

    static var seedProfile: Bool {
        all.contains("-seed-profile")
    }

    static var initialTab: Int {
        if all.contains("-open-fasting") { return 6 }
        guard let flagIndex = all.firstIndex(of: "-tab"),
              all.indices.contains(flagIndex + 1),
              let tab = Int(all[flagIndex + 1]) else { return 0 }
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
        .environment(\.locale, Lingo.shared.language.locale)
        .environment(\.layoutDirection, Lingo.shared.language.isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            if LaunchArgs.seedProfile && BuddyCloset.load().isEmpty {
                BuddyCloset.add(Buddy(kind: "m", index: 7))
                BuddyCloset.add(Buddy(kind: "f", index: 42))
                BuddyCloset.add(Buddy(kind: "blob", index: 4))
            }
            if profiles.isEmpty && LaunchArgs.seedProfile {
                context.insert(UserProfile(name: "Livia", sex: .female, age: 30, heightCm: 178,
                                           weightKg: 78, activity: .moderate, goal: .lose))
                for week in 0..<9 {
                    if let date = Calendar.current.date(byAdding: .weekOfYear, value: -week, to: .now) {
                        context.insert(WeightEntry(date: date, weightKg: 78 + Double(week) * 0.45))
                    }
                }
                // Daily entries so the 7-day weight chart has a line too.
                for day in 1...6 {
                    if let date = Calendar.current.date(byAdding: .day, value: -day, to: .now) {
                        context.insert(WeightEntry(date: date, weightKg: 78 + Double(day) * 0.12))
                    }
                }
                if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                    context.insert(FoodEntry(day: yesterday, meal: .breakfast, name: "Birchermüesli",
                                             calories: 320, proteinG: 12, carbsG: 45, fatG: 9))
                    context.insert(FoodEntry(day: yesterday, meal: .breakfast, name: "Kaffee mit Milch",
                                             calories: 40, proteinG: 2, carbsG: 3, fatG: 2))
                }
                if let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now) {
                    context.insert(FoodEntry(day: twoDaysAgo, meal: .lunch, name: "Rösti mit Spiegelei",
                                             calories: 540, proteinG: 18, carbsG: 52, fatG: 26))
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
                        ParticipantScore(id: PlayerIdentity.myID, name: "Livia", isMe: true,
                                         scores: ["seed": 24500]),
                        ParticipantScore(id: "bot-Luca", name: "Luca", isMe: false, scores: [:]),
                        ParticipantScore(id: "bot-Mia", name: "Mia", isMe: false, scores: [:]),
                    ]))
            }
        }
    }
}

/// Shared tab selection so any screen (e.g. the add-food scan banner) can switch tabs.
/// Detail pages with their own bottom actions can hide the floating tab bar.
@Observable
final class TabRouter {
    static let shared = TabRouter()
    var selection = LaunchArgs.initialTab
    var tabBarHidden = false
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
                case 5: RecipesScreen(profile: profile)
                case 6: NavigationStack { FastingView(profile: profile) }
                default: DiaryView(profile: profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: router.tabBarHidden ? 0 : 66)
            }

            if !router.tabBarHidden {
                ZwaegTabBar(router: router)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: router.tabBarHidden)
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
            tabButton(5, symbol: "book.fill")
            tabButton(6, symbol: "timer")
            scanButton
            tabButton(1, symbol: "flame.fill")
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
