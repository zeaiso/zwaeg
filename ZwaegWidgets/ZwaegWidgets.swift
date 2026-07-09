import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ZwaegWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ZwaegRingWidget()
        ZwaegDayLiveActivity()
    }
}

/// Munch palette for the extension; mirrors Theme.swift without the app target.
private enum Palette {
    static let accent = Color(red: 1.0, green: 0.325, blue: 0.188)
    static let blue = Color(red: 0.24, green: 0.64, blue: 1.0)
    static let orange = Color(red: 0.98, green: 0.55, blue: 0.2)

    static func background(_ midnight: Bool) -> Color {
        midnight ? Color(red: 0.155, green: 0.135, blue: 0.12)
                 : Color(red: 0.996, green: 0.984, blue: 0.976)
    }

    static func ink(_ midnight: Bool) -> Color {
        midnight ? Color(red: 0.96, green: 0.94, blue: 0.925)
                 : Color(red: 0.129, green: 0.11, blue: 0.102)
    }

    static func track(_ midnight: Bool) -> Color {
        midnight ? .white.opacity(0.16)
                 : Color(red: 0.918, green: 0.878, blue: 0.851)
    }
}

// MARK: - Home screen widget

struct DaySnapshotEntry: TimelineEntry {
    let date: Date
    let state: DayActivityAttributes.ContentState
}

struct DaySnapshotProvider: TimelineProvider {
    private var sample: DayActivityAttributes.ContentState {
        DayActivityAttributes.ContentState(
            consumed: 980, target: 2200, burned: 240, glasses: 4, waterGoal: 8,
            fastingEnd: nil, remainingLabel: "kcal", fastingLabel: "Fasten", midnight: false)
    }

    private var current: DayActivityAttributes.ContentState {
        DaySnapshotStore.load() ?? sample
    }

    func placeholder(in context: Context) -> DaySnapshotEntry {
        DaySnapshotEntry(date: .now, state: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaySnapshotEntry) -> Void) {
        completion(DaySnapshotEntry(date: .now, state: current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaySnapshotEntry>) -> Void) {
        // The app reloads the timeline on every change; no self-refresh needed.
        completion(Timeline(entries: [DaySnapshotEntry(date: .now, state: current)], policy: .never))
    }
}

struct ZwaegRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZwaegRingWidget", provider: DaySnapshotProvider()) { entry in
            RingWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    Palette.background(entry.state.midnight)
                }
        }
        .configurationDisplayName("Zwäg")
        .description("Dein Tag auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct RingWidgetView: View {
    let state: DayActivityAttributes.ContentState

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 18) {
                ring(size: 96, lineWidth: 10)
                VStack(alignment: .leading, spacing: 8) {
                    statRow(icon: "fork.knife", color: Palette.accent, value: "\(state.consumed) kcal")
                    statRow(icon: "flame.fill", color: Palette.orange, value: "\(state.burned) kcal")
                    statRow(icon: "drop.fill", color: Palette.blue, value: "\(state.glasses)/\(state.waterGoal)")
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(spacing: 6) {
                ring(size: 78, lineWidth: 9)
                Text(state.remaining.formatted())
                    .font(.custom("Fredoka-SemiBold", size: 21))
                    .foregroundStyle(Palette.ink(state.midnight))
                Text(state.remainingLabel)
                    .font(.custom("Fredoka-Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Palette.track(state.midnight), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if family == .systemMedium {
                VStack(spacing: 0) {
                    Text(state.remaining.formatted())
                        .font(.custom("Fredoka-SemiBold", size: 22))
                        .foregroundStyle(Palette.ink(state.midnight))
                    Text(state.remainingLabel)
                        .font(.custom("Fredoka-Regular", size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .frame(width: size, height: size)
    }

    private func statRow(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(value)
                .font(.custom("Fredoka-SemiBold", size: 15))
                .foregroundStyle(Palette.ink(state.midnight))
        }
    }
}

struct ZwaegDayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Palette.background(context.state.midnight))
                .activitySystemActionForegroundColor(Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 2) {
                        Image(systemName: "fork.knife")
                            .font(.caption)
                            .foregroundStyle(Palette.accent)
                        Text("\(context.state.consumed)")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.orange)
                        Text("\(context.state.burned)")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.state.remaining.formatted())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                        Text(context.state.remainingLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.glasses)/\(context.state.waterGoal)",
                              systemImage: "drop.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Palette.blue)
                        Spacer()
                        if let end = context.state.fastingEnd, end > .now {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundStyle(Palette.accent)
                                Text(timerInterval: Date.now...end, countsDown: true)
                                    .font(.system(.caption, design: .rounded).bold().monospacedDigit())
                                    .frame(width: 58)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Palette.accent)
            } compactTrailing: {
                if let end = context.state.fastingEnd, end > .now {
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .font(.system(.caption2, design: .rounded).bold().monospacedDigit())
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.accent)
                } else {
                    Text(context.state.remaining.formatted())
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundStyle(Palette.accent)
                }
            } minimal: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

/// Lock screen banner: ring, remaining kcal, burned and water, fasting timer.
private struct LockScreenView: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Palette.track(state.midnight), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(state.remaining.formatted())
                        .font(.custom("Fredoka-SemiBold", size: 27))
                        .foregroundStyle(Palette.ink(state.midnight))
                    Text(state.remainingLabel)
                        .font(.custom("Fredoka-Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label("\(state.burned)", systemImage: "flame.fill")
                        .font(.custom("Fredoka-SemiBold", size: 12))
                        .foregroundStyle(Palette.orange)
                    Label("\(state.glasses)/\(state.waterGoal)", systemImage: "drop.fill")
                        .font(.custom("Fredoka-SemiBold", size: 12))
                        .foregroundStyle(Palette.blue)
                }
            }

            Spacer()

            if let end = state.fastingEnd, end > .now {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.fastingLabel)
                        .font(.custom("Fredoka-Regular", size: 11))
                        .foregroundStyle(.secondary)
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .font(.custom("Fredoka-SemiBold", size: 19).monospacedDigit())
                        .frame(width: 82)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .padding(16)
    }
}
