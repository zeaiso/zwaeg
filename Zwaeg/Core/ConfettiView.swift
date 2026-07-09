import SwiftUI

/// One-shot confetti burst overlay; bump `trigger` to fire a new burst.
/// Pieces use the Munch meal palette and fall with a touch of gravity.
struct ConfettiBurst: View {
    let trigger: Int

    @State private var bursts: [Int] = []

    var body: some View {
        ZStack {
            ForEach(bursts, id: \.self) { id in
                ConfettiExplosion(seed: id)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            bursts.append(newValue)
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { bursts.removeAll { $0 == newValue } }
            }
        }
    }
}

private struct ConfettiExplosion: View {
    let seed: Int

    @State private var flight: CGFloat = 0

    private static let colors: [Color] = [
        Color(red: 1.0, green: 0.325, blue: 0.188),
        Color(red: 1.0, green: 0.72, blue: 0.25),
        Color(red: 0.55, green: 0.83, blue: 0.5),
        Color(red: 0.52, green: 0.48, blue: 0.95),
        Color(red: 0.24, green: 0.64, blue: 1.0),
        Color(red: 1.0, green: 0.55, blue: 0.62),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<42, id: \.self) { index in
                    piece(index, size: geo.size)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                flight = 1
            }
        }
    }

    /// Deterministic pseudo-random 0..1 per piece so every burst looks lively
    /// without any shared state.
    private func random(_ index: Int, _ salt: Int) -> CGFloat {
        let value = sin(Double(index * 127 + salt * 311 + seed * 733)) * 43758.5453
        return CGFloat(abs(value - value.rounded(.towardZero)))
    }

    private func piece(_ index: Int, size: CGSize) -> some View {
        let angle = random(index, 1) * 2 * .pi
        let distance = 70 + random(index, 2) * 190
        let x = size.width / 2 + cos(angle) * distance * flight
        let y = size.height * 0.32 + sin(angle) * distance * flight + 150 * flight * flight
        let spin = Angle(degrees: Double(random(index, 3) * 720 - 360) * flight)
        let tall = random(index, 4) > 0.5
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Self.colors[index % Self.colors.count])
            .frame(width: 8, height: tall ? 15 : 8)
            .rotationEffect(spin)
            .rotation3DEffect(.degrees(Double(random(index, 5) * 360) * flight),
                              axis: (x: 1, y: 1, z: 0))
            .position(x: x, y: y)
            .opacity(1.15 - flight)
    }
}
