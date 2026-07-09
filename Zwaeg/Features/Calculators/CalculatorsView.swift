import SwiftUI

struct CalculatorsView: View {
    let profile: UserProfile

    @State private var route: CalcRoute?

    enum CalcRoute: String, Identifiable {
        case bmi, ideal, needs, burn
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    calculatorCard(.bmi, title: "BMI-Rechner".loc,
                                   subtitle: "Body-Mass-Index & Einordnung".loc,
                                   symbol: "figure.arms.open",
                                   colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent])
                    calculatorCard(.ideal, title: "Idealgewicht".loc,
                                   subtitle: "Dein Zielbereich nach 4 Formeln".loc,
                                   symbol: "scalemass.fill",
                                   colors: [Color(red: 0.52, green: 0.48, blue: 0.95), Color(red: 0.68, green: 0.6, blue: 0.98)])
                    calculatorCard(.needs, title: "Kalorienbedarf".loc,
                                   subtitle: "Grund- & Gesamtumsatz pro Tag".loc,
                                   symbol: "flame.fill",
                                   colors: [Color(red: 1.0, green: 0.72, blue: 0.25), Color(red: 1.0, green: 0.82, blue: 0.45)])
                    calculatorCard(.burn, title: "Kalorienverbrauch".loc,
                                   subtitle: "Verbrauch pro Aktivität".loc,
                                   symbol: "figure.run",
                                   colors: [Color(red: 0.35, green: 0.75, blue: 0.5), Color(red: 0.55, green: 0.85, blue: 0.6)])
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { route in
                switch route {
                case .bmi: BMICalculatorView(profile: profile)
                case .ideal: IdealWeightView(profile: profile)
                case .needs: CalorieNeedsView(profile: profile)
                case .burn: CalorieBurnView(profile: profile)
                }
            }
            .onAppear {
                if let flagIndex = CommandLine.arguments.firstIndex(of: "-open-calc"),
                   CommandLine.arguments.indices.contains(flagIndex + 1),
                   let target = CalcRoute(rawValue: CommandLine.arguments[flagIndex + 1]) {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        route = target
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rechner".loc)
                    .font(.fredoka(27, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Deine Gesundheits-Tools".loc)
                    .font(.fredoka(15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func calculatorCard(_ target: CalcRoute, title: String, subtitle: String,
                                symbol: String, colors: [Color]) -> some View {
        Button {
            route = target
        } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.fredoka(19, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
