import SwiftUI

struct CalorieBurnView: View {
    @State private var activity: CalorieMath.METActivity = CalorieMath.activities[0]
    @State private var weightKg: Double
    @State private var minutes = 30.0

    init(profile: UserProfile) {
        _weightKg = State(initialValue: profile.weightKg)
    }

    private var burned: Double {
        CalorieMath.kcalBurned(met: activity.met, weightKg: weightKg, minutes: minutes)
    }

    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(title: "Kalorienverbrauch".loc, subtitle: "Verbrauch pro Aktivität".loc)
                resultCard
                inputCard
                activityCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text("\(Int(burned.rounded()))")
                .font(.fredoka(52, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text("kcal verbrannt".loc)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("%@ · %d Min · %@ kg".loc(activity.name.loc, Int(minutes), String(format: "%.1f", weightKg)))
                .font(.fredoka(12))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(colors: [Color(red: 0.35, green: 0.75, blue: 0.5), Color(red: 0.55, green: 0.85, blue: 0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(red: 0.35, green: 0.75, blue: 0.5).opacity(0.35), radius: 12, y: 5)
    }

    private var inputCard: some View {
        Card {
            VStack(spacing: 14) {
                ValueField(title: "Dauer".loc, value: $minutes, range: 5...240, step: 5, unit: "Min".loc)
                Divider()
                ValueField(title: "Gewicht".loc, value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
            }
        }
    }

    private var activityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aktivität".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CalorieMath.activities) { item in
                        Button {
                            withAnimation(.snappy) { activity = item }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.symbol)
                                    .font(.title3)
                                Text(item.name.loc)
                                    .font(.fredoka(11, .semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2, reservesSpace: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(activity == item
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [Theme.accentLight, Theme.accent],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Theme.field),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(activity == item ? .white : Theme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
