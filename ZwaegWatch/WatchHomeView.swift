import SwiftUI

/// The whole watch app: the day ring, remaining kcal and one-tap water.
struct WatchHomeView: View {
    @State private var link = WatchLink.shared

    private let accent = Color(red: 1.0, green: 0.38, blue: 0.25)
    private let blue = Color(red: 0.24, green: 0.64, blue: 1.0)

    var body: some View {
        if let snapshot = link.snapshot {
            ScrollView {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: snapshot.progress)
                            .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(snapshot.remaining.formatted())
                                .font(.system(.title2, design: .rounded).bold())
                            Text(snapshot.remainingLabel)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 108, height: 108)
                    .padding(.top, 4)

                    if let end = snapshot.fastingEnd, end > .now {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundStyle(accent)
                            Text(timerInterval: Date.now...end, countsDown: true)
                                .monospacedDigit()
                        }
                        .font(.system(.caption, design: .rounded).bold())
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(blue)
                        Text("\(snapshot.glasses)/\(snapshot.waterGoal)")
                            .font(.system(.body, design: .rounded).bold())
                            .contentTransition(.numericText())
                        Spacer()
                        Button {
                            link.addWater()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(.body, design: .rounded).bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(blue)
                        .frame(width: 52)
                    }
                    .padding(.horizontal, 6)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(accent)
                Text("Zwäg")
                    .font(.system(.headline, design: .rounded))
            }
        }
    }
}
