import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable {
        case welcome, name, sex, body, activity, goal, result
    }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var sex: Sex = .male
    @State private var age = 30.0
    @State private var heightCm = 175.0
    @State private var weightKg = 75.0
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: Goal = .lose

    private var target: Int {
        CalorieMath.dailyTarget(sex: sex, weightKg: weightKg, heightCm: heightCm,
                                age: Int(age), activity: activity, goal: goal)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                    .tint(.appAccent)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Group {
                switch step {
                case .welcome: welcome
                case .name: nameStep
                case .sex: sexStep
                case .body: bodyStep
                case .activity: activityStep
                case .goal: goalStep
                case .result: resultStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

            controls
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(Color.appAccent)
            Text("Willkommen!")
                .font(.system(.largeTitle, design: .rounded).bold())
            Text("Dein persönlicher Kalorien-Tracker.\nIn einer Minute eingerichtet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Wie heisst du?")
            TextField("Dein Name", text: $name)
                .font(.title2)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .textInputAutocapitalization(.words)
        }
    }

    private var sexStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Dein Geschlecht")
            Text("Wird für die Kalorienberechnung benötigt.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Sex.allCases) { s in
                    Button {
                        sex = s
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: s.symbol)
                                .font(.system(size: 40))
                            Text(s.label)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(sex == s ? Color.appAccent.opacity(0.15)
                                             : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(sex == s ? Color.appAccent : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(sex == s ? Color.appAccent : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepTitle("Dein Körper")
            Card {
                VStack(spacing: 20) {
                    ValueSlider(title: "Alter", value: $age, range: 14...99, step: 1, unit: "Jahre")
                    ValueSlider(title: "Grösse", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                    ValueSlider(title: "Gewicht", value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                }
            }
        }
    }

    private var activityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Wie aktiv bist du?")
            ForEach(ActivityLevel.allCases) { level in
                Button {
                    activity = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.label).font(.headline)
                            Text(level.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if activity == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(activity == level ? Color.appAccent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Dein Ziel")
            ForEach(Goal.allCases) { g in
                Button {
                    goal = g
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: g.symbol)
                            .font(.title2)
                            .foregroundStyle(goal == g ? Color.appAccent : .secondary)
                        Text(g.label).font(.headline)
                        Spacer()
                        if goal == g {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(goal == g ? Color.appAccent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resultStep: some View {
        VStack(spacing: 24) {
            Text(name.isEmpty ? "Dein Tagesziel" : "\(name), dein Tagesziel")
                .font(.system(.title2, design: .rounded).bold())
            ResultNumber(value: "\(target)", unit: "kcal")
            Card {
                VStack(spacing: 12) {
                    resultRow("BMI", String(format: "%.1f", CalorieMath.bmi(weightKg: weightKg, heightCm: heightCm)))
                    Divider()
                    resultRow("Grundumsatz", "\(Int(CalorieMath.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age)).rounded())) kcal")
                    Divider()
                    resultRow("Gesamtumsatz", "\(Int(CalorieMath.tdee(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity).rounded())) kcal")
                    Divider()
                    resultRow("Ziel", goal.label)
                }
            }
        }
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text).font(.system(.title, design: .rounded).bold())
    }

    // MARK: - Navigation controls

    private var controls: some View {
        HStack {
            if step != .welcome {
                Button("Zurück") {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if step == .result {
                    finish()
                } else {
                    withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .result }
                }
            } label: {
                Text(step == .result ? "Los geht's!" : "Weiter")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.appAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
    }

    private func finish() {
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespaces),
                                  sex: sex, age: Int(age), heightCm: heightCm,
                                  weightKg: weightKg, activity: activity, goal: goal)
        context.insert(profile)
        context.insert(WeightEntry(weightKg: weightKg))
    }
}
