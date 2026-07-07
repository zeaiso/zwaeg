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
                Card {
                    VStack(spacing: 20) {
                        ValueSlider(title: "Gewicht", value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                        ValueSlider(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                    }
                }

                Card {
                    VStack(spacing: 16) {
                        Text("Dein BMI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        ResultNumber(value: String(format: "%.1f", bmi), unit: "", color: category.color)
                        Text(category.label)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(category.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(category.color)
                        BMIScaleView(bmi: bmi)
                            .padding(.top, 4)
                        Text("Normalgewicht für deine Grösse: \(String(format: "%.0f", healthyRange.lowerBound))-\(String(format: "%.0f", healthyRange.upperBound)) kg")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("BMI-Rechner")
        .navigationBarTitleDisplayMode(.inline)
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
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}
