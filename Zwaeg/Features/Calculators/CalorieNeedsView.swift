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
                DetailHeader(title: "Kalorienbedarf".loc, subtitle: "Grund- & Gesamtumsatz pro Tag".loc)
                inputCard
                resultTiles
                goalsCard
                SourcesCard(
                    intro: "Grundumsatz nach Mifflin-St Jeor (1990), Aktivitätsfaktoren (PAL) nach FAO/WHO/UNU (2004).".loc,
                    sources: CalculationSources.calorieNeeds)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var inputCard: some View {
        Card {
            VStack(spacing: 14) {
                Picker("Geschlecht".loc, selection: $sex) {
                    ForEach(Sex.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                ValueField(title: "Alter".loc, value: $age, range: 14...99, step: 1, unit: "Jahre".loc)
                Divider()
                ValueField(title: "Grösse".loc, value: $heightCm, range: 130...220, step: 1, unit: "cm")
                Divider()
                ValueField(title: "Gewicht".loc, value: $weightKg, range: 40...200, step: 0.5, unit: "kg", format: "%.1f")
                Divider()
                HStack {
                    Text("Aktivität".loc)
                        .font(.fredoka(15))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Aktivität".loc, selection: $activity) {
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
                       label: "Gesamtumsatz".loc,
                       background: AnyShapeStyle(LinearGradient(
                          colors: [Theme.accentLight, Theme.accent],
                          startPoint: .topLeading, endPoint: .bottomTrailing)))
            resultTile(value: "\(Int(bmr.rounded()))",
                       label: "Grundumsatz".loc,
                       background: AnyShapeStyle(Theme.ink), foreground: Theme.onInk)
        }
    }

    private func resultTile(value: String, label: String, background: AnyShapeStyle,
                            foreground: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.fredoka(27, .semibold))
                .foregroundStyle(foreground)
                .contentTransition(.numericText())
            Text("%@ · kcal/Tag".loc(label))
                .font(.fredoka(12, .semibold))
                .foregroundStyle(foreground.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.10), radius: 10, y: 4)
    }

    private var goalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Deine Empfehlung".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    Image(systemName: goal.symbol)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 40, height: 40)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.label)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Dein Ziel".loc)
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(CalorieMath.dailyTarget(sex: sex, weightKg: weightKg, heightCm: heightCm, age: Int(age), activity: activity, goal: goal)) kcal")
                        .font(.fredoka(19, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .contentTransition(.numericText())
                }
                Text("Änderbar unter Profil, Ziele & Vorgaben.".loc)
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
