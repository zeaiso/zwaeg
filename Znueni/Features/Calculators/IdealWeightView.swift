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
                Card {
                    VStack(spacing: 20) {
                        Picker("Geschlecht", selection: $sex) {
                            ForEach(Sex.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        ValueField(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                    }
                }

                Card {
                    VStack(spacing: 12) {
                        Text("Dein Idealgewicht")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        ResultNumber(
                            value: "\(String(format: "%.0f", range.lowerBound))-\(String(format: "%.0f", range.upperBound))",
                            unit: "kg")
                        Text("Bereich über vier anerkannte Formeln")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Card {
                    VStack(spacing: 12) {
                        ForEach(CalorieMath.idealWeights(sex: sex, heightCm: heightCm)) { result in
                            HStack {
                                Text(result.formula)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(String(format: "%.1f", result.weightKg)) kg")
                                    .fontWeight(.semibold)
                                    .contentTransition(.numericText())
                            }
                            if result.id != CalorieMath.idealWeights(sex: sex, heightCm: heightCm).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Idealgewicht")
        .navigationBarTitleDisplayMode(.inline)
    }
}
