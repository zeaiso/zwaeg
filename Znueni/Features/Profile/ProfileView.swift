import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    @Query private var foodEntries: [FoodEntry]

    @State private var showProgress = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    identityCard
                    statTiles
                    accountList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showProgress) {
                ProgressScreen(profile: profile)
            }
            .onAppear {
                if CommandLine.arguments.contains("-open-progress") {
                    showProgress = true
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Profil")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
            Spacer()
            NavigationLink {
                AboutView()
            } label: {
                Image(systemName: "sun.max")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.ink.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Identity (coral gradient card)

    private var initials: String {
        let parts = profile.name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "Z" : String(parts).uppercased()
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Color.appAccent)
                .frame(width: 58, height: 58)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name.isEmpty ? "Dein Profil" : profile.name)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text("Ziel · \(profile.goal.label) · \(profile.dailyCalorieTarget) kcal/Tag")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            NavigationLink {
                PersonalDetailsView(profile: profile)
            } label: {
                Text("Edit")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.25), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.47, blue: 0.30), Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 5)
    }

    // MARK: - Stats

    /// Consecutive days with at least one logged food, ending today or yesterday.
    private var streak: Int {
        let loggedDays = Set(foodEntries.map(\.day))
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        if !loggedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while loggedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            statTile("\(streak)", unit: nil, label: "Tage-Streak")
            statTile("\(foodEntries.count)", unit: nil, label: "Mahlzeiten")
            statTile(String(format: "%.1f", profile.weightKg), unit: "kg", label: "Aktuell")
        }
    }

    private func statTile(_ value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Account list (one card per row)

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KONTO")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            accountRow("Persönliche Daten", symbol: "person.fill", color: Color.appAccent) {
                PersonalDetailsView(profile: profile)
            }
            accountRow("Ziele & Vorgaben", symbol: "target", color: Color(red: 0.42, green: 0.36, blue: 0.91)) {
                GoalsView(profile: profile)
            }
            accountRow("Fortschritt & Trends", symbol: "chart.line.uptrend.xyaxis", color: Color(red: 0.13, green: 0.66, blue: 0.42)) {
                ProgressScreen(profile: profile)
            }
            accountRow("Erinnerungen", symbol: "bell.fill", color: Color(red: 0.24, green: 0.68, blue: 1.0)) {
                RemindersPlaceholderView()
            }
            accountRow("Hilfe & Support", symbol: "questionmark.circle.fill", color: Color(red: 1.0, green: 0.63, blue: 0.14)) {
                AboutView()
            }
        }
    }

    private func accountRow<Destination: View>(
        _ title: String, symbol: String, color: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscreens

struct PersonalDetailsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    @State private var weightText = ""
    @State private var showWeightSaved = false

    var body: some View {
        Form {
            Section("Über dich") {
                TextField("Name", text: $profile.name)
                Picker("Geschlecht", selection: $profile.sex) {
                    ForEach(Sex.allCases) { s in Text(s.label).tag(s) }
                }
                Stepper("Alter: \(profile.age)", value: $profile.age, in: 14...99)
                Stepper("Grösse: \(Int(profile.heightCm)) cm", value: $profile.heightCm, in: 130...220, step: 1)
            }

            Section("Neues Gewicht eintragen") {
                HStack {
                    TextField(String(format: "%.1f", profile.weightKg), text: $weightText)
                        .keyboardType(.decimalPad)
                    Text("kg").foregroundStyle(.secondary)
                    Button("Speichern") { saveWeight() }
                        .disabled(parsedWeight == nil)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appAccent)
                }
                if showWeightSaved {
                    Label("Gespeichert!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.appAccent)
                        .font(.footnote)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Persönliche Daten")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile.sexRaw) { profile.recalculateTarget() }
        .onChange(of: profile.age) { profile.recalculateTarget() }
        .onChange(of: profile.heightCm) { profile.recalculateTarget() }
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    private func saveWeight() {
        guard let weight = parsedWeight, weight > 20, weight < 400 else { return }
        profile.weightKg = weight
        context.insert(WeightEntry(weightKg: weight))
        Task { await HealthKitService.shared.saveWeight(weight) }
        profile.recalculateTarget()
        weightText = ""
        withAnimation { showWeightSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showWeightSaved = false }
        }
    }
}

struct GoalsView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section("Aktivität & Ziel") {
                Picker("Aktivität", selection: $profile.activity) {
                    ForEach(ActivityLevel.allCases) { level in Text(level.label).tag(level) }
                }
                Picker("Ziel", selection: $profile.goal) {
                    ForEach(Goal.allCases) { g in Text(g.label).tag(g) }
                }
            }
            Section("Ergebnis") {
                LabeledContent("Tagesziel", value: "\(profile.dailyCalorieTarget) kcal")
                LabeledContent("BMI", value: String(format: "%.1f", profile.bmi))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Ziele & Vorgaben")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile.activityRaw) { profile.recalculateTarget() }
        .onChange(of: profile.goalRaw) { profile.recalculateTarget() }
    }
}

struct RemindersPlaceholderView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)
            Text("Erinnerungen")
                .font(.system(.title3, design: .rounded).bold())
            Text("Push-Erinnerungen für Mahlzeiten und Wasser kommen in einem späteren Update.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Erinnerungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.appAccent)
            Text("Znüni")
                .font(.system(.title2, design: .rounded).bold())
            Text("Version 0.1 · Dein Schweizer Kalorien-Tracker")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Nährwertdaten: Open Food Facts und kuratierte Schweizer Lebensmittelliste. Alle persönlichen Daten bleiben auf deinem Gerät.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Hilfe & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
