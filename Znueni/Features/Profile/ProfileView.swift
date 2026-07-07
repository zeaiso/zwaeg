import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    @State private var weightText = ""
    @State private var showWeightSaved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.appAccent)
                        VStack(alignment: .leading) {
                            Text(profile.name.isEmpty ? "Dein Profil" : profile.name)
                                .font(.headline)
                            Text("Ziel: \(profile.goal.label) · \(profile.dailyCalorieTarget) kcal/Tag")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Neues Gewicht eintragen") {
                    HStack {
                        TextField(String(format: "%.1f", profile.weightKg), text: $weightText)
                            .keyboardType(.decimalPad)
                        Text("kg").foregroundStyle(.secondary)
                        Button("Speichern") { saveWeight() }
                            .disabled(parsedWeight == nil)
                            .buttonStyle(.borderedProminent)
                            .tint(.appAccent)
                    }
                    if showWeightSaved {
                        Label("Gespeichert!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.appAccent)
                            .font(.footnote)
                    }
                }

                Section("Körperdaten") {
                    Picker("Geschlecht", selection: $profile.sex) {
                        ForEach(Sex.allCases) { s in Text(s.label).tag(s) }
                    }
                    Stepper("Alter: \(profile.age)", value: $profile.age, in: 14...99)
                    Stepper("Grösse: \(Int(profile.heightCm)) cm", value: $profile.heightCm, in: 130...220, step: 1)
                }

                Section("Aktivität & Ziel") {
                    Picker("Aktivität", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases) { level in Text(level.label).tag(level) }
                    }
                    Picker("Ziel", selection: $profile.goal) {
                        ForEach(Goal.allCases) { g in Text(g.label).tag(g) }
                    }
                }

                Section("Übersicht") {
                    LabeledContent("BMI", value: String(format: "%.1f", profile.bmi))
                    LabeledContent("Kategorie", value: CalorieMath.bmiCategory(profile.bmi).label)
                    LabeledContent("Tagesziel", value: "\(profile.dailyCalorieTarget) kcal")
                }
            }
            .navigationTitle("Profil")
            .onChange(of: profile.sexRaw) { recalc() }
            .onChange(of: profile.age) { recalc() }
            .onChange(of: profile.heightCm) { recalc() }
            .onChange(of: profile.activityRaw) { recalc() }
            .onChange(of: profile.goalRaw) { recalc() }
        }
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    private func saveWeight() {
        guard let weight = parsedWeight, weight > 20, weight < 400 else { return }
        profile.weightKg = weight
        context.insert(WeightEntry(weightKg: weight))
        recalc()
        weightText = ""
        withAnimation { showWeightSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showWeightSaved = false }
        }
    }

    private func recalc() {
        profile.recalculateTarget()
    }
}
