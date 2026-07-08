import SwiftUI

struct IdealWeightView: View {
    @State private var sex: Sex
    @State private var heightCm: Double

    init(profile: UserProfile) {
        _sex = State(initialValue: profile.sex)
        _heightCm = State(initialValue: profile.heightCm)
    }

    private var range: ClosedRange<Double> {
        CalorieMath.idealWeightRange(sex: sex, heightCm: heightCm)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(title: "Idealgewicht", subtitle: "Zielbereich nach 4 Formeln")
                inputCard
                resultCard
                formulasCard
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
                Picker("Geschlecht", selection: $sex) {
                    ForEach(Sex.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                ValueField(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text("\(String(format: "%.0f", range.lowerBound)) bis \(String(format: "%.0f", range.upperBound)) kg")
                .font(.fredoka(38, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text("Dein Idealgewicht-Bereich")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(colors: [Color(red: 0.52, green: 0.48, blue: 0.95), Color(red: 0.68, green: 0.6, blue: 0.98)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(red: 0.52, green: 0.48, blue: 0.95).opacity(0.35), radius: 12, y: 5)
    }

    private var formulasCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nach Formel")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                ForEach(CalorieMath.idealWeights(sex: sex, heightCm: heightCm)) { result in
                    HStack {
                        Text(result.formula)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", result.weightKg)) kg")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }
}
