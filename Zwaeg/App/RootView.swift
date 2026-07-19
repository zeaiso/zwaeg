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
            if let profile = profiles.first {
                BuddyCloset.sweepOrphanedFiles(worn: profile.buddy)
            }
            if LaunchArgs.seedProfile && BuddyCloset.load().isEmpty {
                BuddyCloset.add(Buddy(kind: "m", index: 7))
                BuddyCloset.add(Buddy(kind: "f", index: 42))
                BuddyCloset.add(Buddy(kind: "blob", index: 4))
            }
            if LaunchArgs.all.contains("-seed-custom-food"),
               (try? context.fetchCount(FetchDescriptor<CustomFood>())) == 0 {
                context.insert(CustomFood(name: "Proteinriegel Choco", brand: "Zwäg",
                                          kcalPer100g: 380, proteinPer100g: 30,
                                          carbsPer100g: 40, fatPer100g: 12,
                                          barcode: "4041234567890", servingGrams: 45))
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
                // A missed yesterday behind a long history exercises the
                // streak freeze: enough logged days to bank freezes, one gap.
                if LaunchArgs.all.contains("-seed-streak-gap") {
                    for value in 2...15 {
                        if let date = Calendar.current.date(byAdding: .day, value: -value, to: .now) {
                            context.insert(FoodEntry(day: date, meal: .lunch, name: "Älplermagronen",
                                                     calories: 620, proteinG: 22, carbsG: 68, fatG: 28))
                        }
                    }
                } else {
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
                }
                context.insert(FoodEntry(day: .now, meal: .breakfast, name: "Birchermüesli",
                                         calories: 320, proteinG: 12, carbsG: 45, fatG: 9))
                context.insert(FoodEntry(day: .now, meal: .breakfast, name: "Kaffee mit Milch",
                                         calories: 40, proteinG: 2, carbsG: 3, fatG: 2))
                context.insert(FoodEntry(day: .now, meal: .lunch, name: "Älplermagronen",
                                         calories: 620, proteinG: 22, carbsG: 68, fatG: 28))
                context.insert(WaterDay(day: .now, glasses: 3))
                // Two treadmill sessions with proof photos expected in
                // Documents (battle-proof-test-1/2.jpg), for sheet demos.
                if LaunchArgs.all.contains("-seed-manual-entries") {
                    context.insert(BattleManualEntry(day: .now, steps: 3900, distanceKm: 3,
                                                     photoFile: "battle-proof-test-1.jpg"))
                    context.insert(BattleManualEntry(day: .now, steps: 6500, distanceKm: 5,
                                                     photoFile: "battle-proof-test-2.jpg"))
                }
                #if ZWAEG_BATTLES
                let start = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
                let end = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
                // Real battles fill opponents in from CloudKit, which needs an
                // account the simulator doesn't have, so the seeded rivals carry
                // fixed totals. The "seed" day key is deliberate: it is not a
                // real date, so the score refresh leaves these numbers alone.
                // Challenge.demoCode also opts this battle out of CloudKit sync.
                context.insert(Challenge(
                    code: Challenge.demoCode, name: "Wochenbattle", metric: .steps,
                    startDay: start, endDay: end,
                    participants: [
                        ParticipantScore(id: PlayerIdentity.myID, name: "Livia", isMe: true,
                                         scores: ["seed": 24500]),
                        // -seed-manual-opponent: Luca logged a treadmill
                        // session, to preview the badge opponents see.
                        ParticipantScore(id: "demo-luca", name: "Luca", isMe: false,
                                         scores: ["seed": 21000],
                                         manualDays: LaunchArgs.all.contains("-seed-manual-opponent")
                                             ? [BattleDay.key(for: .now)] : []),
                        ParticipantScore(id: "demo-mia", name: "Mia", isMe: false,
                                         scores: ["seed": 18400]),
                    ]))
                #endif
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
                #if ZWAEG_BATTLES
                case 1: BattlesScreen(profile: profile)
                #endif
                case 2: ScannerScreen(profile: profile)
                case 3: CalculatorsView(profile: profile)
                case 4: ProfileView(profile: profile)
                case 5: RecipesScreen(profile: profile)
                case 6: NavigationStack { FastingView(profile: profile).tabBarClearance() }
                default: DiaryView(profile: profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The scanner is full-screen camera with its own back button,
            // so the floating bar stays away there.
            if !router.tabBarHidden && selection != 2 {
                ZwaegTabBar(router: router)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: router.tabBarHidden)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(.appAccent)
    }
}

extension View {
    /// Reserves space for the floating tab bar. Apply inside each tab's
    /// NavigationStack root: SwiftUI's safeAreaInset cannot cross the UIKit
    /// container boundary, so scroll content would end up behind the bar.
    func tabBarClearance() -> some View {
        background(TabBarSafeArea(inset: TabRouter.shared.tabBarHidden ? 0 : ZwaegTabBar.clearance))
    }
}

/// Sets the floating tab bar's height as additionalSafeAreaInsets on the
/// enclosing UINavigationController, so every pushed view and scroll view
/// inherits the clearance the same way they would from a system tab bar.
private struct TabBarSafeArea: UIViewRepresentable {
    var inset: CGFloat

    func makeUIView(context: Context) -> InsetApplier { InsetApplier() }

    func updateUIView(_ view: InsetApplier, context: Context) {
        view.inset = inset
    }

    final class InsetApplier: UIView {
        var inset: CGFloat = 0 { didSet { apply() } }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let current = responder {
                if let nav = (current as? UIViewController)?.navigationController
                            ?? current as? UINavigationController {
                    if nav.additionalSafeAreaInsets.bottom != inset {
                        nav.additionalSafeAreaInsets.bottom = inset
                    }
                    return
                }
                responder = current.next
            }
        }
    }
}

/// Floating pill tab bar, icon only: active tab in a coral circle, dark scan button.
struct ZwaegTabBar: View {
    /// Height the bar occupies above the bottom safe area: capsule (56pt row
    /// + 2x9 padding) + 4pt bottom padding. The raised scan button may overlap
    /// content slightly by design.
    static let clearance: CGFloat = 78

    @Bindable var router: TabRouter

    var body: some View {
        HStack(spacing: 0) {
            tabButton(0, symbol: "house.fill")
            tabButton(5, symbol: "book.fill")
            tabButton(6, symbol: "timer")
            scanButton
            #if ZWAEG_BATTLES
            tabButton(1, symbol: "flame.fill")
            #endif
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
