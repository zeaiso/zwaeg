import SwiftUI

struct CalorieNeedsView: View {
    @State private var sex: Sex
    @State private var age: Double
    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var activity: ActivityLevel

    init(profile: UserProfile) {
        _sex = State(initialValue: profile.sex)
        _age = State(initialValue: Double(profile.age))
        _heightCm = State(initialValue: profile.heightCm)
        _weightKg = State(initialValue: profile.weightKg)
        _activity = State(initialValue: profile.activity)
    }

    private var bmr: Double {
        CalorieMath.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age))
    }

    private var tdee: Double {
        CalorieMath.tdee(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity)
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
                        ValueField(title: "Alter", value: $age, range: 14...99, step: 1, unit: "Jahre")
                        ValueField(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                        ValueField(title: "Gewicht", value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                        Picker("Aktivität", selection: $activity) {
                            ForEach(ActivityLevel.allCases) { level in
                                Text(level.label).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.appAccent)
                    }
                }

                Card {
                    VStack(spacing: 14) {
                        HStack {
                            VStack(spacing: 4) {
                                Text("Grundumsatz")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(bmr.rounded()))")
                                    .font(.system(.title, design: .rounded).bold())
                                    .contentTransition(.numericText())
                                Text("kcal/Tag")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            Divider()
                            VStack(spacing: 4) {
                                Text("Gesamtumsatz")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(tdee.rounded()))")
                                    .font(.system(.title, design: .rounded).bold())
                                    .foregroundStyle(Color.appAccent)
                                    .contentTransition(.numericText())
                                Text("kcal/Tag")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                Card {
                    VStack(spacing: 12) {
                        Text("Empfehlung je nach Ziel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Goal.allCases) { goal in
                            HStack {
                                Image(systemName: goal.symbol)
                                    .foregroundStyle(Color.appAccent)
                                Text(goal.label)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(CalorieMath.dailyTarget(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity, goal: goal)) kcal")
                                    .fontWeight(.semibold)
                                    .contentTransition(.numericText())
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kalorienbedarf")
        .navigationBarTitleDisplayMode(.inline)
    }
}
