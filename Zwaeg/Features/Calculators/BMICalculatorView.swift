import SwiftUI

struct BMICalculatorView: View {
    @State private var weightKg: Double
    @State private var heightCm: Double

    init(profile: UserProfile) {
        _weightKg = State(initialValue: profile.weightKg)
        _heightCm = State(initialValue: profile.heightCm)
    }

    private var bmi: Double { CalorieMath.bmi(weightKg: weightKg, heightCm: heightCm) }
    private var category: CalorieMath.BMICategory { CalorieMath.bmiCategory(bmi) }
    private var healthyRange: ClosedRange<Double> { CalorieMath.healthyWeightRange(heightCm: heightCm) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(title: "BMI-Rechner".loc, subtitle: "Body-Mass-Index & Einordnung".loc)
                inputCard
                resultCard
                scaleCard
                supportCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var inputCard: some View {
        Card {
            VStack(spacing: 14) {
                ValueField(title: "Gewicht".loc, value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                Divider()
                ValueField(title: "Größe".loc, value: $heightCm, range: 130...220, step: 1, unit: "cm")
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 8) {
            Text(String(format: "%.1f", bmi))
                .font(.fredoka(52, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(category.label)
                .font(.fredoka(15, .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.white.opacity(0.25), in: Capsule())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 5)
    }

    private var scaleCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Einordnung".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                BMIScaleView(bmi: bmi)
                Text("Normalgewicht für deine Größe: %@ bis %@ kg".loc(String(format: "%.0f", healthyRange.lowerBound), String(format: "%.0f", healthyRange.upperBound)))
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Support & resources

    @ViewBuilder
    private var supportCard: some View {
        switch category {
        case .normal:
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.13, green: 0.66, blue: 0.42))
                    Text("Alles im grünen Bereich. Weiter so!".loc)
                        .font(.fredoka(15, .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
        case .underweight:
            supportLinks(
                intro: "Untergewicht kann viele Ursachen haben. Sprich mit deiner Hausärztin oder deinem Hausarzt, wenn es dich beschäftigt.".loc,
                links: [
                    ("Arbeitsgemeinschaft Ess-Störungen AES", "https://www.aes.ch"),
                    ("BAG · Ernährung & Bewegung", "https://www.bag.admin.ch"),
                ])
        case .overweight, .obese1, .obese2, .obese3:
            supportLinks(
                intro: "Du bist nicht allein. Kleine Schritte zählen, und professionelle Unterstützung hilft. Deine Hausärztin oder dein Hausarzt ist eine gute erste Anlaufstelle.".loc,
                links: [
                    ("Schweizer Adipositas-Stiftung SAPS", "https://www.saps.ch"),
                    ("Ernährungsberatung SVDE", "https://www.svde-asdd.ch"),
                    ("BAG · Ernährung & Bewegung", "https://www.bag.admin.ch"),
                ])
        }
    }

    private func supportLinks(intro: String, links: [(String, String)]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Unterstützung & Infos".loc, systemImage: "heart.fill")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(intro)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                ForEach(links, id: \.1) { name, urlString in
                    if let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .font(.fredoka(12, .semibold))
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                                Text(name)
                                    .font(.fredoka(15, .medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.fredoka(12, .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Horizontal BMI scale (15-40) with a marker at the current value.
struct BMIScaleView: View {
    let bmi: Double

    private let minBMI = 15.0
    private let maxBMI = 40.0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let fraction = min(1, max(0, (bmi - minBMI) / (maxBMI - minBMI)))
                ZStack(alignment: .leading) {
                    LinearGradient(
                        stops: [
                            .init(color: .blue, location: 0.0),
                            .init(color: .green, location: (18.5 - 15) / 25),
                            .init(color: .green, location: (24.9 - 15) / 25),
                            .init(color: .yellow, location: (27.5 - 15) / 25),
                            .init(color: .orange, location: (32 - 15) / 25),
                            .init(color: .red, location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing)
                    .clipShape(Capsule())
                    Circle()
                        .fill(.white)
                        .stroke(Color(.systemGray3), lineWidth: 1)
                        .frame(width: 18, height: 18)
                        .offset(x: fraction * (geo.size.width - 18))
                        .animation(.spring(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 18)
            HStack {
                Text("15").frame(maxWidth: .infinity, alignment: .leading)
                Text("18.5")
                Text("25")
                Text("30")
                Text("40").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.fredoka(11))
            .foregroundStyle(.tertiary)
        }
    }
}
