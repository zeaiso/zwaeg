import SwiftUI

/// A full-body blob buddy whose belly follows the user's BMI: it starts
/// round and slims down as the weight comes off. Factor 0 is slim,
/// factor 1 is maximally round.
struct BodyBuddyView: View {
    var factor: Double
    var size: CGFloat = 170

    var body: some View {
        let clamped = min(max(factor, 0), 1)
        let bodyWidth = size * (0.46 + 0.38 * clamped)
        let bodyHeight = size * 0.54
        let headSize = size * 0.46
        let legWidth = size * 0.105
        let armWidth = size * 0.09
        let gradient = LinearGradient(colors: [Theme.accentLight, Theme.accent],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

        ZStack {
            // legs
            HStack(spacing: bodyWidth * 0.22) {
                Capsule().fill(gradient).frame(width: legWidth, height: size * 0.22)
                Capsule().fill(gradient).frame(width: legWidth, height: size * 0.22)
            }
            .offset(y: size * 0.44)

            // arms hug the belly, so they travel with its width
            Capsule()
                .fill(gradient)
                .frame(width: armWidth, height: size * 0.26)
                .rotationEffect(.degrees(24))
                .offset(x: -bodyWidth * 0.52, y: size * 0.10)
            Capsule()
                .fill(gradient)
                .frame(width: armWidth, height: size * 0.26)
                .rotationEffect(.degrees(-24))
                .offset(x: bodyWidth * 0.52, y: size * 0.10)

            // belly
            Ellipse()
                .fill(gradient)
                .frame(width: bodyWidth, height: bodyHeight)
                .offset(y: size * 0.14)
                .overlay(
                    Ellipse()
                        .fill(.white.opacity(0.22))
                        .frame(width: bodyWidth * 0.32, height: bodyHeight * 0.2)
                        .offset(x: -bodyWidth * 0.22, y: -size * 0.02)
                )

            // head with the blob face
            ZStack {
                Circle().fill(gradient)
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: headSize * 0.26, height: headSize * 0.18)
                    .offset(x: -headSize * 0.2, y: -headSize * 0.26)
                HStack(spacing: headSize * 0.26) {
                    Circle().fill(Theme.ink).frame(width: headSize * 0.1)
                    Circle().fill(Theme.ink).frame(width: headSize * 0.1)
                }
                .offset(y: -headSize * 0.03)
                SmileArc()
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: headSize * 0.055, lineCap: .round))
                    .frame(width: headSize * 0.3, height: headSize * 0.16)
                    .offset(y: headSize * 0.17)
                HStack(spacing: headSize * 0.62) {
                    Circle().fill(Color(red: 1.0, green: 0.7, blue: 0.62).opacity(0.85))
                        .frame(width: headSize * 0.11)
                    Circle().fill(Color(red: 1.0, green: 0.7, blue: 0.62).opacity(0.85))
                        .frame(width: headSize * 0.11)
                }
                .offset(y: headSize * 0.1)
            }
            .frame(width: headSize, height: headSize)
            .offset(y: -size * 0.30)
        }
        .frame(width: size, height: size * 1.15)
    }
}

/// Simple smile: the lower half of an ellipse-ish arc.
private struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY),
                    radius: rect.width / 2,
                    startAngle: .degrees(200), endAngle: .degrees(340), clockwise: true)
        return path
    }
}
