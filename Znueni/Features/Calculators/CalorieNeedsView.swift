import SwiftUI

struct CalorieNeedsView: View {
    @State private var sex: Sex
    @State private var age: Double
    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var activity: ActivityLevel
    private let goal: Goal

    init(profile: UserProfile) {
        self.goal = profile.goal
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
                DetailHeader(title: "Kalorienbedarf", subtitle: "Grund- & Gesamtumsatz pro Tag")
                inputCard
                resultTiles
                goalsCard
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
                ValueField(title: "Alter", value: $age, range: 14...99, step: 1, unit: "Jahre")
                Divider()
                ValueField(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                Divider()
                ValueField(title: "Gewicht", value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                Divider()
                HStack {
                    Text("Aktivität")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Aktivität", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appAccent)
                }
            }
        }
    }

    private var resultTiles: some View {
        HStack(spacing: 12) {
            resultTile(value: "\(Int(tdee.rounded()))",
                       label: "Gesamtumsatz",
                       background: AnyShapeStyle(LinearGradient(
                          colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
                          startPoint: .topLeading, endPoint: .bottomTrailing)))
            resultTile(value: "\(Int(bmr.rounded()))",
                       label: "Grundumsatz",
                       background: AnyShapeStyle(Theme.ink))
        }
    }

    private func resultTile(value: String, label: String, background: AnyShapeStyle) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text("\(label) · kcal/Tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.10), radius: 10, y: 4)
    }

    private var goalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Deine Empfehlung")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    Image(systemName: goal.symbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 40, height: 40)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Dein Ziel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(CalorieMath.dailyTarget(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity, goal: goal)) kcal")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Color.appAccent)
                        .contentTransition(.numericText())
                }
                Text("Änderbar unter Profil, Ziele & Vorgaben.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
