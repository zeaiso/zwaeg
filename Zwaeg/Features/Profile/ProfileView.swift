import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    @Query private var foodEntries: [FoodEntry]

    @State private var showProgress = false
    @State private var showBuddyEdit = false

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
            .navigationDestination(isPresented: $showBuddyEdit) {
                BuddyEditView(profile: profile)
            }
            .onAppear {
                if CommandLine.arguments.contains("-open-progress") {
                    showProgress = true
                }
                if CommandLine.arguments.contains("-open-buddy") {
                    showBuddyEdit = true
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Profil")
                .font(.fredoka(27, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            NavigationLink {
                AboutView()
            } label: {
                Image(systemName: "sun.max")
                    .font(.fredoka(17, .semibold))
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

    private var identityCard: some View {
        HStack(spacing: 14) {
            NavigationLink {
                BuddyEditView(profile: profile)
            } label: {
                BuddyView(buddy: profile.buddy, size: 44)
                    .frame(width: 58, height: 58)
                    .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name.isEmpty ? "Dein Profil" : profile.name)
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(.white)
                Text("Ziel · \(profile.goal.label) · \(profile.dailyCalorieTarget) kcal/Tag")
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            NavigationLink {
                PersonalDetailsView(profile: profile)
            } label: {
                Text("Edit")
                    .font(.fredoka(15, .semibold))
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
                    .font(.fredoka(22, .semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.fredoka(12, .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            Text(label)
                .font(.fredoka(12))
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
                .font(.fredoka(12, .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            accountRow("Mein Buddy", symbol: "face.smiling.inverse", color: Color(red: 1.0, green: 0.51, blue: 0.6)) {
                BuddyEditView(profile: profile)
            }
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
                RemindersView()
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
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.fredoka(12, .semibold))
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
                        .font(.fredoka(13))
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
            Section {
                Stepper("Wasserziel: \(profile.waterGoalGlasses) Gläser",
                        value: $profile.waterGoalGlasses, in: 4...16)
            } footer: {
                Text("1 Glas = 2.5 dl. 8 Gläser entsprechen 2 Litern am Tag.")
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

struct RemindersView: View {
    @AppStorage("waterRemindersOn") private var waterOn = false
    @AppStorage("mealRemindersOn") private var mealsOn = false
    @State private var times = ReminderStore.load()
    @State private var permissionDenied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                waterCard
                mealsCard
                if permissionDenied {
                    Label("Benachrichtigungen sind deaktiviert. Erlaube sie in den iOS-Einstellungen für Zwäg.",
                          systemImage: "bell.slash")
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Erinnerungen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: waterOn) { applyChanges() }
        .onChange(of: mealsOn) { applyChanges() }
        .onChange(of: times) { applyChanges() }
    }

    // MARK: - Water

    private var waterCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Wasser trinken",
                          subtitle: "\(times.water.count)x täglich",
                          symbol: "drop.fill",
                          color: Color(red: 0.24, green: 0.64, blue: 1.0),
                          isOn: $waterOn)
                if waterOn {
                    Divider()
                    ForEach(times.water.indices, id: \.self) { index in
                        HStack {
                            DatePicker("", selection: minuteBinding(
                                get: { times.water[index] },
                                set: { times.water[index] = $0 }),
                                displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                            Button {
                                withAnimation(.snappy) {
                                    _ = times.water.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.field, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(times.water.count == 1)
                        }
                    }
                    if times.water.count < 8 {
                        Button {
                            withAnimation(.snappy) {
                                times.water.append(14 * 60)
                            }
                        } label: {
                            Label("Zeit hinzufügen", systemImage: "plus")
                                .font(.fredoka(14, .semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Meals

    private var mealsCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Mahlzeiten loggen",
                          subtitle: "Frühstück, Mittag- und Abendessen",
                          symbol: "fork.knife",
                          color: Color.appAccent,
                          isOn: $mealsOn)
                if mealsOn {
                    Divider()
                    mealTimeRow("Frühstück", get: { times.breakfast }, set: { times.breakfast = $0 })
                    mealTimeRow("Mittagessen", get: { times.lunch }, set: { times.lunch = $0 })
                    mealTimeRow("Abendessen", get: { times.dinner }, set: { times.dinner = $0 })
                }
            }
        }
    }

    private func mealTimeRow(_ title: String, get: @escaping () -> Int,
                             set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.fredoka(14))
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker("", selection: minuteBinding(get: get, set: set),
                       displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    // MARK: - Shared pieces

    private func toggleRow(title: String, subtitle: String, symbol: String,
                           color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.fredoka(14, .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.fredoka(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.appAccent)
        }
    }

    /// Bridges minutes-since-midnight storage to DatePicker dates.
    private func minuteBinding(get: @escaping () -> Int,
                               set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding(
            get: {
                let minutes = get()
                return Calendar.current.date(bySettingHour: minutes / 60,
                                             minute: minutes % 60,
                                             second: 0, of: .now) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                set((components.hour ?? 0) * 60 + (components.minute ?? 0))
            })
    }

    private func applyChanges() {
        ReminderStore.save(times)
        Task {
            if waterOn || mealsOn {
                let granted = await NotificationService.requestPermission()
                if !granted {
                    permissionDenied = true
                    waterOn = false
                    mealsOn = false
                    await NotificationService.reschedule(waterOn: false, mealsOn: false, times: times)
                    return
                }
            }
            permissionDenied = false
            await NotificationService.reschedule(waterOn: waterOn, mealsOn: mealsOn, times: times)
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.appAccent)
            Text("Zwäg")
                .font(.fredoka(22, .semibold))
            Text("Version 0.1 · Zwäg heisst: fit und wohl. Dein Schweizer Kalorien-Tracker.")
                .font(.fredoka(13))
                .foregroundStyle(.secondary)
            Text("Nährwertdaten: Schweizer Nährwertdatenbank V7.0, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, sowie Open Food Facts. Avatare erstellt mit DiceBear (dicebear.com), Stile Thumbs (CC0) und Avataaars von Pablo Stanley. Schrift: Fredoka (SIL Open Font License). Alle persönlichen Daten bleiben auf deinem Gerät.")
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            if let blv = URL(string: "https://naehrwertdaten.ch"),
               let off = URL(string: "https://ch.openfoodfacts.org") {
                HStack(spacing: 16) {
                    Link("naehrwertdaten.ch", destination: blv)
                    Link("openfoodfacts.org", destination: off)
                    if let dice = URL(string: "https://dicebear.com") {
                        Link("dicebear.com", destination: dice)
                    }
                }
                .font(.fredoka(12, .semibold))
                .tint(Color.appAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Hilfe & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
