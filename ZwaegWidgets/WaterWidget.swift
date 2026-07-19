import AppIntents
import SwiftUI
import WidgetKit

/// Interactive water widget: today's glasses as a drop grid plus a button
/// that logs a glass right on the home screen (AddWaterGlassIntent parks it
/// in the app group; the app merges on next activation).
struct WaterEntry: TimelineEntry {
    let date: Date
    let glasses: Int
    let goal: Int
    let midnight: Bool
}

struct WaterProvider: TimelineProvider {
    private var current: WaterEntry {
        let state = DaySnapshotStore.load()
        return WaterEntry(date: .now,
                          glasses: state?.glasses ?? 3,
                          goal: state?.waterGoal ?? 8,
                          midnight: state?.midnight ?? false)
    }

    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: .now, glasses: 3, goal: 8, midnight: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(current)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        // The app and the intent reload the timeline on every change.
        completion(Timeline(entries: [current], policy: .never))
    }
}

struct ZwaegWaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZwaegWaterWidget", provider: WaterProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Palette.background(entry.midnight)
                }
        }
        .configurationDisplayName("Wasser")
        .description("Tippe, um ein Glas zu loggen.")
        .supportedFamilies([.systemSmall])
    }
}

private struct WaterWidgetView: View {
    let entry: WaterEntry

    /// Drop grid capped at 12 slots so unusual goals still fit the small tile.
    private var slots: Int { min(entry.goal, 12) }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.blue)
                Spacer()
                Text("\(entry.glasses)/\(entry.goal)")
                    .font(.custom("Fredoka-SemiBold", size: 17))
                    .foregroundStyle(Palette.ink(entry.midnight))
                    .contentTransition(.numericText())
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(0..<slots, id: \.self) { index in
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(index < entry.glasses ? Palette.blue
                                                               : Palette.track(entry.midnight))
                }
            }

            Button(intent: AddWaterGlassIntent()) {
                HStack(spacing: 5) {
                    Image(systemName: entry.glasses >= entry.goal ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Glas")
                        .font(.custom("Fredoka-SemiBold", size: 14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(entry.glasses >= entry.goal ? Palette.blue : Palette.accent,
                            in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
