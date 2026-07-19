import SwiftUI

/// The buddy's reaction to a situation, expressed through motion and small
/// floating accents, since the buddy artwork itself is a static image.
enum BuddyPose {
    case neutral
    case sleeping
    case happy
    case over
    case party
}

struct BuddyPoseView: View {
    let buddy: Buddy
    let size: CGFloat
    let pose: BuddyPose

    @State private var animating = false

    var body: some View {
        ZStack {
            BuddyView(buddy: buddy, size: size)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .offset(y: bounce)
            accents
        }
        .onAppear {
            start()
        }
        .onChange(of: pose) {
            animating = false
            start()
        }
    }

    private func start() {
        guard pose != .neutral else { return }
        withAnimation(animation) {
            animating = true
        }
    }

    private var animation: Animation {
        switch pose {
        case .neutral: return .default
        case .sleeping: return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        case .happy: return .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        case .over: return .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
        case .party: return .spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true)
        }
    }

    private var rotation: Double {
        switch pose {
        case .sleeping: return -9
        case .over: return animating ? 3.5 : -3.5
        default: return 0
        }
    }

    private var scale: CGFloat {
        switch pose {
        case .sleeping: return animating ? 1.03 : 1.0
        case .party: return animating ? 1.09 : 0.98
        default: return 1
        }
    }

    private var bounce: CGFloat {
        switch pose {
        case .happy: return animating ? -size * 0.06 : 0
        default: return 0
        }
    }

    @ViewBuilder
    private var accents: some View {
        switch pose {
        case .sleeping:
            Image(systemName: "zzz")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(Color(.systemGray))
                .offset(x: size * 0.44, y: animating ? -size * 0.54 : -size * 0.38)
                .opacity(animating ? 0.35 : 0.95)
        case .happy:
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(x: size * 0.46, y: -size * 0.40)
                .opacity(animating ? 1 : 0.3)
        case .over:
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.20, weight: .bold))
                .foregroundStyle(Theme.blue)
                .offset(x: size * 0.44, y: animating ? -size * 0.30 : -size * 0.42)
        case .party:
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(x: -size * 0.46, y: -size * 0.40)
                .opacity(animating ? 1 : 0.4)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.20, weight: .bold))
                .foregroundStyle(Theme.accentLight)
                .offset(x: size * 0.48, y: -size * 0.28)
                .opacity(animating ? 0.5 : 1)
        case .neutral:
            EmptyView()
        }
    }
}
