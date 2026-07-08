import SwiftUI

/// Draws a buddy: egg-shaped body, belly, face and accessory.
/// Pure vector, crisp at any size.
struct BuddyView: View {
    let buddy: Buddy
    var size: CGFloat = 46

    private var ink: Color { Color(red: 0.24, green: 0.12, blue: 0.08) }

    var body: some View {
        ZStack {
            bodyShape
            belly
            eyesView
                .offset(y: -size * 0.12)
            mouthView
                .offset(y: size * 0.08)
            accessoryView
        }
        .frame(width: size, height: size)
    }

    // MARK: - Body

    private var bodyShape: some View {
        UnevenRoundedRectangle(topLeadingRadius: size * 0.46,
                               bottomLeadingRadius: size * 0.34,
                               bottomTrailingRadius: size * 0.34,
                               topTrailingRadius: size * 0.46,
                               style: .continuous)
            .fill(LinearGradient(colors: [buddy.bodyColor, buddy.bodyColor.opacity(0.85)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size * 0.92, height: size * 0.96)
            .offset(y: size * 0.02)
    }

    private var belly: some View {
        Ellipse()
            .fill(buddy.bellyColor)
            .frame(width: size * 0.5, height: size * 0.4)
            .offset(y: size * 0.26)
    }

    // MARK: - Eyes

    @ViewBuilder
    private var eyesView: some View {
        switch buddy.eyes {
        case 1:
            // Happy closed arcs
            HStack(spacing: size * 0.14) {
                happyEye
                happyEye
            }
        case 2:
            // Sleepy half-lidded
            HStack(spacing: size * 0.12) {
                sleepyEye
                sleepyEye
            }
        default:
            // Round white eyes with pupils
            HStack(spacing: size * 0.12) {
                roundEye
                roundEye
            }
        }
    }

    private var roundEye: some View {
        ZStack {
            Circle().fill(.white)
                .frame(width: size * 0.22, height: size * 0.22)
            Circle().fill(ink)
                .frame(width: size * 0.11, height: size * 0.11)
        }
    }

    private var happyEye: some View {
        Arc(startAngle: .degrees(200), endAngle: .degrees(340))
            .stroke(ink, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
            .frame(width: size * 0.18, height: size * 0.18)
    }

    private var sleepyEye: some View {
        ZStack(alignment: .top) {
            Circle().fill(.white)
                .frame(width: size * 0.2, height: size * 0.2)
            Circle().fill(ink)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: size * 0.07)
            Rectangle().fill(buddy.bodyColor)
                .frame(width: size * 0.22, height: size * 0.09)
        }
        .frame(width: size * 0.2, height: size * 0.2)
        .clipShape(Circle())
    }

    // MARK: - Mouth

    @ViewBuilder
    private var mouthView: some View {
        switch buddy.mouth {
        case 1:
            // Open happy oval
            Ellipse()
                .fill(ink)
                .frame(width: size * 0.2, height: size * 0.16)
        case 2:
            // Cheeky small smile
            Arc(startAngle: .degrees(20), endAngle: .degrees(160))
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.14)
        default:
            // Wide smile, like the hero mascot
            UnevenRoundedRectangle(topLeadingRadius: size * 0.04,
                                   bottomLeadingRadius: size * 0.14,
                                   bottomTrailingRadius: size * 0.14,
                                   topTrailingRadius: size * 0.04)
                .fill(ink)
                .frame(width: size * 0.3, height: size * 0.13)
        }
    }

    // MARK: - Accessory

    @ViewBuilder
    private var accessoryView: some View {
        switch buddy.accessory {
        case 1:
            // Sweatband
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.62, height: size * 0.09)
                .offset(y: -size * 0.3)
        case 2:
            // Beanie with pompom
            ZStack {
                Ellipse()
                    .fill(ink.opacity(0.85))
                    .frame(width: size * 0.6, height: size * 0.26)
                    .offset(y: -size * 0.38)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.12, height: size * 0.12)
                    .offset(y: -size * 0.5)
            }
        case 3:
            // Sunglasses
            HStack(spacing: size * 0.05) {
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(ink)
                    .frame(width: size * 0.2, height: size * 0.14)
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(ink)
                    .frame(width: size * 0.2, height: size * 0.14)
            }
            .offset(y: -size * 0.12)
        default:
            EmptyView()
        }
    }
}

/// Simple arc segment used for happy eyes and the cheeky smile.
struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: min(rect.width, rect.height) / 2,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}
