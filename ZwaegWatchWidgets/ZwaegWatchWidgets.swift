import SwiftUI
import WidgetKit

@main
struct ZwaegWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ZwaegComplication()
    }
}

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchDaySnapshot
}

struct WatchComplicationProvider: TimelineProvider {
    private var sample: WatchDaySnapshot {
        WatchDaySnapshot(consumed: 980, target: 2200, burned: 240,
                         glasses: 4, waterGoal: 8, remainingLabel: "kcal", fastingEnd: nil)
    }

    private var current: WatchDaySnapshot {
        WatchSnapshotStore.load() ?? sample
    }

    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(WatchComplicationEntry(date: .now, snapshot: current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        // The watch app reloads timelines whenever a fresh snapshot arrives.
        completion(Timeline(entries: [WatchComplicationEntry(date: .now, snapshot: current)], policy: .never))
    }
}

struct ZwaegComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZwaegComplication", provider: WatchComplicationProvider()) { entry in
            ComplicationView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Zwäg")
        .description("Übrige Kalorien und Wasser.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

private struct ComplicationView: View {
    let snapshot: WatchDaySnapshot

    @Environment(\.widgetFamily) private var family

    private let accent = Color(red: 1.0, green: 0.38, blue: 0.25)

    /// "1.2k" style so big numbers fit tiny complication slots.
    private var shortRemaining: String {
        let value = snapshot.remaining
        return value >= 1000 ? String(format: "%.1fk", Double(value) / 1000) : "\(value)"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(snapshot.remaining.formatted()) kcal")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(snapshot.remaining.formatted())
                        .font(.headline.bold())
                        .widgetAccentable()
                    Text(snapshot.remainingLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Gauge(value: snapshot.progress) {}
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(accent)
                Label("\(snapshot.glasses)/\(snapshot.waterGoal)", systemImage: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .accessoryCorner:
            Text(shortRemaining)
                .font(.title3.bold())
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: snapshot.progress) {
                        Text("kcal")
                    }
                    .tint(accent)
                }
        default:
            Gauge(value: snapshot.progress) {
                Image(systemName: "fork.knife")
            } currentValueLabel: {
                Text(shortRemaining)
                    .widgetAccentable()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(accent)
        }
    }
}
