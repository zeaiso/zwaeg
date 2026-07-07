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
                Card {
                    VStack(spacing: 12) {
                        Text("Verbrauch")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ResultNumber(value: "\(Int(burned.rounded()))", unit: "kcal", color: .orange)
                        Text("\(activity.name) · \(Int(minutes)) Min · \(String(format: "%.1f", weightKg)) kg")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Card {
                    VStack(spacing: 20) {
                        ValueSlider(title: "Dauer", value: $minutes, range: 5...240, step: 5, unit: "Min")
                        ValueSlider(title: "Gewicht", value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aktivität")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(CalorieMath.activities) { item in
                                Button {
                                    activity = item
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: item.symbol)
                                            .font(.title3)
                                        Text(item.name)
                                            .font(.caption2.weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2, reservesSpace: true)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(activity == item ? Color.appAccent.opacity(0.15)
                                                                 : Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(activity == item ? Color.appAccent : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(activity == item ? Color.appAccent : .clear, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kalorienverbrauch")
        .navigationBarTitleDisplayMode(.inline)
    }
}
