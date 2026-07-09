import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable {
        case welcome, name, sex, age, height, weight, activity, goal, buddy, result
    }

    @State private var step: Step = {
        if CommandLine.arguments.contains("-onboarding-buddy") { return .buddy }
        if CommandLine.arguments.contains("-onboarding-body") { return .age }
        return .welcome
    }()
    @State private var name = ""
    @State private var sex: Sex = .male
    @State private var age = 30.0
    @State private var heightCm = 175.0
    @State private var weightKg = 75.0
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: Goal = .lose
    @State private var buddy = Buddy(kind: "", index: 0)

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
                case .age: ageStep
                case .height: heightStep
                case .weight: weightStep
                case .activity: activityStep
                case .goal: goalStep
                case .buddy: buddyStep
                case .result: resultStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

            controls
        }
        .background(Theme.background)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(Color.appAccent)
            Text("Willkommen!".loc)
                .font(.fredoka(32, .semibold))
            Text("Dein persönlicher Kalorien-Tracker.\nIn einer Minute eingerichtet.".loc)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Wie heißt du?".loc)
            TextField("Dein Name".loc, text: $name)
                .font(.title2)
                .padding()
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .textInputAutocapitalization(.words)
        }
    }

    private var sexStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Dein Geschlecht".loc)
            Text("Wird für die Kalorienberechnung benötigt.".loc)
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
                                .font(.fredoka(17, .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(sex == s ? Color.appAccent.opacity(0.15)
                                             : Theme.card)
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

    private var ageStep: some View {
        questionStep("Wie alt bist du?".loc) {
            BigValueField(value: $age, range: 14...99, step: 1, unit: "Jahre".loc)
        }
    }

    private var heightStep: some View {
        questionStep("Wie groß bist du?".loc) {
            BigValueField(value: $heightCm, range: 130...220, step: 1, unit: "cm")
        }
    }

    private var weightStep: some View {
        questionStep("Wie viel wiegst du?".loc) {
            BigValueField(value: $weightKg, range: 40...200, step: 0.5, unit: "kg", fractionDigits: 1)
        }
    }

    private func questionStep<Content: View>(_ title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 40) {
            stepTitle(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private var activityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Wie aktiv bist du?".loc)
            ForEach(ActivityLevel.allCases) { level in
                Button {
                    activity = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.label).font(.fredoka(17, .semibold))
                            Text(level.detail).font(.fredoka(13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if activity == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(14)
                    .background(Theme.card)
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
            stepTitle("Dein Ziel".loc)
            ForEach(Goal.allCases) { g in
                Button {
                    goal = g
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: g.symbol)
                            .font(.title2)
                            .foregroundStyle(goal == g ? Color.appAccent : .secondary)
                        Text(g.label).font(.fredoka(17, .semibold))
                        Spacer()
                        if goal == g {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(16)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(goal == g ? Color.appAccent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buddyStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepTitle("Wähle deinen Buddy".loc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Dein Begleiter für Battles und mehr.".loc)
                    .font(.fredoka(15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BuddyPickerView(buddy: $buddy, sex: sex)
            }
        }
        .onAppear {
            if buddy.kind.isEmpty || (buddy.kind != "blob" && buddy.kind != (sex == .male ? "m" : "f")) {
                buddy = .random(for: sex)
            }
        }
    }

    private var resultStep: some View {
        VStack(spacing: 24) {
            Text(name.isEmpty ? "Dein Tagesziel".loc : "%@, dein Tagesziel".loc(name))
                .font(.fredoka(22, .semibold))
            ResultNumber(value: "\(target)", unit: "kcal")
            Card {
                VStack(spacing: 12) {
                    resultRow("BMI", String(format: "%.1f", CalorieMath.bmi(weightKg: weightKg, heightCm: heightCm)))
                    Divider()
                    resultRow("Grundumsatz".loc, "\(Int(CalorieMath.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age)).rounded())) kcal")
                    Divider()
                    resultRow("Gesamtumsatz".loc, "\(Int(CalorieMath.tdee(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity).rounded())) kcal")
                    Divider()
                    resultRow("Ziel".loc, goal.label)
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
        Text(text).font(.fredoka(27, .semibold))
    }

    // MARK: - Navigation controls

    private var controls: some View {
        HStack {
            if step != .welcome {
                Button("Zurück".loc) {
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
                Text(step == .result ? "Los geht's!".loc : "Weiter".loc)
                    .font(.fredoka(17, .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
    }

    private func finish() {
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespaces),
                                  sex: sex, age: Int(age), heightCm: heightCm,
                                  weightKg: weightKg, activity: activity, goal: goal)
        profile.buddy = buddy
        context.insert(profile)
        context.insert(WeightEntry(weightKg: weightKg))
    }
}
