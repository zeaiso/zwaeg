import SwiftData
import SwiftUI

/// Intermittent fasting tracker: live ring timer with the buddy inside,
/// plan picker and history.
struct FastingView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FastingSession.start, order: .reverse) private var sessions: [FastingSession]
    @AppStorage("fastingPlan") private var planRaw = FastingPlan.sixteenEight.rawValue
    @State private var confettiTrigger = 0

    private var plan: FastingPlan { FastingPlan(rawValue: planRaw) ?? .sixteenEight }

    private var activeSession: FastingSession? {
        sessions.first { $0.isActive }
    }

    private var history: [FastingSession] {
        Array(sessions.filter { !$0.isActive }.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(title: "Fasten".loc, subtitle: plan.detail, showsBack: false)
                planPicker
                timerCard
                if !history.isEmpty {
                    historyCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            ConfettiBurst(trigger: confettiTrigger)
        }
    }

    // MARK: - Plan picker

    private var planPicker: some View {
        let selected = activeSession?.plan ?? plan
        return HStack(spacing: 10) {
            ForEach(FastingPlan.allCases) { option in
                Button {
                    planRaw = option.rawValue
                } label: {
                    VStack(spacing: 2) {
                        Text(option.label)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(selected == option ? Theme.onAccent : Theme.ink)
                        Text("%d Std. essen".loc(24 - option.fastingHours))
                            .font(.fredoka(11))
                            .foregroundStyle(selected == option ? Theme.onAccent.opacity(0.85) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected == option ? AnyShapeStyle(Theme.accent.gradient)
                                                  : AnyShapeStyle(Theme.card),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(activeSession != nil)
            }
        }
    }

    // MARK: - Timer

    private var timerCard: some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ring(now: timeline.date)
            }
            if let session = activeSession {
                HStack {
                    timeLabel("Beginn".loc, date: session.start)
                    Spacer()
                    timeLabel("Ziel".loc, date: session.goalEnd)
                }
                .padding(.horizontal, 8)
            } else {
                Text(plan.detail)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
            actionButton
        }
        .padding(20)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func ring(now: Date) -> some View {
        let session = activeSession
        let total = TimeInterval((session?.plan ?? plan).fastingHours) * 3600
        let elapsed = session.map { now.timeIntervalSince($0.start) } ?? 0
        let progress = session == nil ? 0 : min(1, elapsed / total)
        let remaining = total - elapsed
        return ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Theme.accentLight, Theme.accent],
                                   startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
            VStack(spacing: 4) {
                BuddyPoseView(buddy: profile.buddy, size: 52,
                              pose: session != nil && remaining <= 0 ? .party : .neutral)
                    .padding(.bottom, 2)
                if session != nil {
                    if remaining > 0 {
                        Text(format(remaining))
                            .font(.fredoka(30, .semibold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text("bis zum Ziel".loc)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ziel erreicht!".loc)
                            .font(.fredoka(20, .semibold))
                            .foregroundStyle(Color.appAccent)
                        Text("+\(format(-remaining))")
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    Text(plan.label)
                        .font(.fredoka(30, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Bereit zum Fasten?".loc)
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 220, height: 220)
        .padding(.top, 6)
    }

    private func timeLabel(_ title: String, date: Date) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.fredoka(16, .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private var actionButton: some View {
        Button {
            if let session = activeSession {
                stop(session)
            } else {
                start()
            }
        } label: {
            Text(activeSession == nil ? "Fasten starten".loc : "Fasten beenden".loc)
                .font(.fredoka(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(activeSession == nil ? AnyShapeStyle(Theme.accent.gradient)
                                                 : AnyShapeStyle(Theme.ink),
                            in: Capsule())
                .foregroundStyle(activeSession == nil ? Theme.onAccent : Theme.onInk)
        }
        .buttonStyle(.plain)
    }

    private func start() {
        let session = FastingSession(plan: plan)
        withAnimation(.snappy) {
            context.insert(session)
        }
        Task {
            if await NotificationService.requestPermission() {
                NotificationService.scheduleFastingEnd(at: session.goalEnd)
            }
        }
    }

    private func stop(_ session: FastingSession) {
        if Date.now >= session.goalEnd {
            confettiTrigger += 1
        }
        withAnimation(.snappy) {
            session.endedAt = .now
        }
        NotificationService.cancelFastingEnd()
    }

    // MARK: - History

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Letzte Fasten".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                ForEach(history) { session in
                    historyRow(session)
                }
            }
        }
    }

    private func historyRow(_ session: FastingSession) -> some View {
        let ended = session.endedAt ?? session.start
        let reached = ended >= session.goalEnd
        let minutes = Int(ended.timeIntervalSince(session.start) / 60)
        return HStack(spacing: 12) {
            Image(systemName: reached ? "checkmark.seal.fill" : "moon.zzz.fill")
                .font(.fredoka(15, .semibold))
                .foregroundStyle(reached ? Color(red: 0.3, green: 0.65, blue: 0.35) : .secondary)
                .frame(width: 34, height: 34)
                .background(Theme.field.opacity(0.6), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(session.start.formatted(.dateTime.weekday(.wide).day().month()
                    .locale(Lingo.shared.language.locale)))
                    .font(.fredoka(14, .medium))
                    .foregroundStyle(Theme.ink)
                Text("%@ · %d Std. %d Min. gefastet".loc(session.plan.label, minutes / 60, minutes % 60))
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if reached {
                Text("Geschafft".loc)
                    .font(.fredoka(11, .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
