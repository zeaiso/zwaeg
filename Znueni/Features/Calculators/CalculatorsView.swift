import SwiftUI

struct CalculatorsView: View {
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    calculatorLink(
                        title: "BMI-Rechner",
                        subtitle: "Body-Mass-Index & Einordnung",
                        symbol: "figure.arms.open",
                        color: .blue
                    ) { BMICalculatorView(profile: profile) }

                    calculatorLink(
                        title: "Idealgewicht",
                        subtitle: "Dein Zielbereich nach 4 Formeln",
                        symbol: "scalemass.fill",
                        color: .purple
                    ) { IdealWeightView(profile: profile) }

                    calculatorLink(
                        title: "Kalorienbedarf",
                        subtitle: "Grund- & Gesamtumsatz pro Tag",
                        symbol: "flame.fill",
                        color: .orange
                    ) { CalorieNeedsView(profile: profile) }

                    calculatorLink(
                        title: "Kalorienverbrauch",
                        subtitle: "Verbrauch pro Aktivität",
                        symbol: "figure.run",
                        color: .appAccent
                    ) { CalorieBurnView(profile: profile) }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Rechner")
        }
    }

    private func calculatorLink<Destination: View>(
        title: String, subtitle: String, symbol: String, color: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(color.gradient, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
