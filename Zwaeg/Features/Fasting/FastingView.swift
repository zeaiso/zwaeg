import SwiftData
import SwiftUI

/// Intermittent fasting tracker: live ring timer with the buddy inside and
/// stage markers, plan catalog, editable start, week stats and history.
struct FastingView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FastingSession.start, order: .reverse) private var sessions: [FastingSession]
    @AppStorage("fastingPlan") private var planRaw = FastingPlan.sixteenEight.rawValue
    @State private var confettiTrigger = 0
    @State private var showCatalog = false
    @State private var showStages = false
    @State private var showEditStart = false
    @State private var editedStart = Date.now

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
                planCard
                timerCard
                weekCard
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
                .allowsHitTesting(false)
        }
        .navigationDestination(isPresented: $showCatalog) {
            PlanCatalogView()
        }
        .sheet(isPresented: $showStages) {
            FastingStagesSheet(elapsedHours: activeSession.map {
                Date.now.timeIntervalSince($0.start) / 3600
            })
        }
        .sheet(isPresented: $showEditStart) {
            editStartSheet
        }
        .onAppear {
            #if DEBUG
            if CommandLine.arguments.contains("-seed-fast"), activeSession == nil {
                context.insert(FastingSession(start: .now.addingTimeInterval(-13 * 3600),
                                              plan: .sixteenEight))
            }
            #endif
            if CommandLine.arguments.contains("-open-fasting-plans") {
                showCatalog = true
            }
        }
    }

    // MARK: - Plan

    private var planCard: some View {
        Button {
            showCatalog = true
        } label: {
            Card {
                HStack(spacing: 14) {
                    EmojiOrSymbol(emoji: plan.emoji, symbol: plan.symbol, size: 28)
                        .frame(width: 48, height: 48)
                        .background(Theme.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.label)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(plan.level.label) · \(plan.detail)")
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Ändern".loc)
                        .font(.fredoka(14, .semibold))
                        .foregroundStyle(Color.appAccent)
                    Image(systemName: "chevron.forward")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer

    private var timerCard: some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ring(now: timeline.date)
            }
            if let session = activeSession {
                stageRow(session: session)
                HStack {
                    Button {
                        editedStart = session.start
                        showEditStart = true
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Beginn".loc)
                                    .font(.fredoka(12))
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            Text(session.start.formatted(date: .omitted, time: .shortened))
                                .font(.fredoka(16, .semibold))
                                .foregroundStyle(Theme.ink)
                                .underline(color: .secondary.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)
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
        let ringPlan = session?.plan ?? plan
        let total = TimeInterval(ringPlan.fastingHours) * 3600
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
            stageMarkers(plan: ringPlan, elapsedHours: elapsed / 3600, active: session != nil)
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

    /// Small dots on the ring where each fasting stage begins.
    private func stageMarkers(plan: FastingPlan, elapsedHours: Double, active: Bool) -> some View {
        ForEach(FastingStage.allCases.filter { $0.startHour > 0 && $0.startHour < plan.fastingHours }) { stage in
            let fraction = Double(stage.startHour) / Double(plan.fastingHours)
            let reached = active && elapsedHours >= Double(stage.startHour)
            Circle()
                .fill(reached ? Color.appAccent : Theme.background)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(reached ? Theme.background : Theme.track, lineWidth: 2))
                .offset(y: -110)
                .rotationEffect(.degrees(fraction * 360))
        }
    }

    private func stageRow(session: FastingSession) -> some View {
        let elapsedHours = Date.now.timeIntervalSince(session.start) / 3600
        let stage = FastingStage.current(elapsedHours: elapsedHours)
        return Button {
            showStages = true
        } label: {
            HStack(spacing: 12) {
                EmojiOrSymbol(emoji: stage.emoji, symbol: stage.symbol, size: 22)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Aktuelle Phase".loc)
                        .font(.fredoka(11))
                        .foregroundStyle(.secondary)
                    Text(stage.name)
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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

    private var editStartSheet: some View {
        VStack(spacing: 16) {
            Text("Start bearbeiten".loc)
                .font(.fredoka(17, .semibold))
            DatePicker("Beginn".loc, selection: $editedStart,
                       in: Date.now.addingTimeInterval(-48 * 3600)...Date.now)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Lingo.shared.language.locale)
            Button {
                if let session = activeSession {
                    session.start = editedStart
                    NotificationService.cancelFastingEnd()
                    if session.goalEnd > .now {
                        NotificationService.scheduleFastingEnd(at: session.goalEnd)
                    }
                }
                showEditStart = false
            } label: {
                Text("Speichern".loc)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accent.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .presentationDetents([.height(340)])
        .presentationBackground(Theme.background)
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

    // MARK: - Week stats

    /// Hours fasted per day for the last 7 days, keyed by start day.
    private var weekHours: [(day: Date, hours: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let hours = sessions
                .filter { calendar.startOfDay(for: $0.start) == day }
                .reduce(0.0) { $0 + ($1.endedAt ?? .now).timeIntervalSince($1.start) / 3600 }
            return (day, hours)
        }
    }

    private var weekCard: some View {
        let data = weekHours
        let goal = Double(plan.fastingHours)
        let maxValue = max(goal, data.map(\.hours).max() ?? 0)
        let total = data.reduce(0) { $0 + $1.hours }
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Letzte 7 Tage".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(data, id: \.day) { entry in
                        VStack(spacing: 5) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.track.opacity(0.5))
                                    .frame(height: 84)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(entry.hours >= goal ? AnyShapeStyle(Theme.accent.gradient)
                                                              : AnyShapeStyle(Theme.accent.opacity(0.45)))
                                    .frame(height: max(entry.hours > 0 ? 6 : 0,
                                                       84 * entry.hours / maxValue))
                            }
                            Text(entry.day.formatted(.dateTime.weekday(.narrow)
                                .locale(Lingo.shared.language.locale)))
                                .font(.fredoka(11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 10) {
                    statChip("Total".loc, value: total)
                    statChip("Ø pro Tag".loc, value: total / 7)
                }
            }
        }
    }

    private func statChip(_ label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
            Text("%@ Std.".loc(value.formatted(.number.precision(.fractionLength(0...1))
                .locale(Lingo.shared.language.locale))))
                .font(.fredoka(14, .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.field.opacity(0.6), in: Capsule())
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

/// All fasting stages with hour ranges; highlights the current one while fasting.
struct FastingStagesSheet: View {
    var elapsedHours: Double?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Fastenphasen".loc)
                        .font(.fredoka(20, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)
                ForEach(FastingStage.allCases) { stage in
                    let isCurrent = elapsedHours.map { FastingStage.current(elapsedHours: $0) == stage } ?? false
                    HStack(alignment: .top, spacing: 12) {
                        EmojiOrSymbol(emoji: stage.emoji, symbol: stage.symbol, size: 22)
                            .frame(width: 42, height: 42)
                            .background(isCurrent ? Theme.accentSoft : Theme.field.opacity(0.6),
                                        in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(stage.name)
                                    .font(.fredoka(15, .semibold))
                                    .foregroundStyle(isCurrent ? Color.appAccent : Theme.ink)
                                Text(stage.rangeLabel)
                                    .font(.fredoka(11, .medium))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.field.opacity(0.7), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                            Text(stage.info)
                                .font(.fredoka(13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(isCurrent ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .presentationDetents([.medium, .large])
    }
}
