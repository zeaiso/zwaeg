import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    @Query private var foodEntries: [FoodEntry]
    @Environment(\.modelContext) private var context

    @State private var showDeleteConfirm = false

    /// One destination for the debug-arg navigation; stacked
    /// navigationDestination modifiers broke touch delivery on iOS 17.
    private enum Route: Hashable, Identifiable {
        case progress, buddy, language, look, about, goals, reminders

        var id: Self { self }
    }

    @State private var route: Route?

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
            .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
            .background(Theme.background)
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { route in
                switch route {
                case .progress:
                    ProgressScreen(profile: profile)
                case .buddy:
                    BuddyEditView(profile: profile)
                case .language:
                    LanguageView()
                case .look:
                    LookView()
                case .about:
                    AboutView()
                case .goals:
                    GoalsView(profile: profile)
                case .reminders:
                    RemindersView()
                }
            }
            .onAppear {
                if LaunchArgs.all.contains("-open-progress") {
                    route = .progress
                }
                if LaunchArgs.all.contains("-open-buddy") {
                    route = .buddy
                }
                if LaunchArgs.all.contains("-open-language") {
                    route = .language
                }
                if LaunchArgs.all.contains("-open-look") {
                    route = .look
                }
                if LaunchArgs.all.contains("-open-about") {
                    route = .about
                }
                if LaunchArgs.all.contains("-open-goals") {
                    route = .goals
                }
                if LaunchArgs.all.contains("-open-reminders") {
                    route = .reminders
                }
                if LaunchArgs.all.contains("-wipe-data") {
                    DataReset.wipeAll(context: context)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Profil".loc)
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
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 6, y: 2)
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
                Text(profile.name.isEmpty ? "Dein Profil".loc : profile.name)
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(.white)
                Text("Ziel · %@ · %d kcal/Tag".loc(profile.goal.label, profile.dailyCalorieTarget))
                    .font(.fredoka(12))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            NavigationLink {
                PersonalDetailsView(profile: profile)
            } label: {
                Image(systemName: "pencil")
                    .font(.fredoka(16, .semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.25), in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.accentLight, Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 5)
    }

    // MARK: - Stats

    /// Consecutive days with at least one logged food, ending today or
    /// yesterday; banked freezes bridge missed days.
    private var streak: Int {
        Streak.current(loggedDays: Set(foodEntries.map(\.day)))
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            statTile("\(streak)", unit: nil, label: "Tage-Streak".loc)
            statTile("\(foodEntries.count)", unit: nil, label: "Mahlzeiten".loc)
            statTile(String(format: "%.1f", profile.weightKg), unit: "kg", label: "Aktuell".loc)
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
        .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Account list (one card per row)

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KONTO".loc)
                .font(.fredoka(12, .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            accountRow("Mein Buddy".loc, symbol: "face.smiling.inverse", color: Color(red: 1.0, green: 0.51, blue: 0.6)) {
                BuddyEditView(profile: profile)
            }
            accountRow("Persönliche Daten".loc, symbol: "person.fill", color: Color.appAccent) {
                PersonalDetailsView(profile: profile)
            }
            accountRow("Ziele & Vorgaben".loc, symbol: "target", color: Color(red: 0.42, green: 0.36, blue: 0.91)) {
                GoalsView(profile: profile)
            }
            accountRow("Fortschritt & Trends".loc, symbol: "chart.line.uptrend.xyaxis", color: Color(red: 0.13, green: 0.66, blue: 0.42)) {
                ProgressScreen(profile: profile)
            }
            accountRow("Erinnerungen".loc, symbol: "bell.fill", color: Color(red: 0.24, green: 0.68, blue: 1.0)) {
                RemindersView()
            }
            accountRow("Sprache".loc, symbol: "globe", color: Color(red: 0.2, green: 0.68, blue: 0.62)) {
                LanguageView()
            }
            accountRow("Aussehen".loc, symbol: "paintpalette.fill", color: Color(red: 0.78, green: 0.4, blue: 0.85)) {
                LookView()
            }
            accountRow("Hilfe & Support".loc, symbol: "questionmark.circle.fill", color: Color(red: 1.0, green: 0.63, blue: 0.14)) {
                AboutView()
            }
            deleteRow
        }
    }

    // MARK: - Delete all data

    /// Everything is local, so this is the one place the user can start
    /// over: SwiftData, preferences, cached files, reminders.
    private var deleteRow: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Alle Daten löschen".loc)
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Alle Daten löschen".loc,
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Ja, alles löschen".loc, role: .destructive) {
                DataReset.wipeAll(context: context)
            }
            Button("Abbrechen".loc, role: .cancel) {}
        } message: {
            Text("Profil, Tagebuch, Gewichte, Challenges und Einstellungen werden endgültig von diesem Gerät entfernt.".loc)
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
                Image(systemName: "chevron.forward")
                    .font(.fredoka(12, .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language

struct LanguageView: View {
    @State private var lingo = Lingo.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wähle die Sprache der App.".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                sectionLabel("Schweizer Sprachen".loc)
                ForEach(AppLanguage.allCases.filter(\.isSwiss)) { language in
                    languageRow(language)
                }
                sectionLabel("Weitere Sprachen".loc)
                    .padding(.top, 10)
                ForEach(AppLanguage.allCases.filter { !$0.isSwiss }
                    .sorted { $0.label.localizedCompare($1.label) == .orderedAscending }) { language in
                    languageRow(language)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Sprache".loc)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.fredoka(12, .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let isSelected = lingo.language == language
        return Button {
            withAnimation(.snappy) {
                lingo.language = language
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.label)
                        .font(.fredoka(16, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(language.detail)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(isSelected ? Color.appAccent : Color(.systemGray3))
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.appAccent : .clear, lineWidth: 1.5))
            .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Look

struct LookView: View {
    @State private var themer = Themer.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wähle den Look der App.".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                ForEach(AppLook.allCases) { look in
                    lookRow(look)
                }
                sectionLabel("Akzentfarbe".loc)
                    .padding(.top, 10)
                accentCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Aussehen".loc)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let presets: [Color?] = [
        nil,
        Color(red: 0.20, green: 0.48, blue: 0.97),
        Color(red: 0.36, green: 0.33, blue: 0.90),
        Color(red: 0.13, green: 0.66, blue: 0.42),
        Color(red: 0.90, green: 0.22, blue: 0.48),
        Color(red: 0.16, green: 0.62, blue: 0.62),
        Color(red: 0.93, green: 0.61, blue: 0.10),
    ]

    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(Array(Self.presets.enumerated()), id: \.offset) { _, preset in
                    presetDot(preset)
                }
            }
            ColorPicker(selection: Binding(
                get: { themer.accent ?? AppLook.munch.previewAccent },
                set: { themer.accent = $0 }), supportsOpacity: false) {
                Text("Akzentfarbe".loc)
                    .font(.fredoka(14, .medium))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    private func presetDot(_ preset: Color?) -> some View {
        let isSelected = preset == nil
            ? themer.accent == nil
            : preset?.hexString == themer.accent?.hexString
        return Button {
            withAnimation(.snappy) {
                themer.accent = preset
            }
        } label: {
            Circle()
                .fill(preset ?? AppLook.munch.previewAccent)
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(Circle().stroke(Theme.field, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.fredoka(12, .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
    }

    /// The home screen icon follows the look (Munch is the primary icon).
    private func applyIcon(for look: AppLook) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name: String?
        switch look {
        case .munch: name = nil
        case .midnight: name = "AppIconMidnight"
        case .mono: name = "AppIconMono"
        }
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
    }

    private func lookRow(_ look: AppLook) -> some View {
        let isSelected = themer.look == look
        return Button {
            withAnimation(.snappy) {
                themer.look = look
            }
            applyIcon(for: look)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(look.previewBackground)
                    Circle()
                        .fill(look.previewAccent)
                        .frame(width: 17, height: 17)
                }
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(look.label)
                        .font(.fredoka(16, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(look.detail)
                        .font(.fredoka(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(isSelected ? Color.appAccent : Color(.systemGray3))
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.appAccent : .clear, lineWidth: 1.5))
            .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
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
            Section("Über dich".loc) {
                TextField("Name".loc, text: $profile.name)
                Picker("Geschlecht".loc, selection: $profile.sex) {
                    ForEach(Sex.allCases) { s in Text(s.label).tag(s) }
                }
                Stepper("Alter: %d".loc(profile.age), value: $profile.age, in: 14...99)
                Stepper("Grösse: %d cm".loc(Int(profile.heightCm)), value: $profile.heightCm, in: 130...220, step: 1)
            }

            Section("Neues Gewicht eintragen".loc) {
                HStack {
                    TextField(String(format: "%.1f", profile.weightKg), text: $weightText)
                        .keyboardType(.decimalPad)
                    Text("kg").foregroundStyle(.secondary)
                    Button("Speichern".loc) { saveWeight() }
                        .disabled(parsedWeight == nil)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appAccent)
                }
                if showWeightSaved {
                    Label("Gespeichert!".loc, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.appAccent)
                        .font(.fredoka(13))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Persönliche Daten".loc)
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

/// Common energy splits; carb/protein/fat percent, custom keeps own values.
private enum MacroPreset: String, CaseIterable, Identifiable {
    case balanced, highProtein, lowCarb, keto, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: return "Ausgewogen".loc
        case .highProtein: return "High-Protein"
        case .lowCarb: return "Low-Carb"
        case .keto: return "Keto"
        case .custom: return "Eigene".loc
        }
    }

    var shares: (carbs: Int, protein: Int, fat: Int)? {
        switch self {
        case .balanced: return (45, 25, 30)
        case .highProtein: return (35, 35, 30)
        case .lowCarb: return (20, 35, 45)
        case .keto: return (10, 25, 65)
        case .custom: return nil
        }
    }
}

struct GoalsView: View {
    @Bindable var profile: UserProfile
    @State private var customMacros = false
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""
    @AppStorage("waterRemindersOn") private var waterRemindersOn = false
    @AppStorage("mealRemindersOn") private var mealRemindersOn = false
    @AppStorage("fastingRemindersOn") private var fastingRemindersOn = false
    @AppStorage("weighRemindersOn") private var weighRemindersOn = false

    private var enabledMeals: [MealType] {
        MealPlan.enabled(from: enabledMealsRaw)
    }

    var body: some View {
        Form {
            Section("Aktivität & Ziel".loc) {
                Picker("Aktivität".loc, selection: $profile.activity) {
                    ForEach(ActivityLevel.allCases) { level in Text(level.label).tag(level) }
                }
                Picker("Ziel".loc, selection: $profile.goal) {
                    ForEach(Goal.allCases) { g in Text(g.label).tag(g) }
                }
            }
            Section {
                ForEach(MealType.allCases) { meal in
                    Toggle(meal.label, isOn: mealBinding(meal))
                        .disabled(enabledMeals == [meal])
                }
            } header: {
                Text("Mahlzeiten".loc)
            } footer: {
                Text("Dein Kalorienziel verteilt sich auf die gewählten Mahlzeiten. Ausgeblendete Mahlzeiten verschwinden aus dem Tagebuch.".loc)
            }
            Section {
                Picker("Verteilung".loc, selection: macroPresetBinding) {
                    ForEach(MacroPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                if macroPresetBinding.wrappedValue == .custom {
                    Stepper("Protein: %d %%".loc(profile.proteinSharePercent),
                            value: proteinShareBinding, in: 10...50, step: 5)
                    Stepper("Fett: %d %%".loc(profile.fatSharePercent),
                            value: fatShareBinding, in: 10...70, step: 5)
                    LabeledContent("Kohlenhydrate".loc, value: "\(profile.carbSharePercent) %")
                }
            } header: {
                Text("Makro-Verteilung".loc)
            } footer: {
                Text("Ziele: %d g Kohlenhydrate, %d g Protein, %d g Fett".loc(
                    macroGrams.carbs, macroGrams.protein, macroGrams.fat))
            }
            Section {
                Stepper("Wasserziel: %d Gläser".loc(profile.waterGoalGlasses),
                        value: $profile.waterGoalGlasses, in: 4...16)
            } footer: {
                Text("1 Glas = 2.5 dl. 8 Gläser entsprechen 2 Litern am Tag.".loc)
            }
            Section("Ergebnis".loc) {
                LabeledContent("Tagesziel".loc, value: "\(profile.dailyCalorieTarget) kcal")
                LabeledContent("BMI", value: String(format: "%.1f", profile.bmi))
            }
            Section {
                SourcesCard(
                    intro: "Tagesziel nach Mifflin-St Jeor (1990) und FAO/WHO/UNU (2004), BMI-Einordnung nach WHO.".loc,
                    sources: CalculationSources.calorieNeeds + CalculationSources.bmi)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Ziele & Vorgaben".loc)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile.activityRaw) { profile.recalculateTarget() }
        .onChange(of: profile.goalRaw) { profile.recalculateTarget() }
        .onChange(of: enabledMealsRaw) {
            // Meal reminders only cover enabled meals; resync the schedule.
            Task {
                await NotificationService.reschedule(
                    waterOn: waterRemindersOn, mealsOn: mealRemindersOn,
                    fastingOn: fastingRemindersOn, weighOn: weighRemindersOn,
                    times: ReminderStore.load())
            }
        }
    }

    // MARK: - Macro split

    private var currentShares: (carbs: Int, protein: Int, fat: Int) {
        (profile.carbSharePercent, profile.proteinSharePercent, profile.fatSharePercent)
    }

    private var macroPresetBinding: Binding<MacroPreset> {
        Binding(
            get: {
                if customMacros { return .custom }
                return MacroPreset.allCases.first {
                    $0.shares.map { $0 == currentShares } ?? false
                } ?? .custom
            },
            set: { preset in
                if let shares = preset.shares {
                    customMacros = false
                    profile.carbSharePercent = shares.carbs
                    profile.proteinSharePercent = shares.protein
                    profile.fatSharePercent = shares.fat
                } else {
                    customMacros = true
                }
            })
    }

    /// Carbs absorb the change; fat gives way when carbs would drop below 5%.
    private var proteinShareBinding: Binding<Int> {
        Binding(
            get: { profile.proteinSharePercent },
            set: { newValue in
                profile.proteinSharePercent = newValue
                if 100 - newValue - profile.fatSharePercent < 5 {
                    profile.fatSharePercent = max(10, 100 - newValue - 5)
                }
                profile.carbSharePercent = 100 - newValue - profile.fatSharePercent
            })
    }

    private var fatShareBinding: Binding<Int> {
        Binding(
            get: { profile.fatSharePercent },
            set: { newValue in
                profile.fatSharePercent = newValue
                if 100 - profile.proteinSharePercent - newValue < 5 {
                    profile.proteinSharePercent = max(10, 100 - newValue - 5)
                }
                profile.carbSharePercent = 100 - profile.proteinSharePercent - newValue
            })
    }

    private var macroGrams: (carbs: Int, protein: Int, fat: Int) {
        let kcal = Double(profile.dailyCalorieTarget)
        return (Int((kcal * Double(profile.carbSharePercent) / 100 / 4).rounded()),
                Int((kcal * Double(profile.proteinSharePercent) / 100 / 4).rounded()),
                Int((kcal * Double(profile.fatSharePercent) / 100 / 9).rounded()))
    }

    /// The last enabled meal can't be turned off; the toggle is disabled then.
    private func mealBinding(_ meal: MealType) -> Binding<Bool> {
        Binding(
            get: { enabledMeals.contains(meal) },
            set: { isOn in
                var meals = enabledMeals
                if isOn {
                    meals = MealType.allCases.filter { meals.contains($0) || $0 == meal }
                } else {
                    meals.removeAll { $0 == meal }
                }
                guard !meals.isEmpty else { return }
                enabledMealsRaw = MealPlan.rawValue(meals)
            })
    }
}

struct RemindersView: View {
    @AppStorage("waterRemindersOn") private var waterOn = false
    @AppStorage("mealRemindersOn") private var mealsOn = false
    @AppStorage("fastingRemindersOn") private var fastingOn = false
    @AppStorage("weighRemindersOn") private var weighOn = false
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""
    @State private var times = ReminderStore.load()
    @State private var permissionDenied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                waterCard
                mealsCard
                fastingCard
                weighCard
                if permissionDenied {
                    Label("Benachrichtigungen sind deaktiviert. Erlaube sie in den iOS-Einstellungen für Zwäg.".loc,
                          systemImage: "bell.slash")
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Erinnerungen".loc)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: waterOn) { applyChanges() }
        .onChange(of: mealsOn) { applyChanges() }
        .onChange(of: fastingOn) { applyChanges() }
        .onChange(of: weighOn) { applyChanges() }
        .onChange(of: times) { applyChanges() }
    }

    // MARK: - Water

    private var waterCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Wasser trinken".loc,
                          subtitle: "%dx täglich".loc(times.water.count),
                          symbol: "drop.fill",
                          color: Color(red: 0.24, green: 0.64, blue: 1.0),
                          isOn: $waterOn)
                if waterOn {
                    Divider()
                    ForEach(times.water.indices, id: \.self) { index in
                        HStack {
                            // Bounds-checked: rows animating out after a
                            // removal re-evaluate against the shorter array.
                            DatePicker("", selection: minuteBinding(
                                get: { times.water.indices.contains(index) ? times.water[index] : 12 * 60 },
                                set: { if times.water.indices.contains(index) { times.water[index] = $0 } }),
                                displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                            Button {
                                withAnimation(.snappy) {
                                    if times.water.indices.contains(index) {
                                        _ = times.water.remove(at: index)
                                    }
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
                            Label("Zeit hinzufügen".loc, systemImage: "plus")
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

    /// Meals the user eats (MealPlan) that can carry a reminder time.
    private var reminderMeals: [MealType] {
        MealPlan.enabled(from: enabledMealsRaw).filter { $0 != .snack }
    }

    private var mealsCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Mahlzeiten loggen".loc,
                          subtitle: reminderMeals.map(\.label).joined(separator: ", "),
                          symbol: "fork.knife",
                          color: Color.appAccent,
                          isOn: $mealsOn)
                if mealsOn {
                    Divider()
                    if reminderMeals.contains(.breakfast) {
                        mealTimeRow("Frühstück".loc, get: { times.breakfast }, set: { times.breakfast = $0 })
                    }
                    if reminderMeals.contains(.lunch) {
                        mealTimeRow("Mittagessen".loc, get: { times.lunch }, set: { times.lunch = $0 })
                    }
                    if reminderMeals.contains(.dinner) {
                        mealTimeRow("Abendessen".loc, get: { times.dinner }, set: { times.dinner = $0 })
                    }
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

    // MARK: - Fasting

    private var fastingCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Fasten starten".loc,
                          subtitle: "Wenn dein Fastenfenster beginnt".loc,
                          symbol: "timer",
                          color: Color(red: 0.52, green: 0.48, blue: 0.95),
                          isOn: $fastingOn)
                if fastingOn {
                    Divider()
                    mealTimeRow("Startzeit".loc, get: { times.fasting }, set: { times.fasting = $0 })
                }
            }
        }
    }

    // MARK: - Weigh-in

    private var weighCard: some View {
        Card {
            VStack(spacing: 12) {
                toggleRow(title: "Wiegen".loc,
                          subtitle: "Einmal pro Woche".loc,
                          symbol: "scalemass.fill",
                          color: Color(red: 0.13, green: 0.66, blue: 0.42),
                          isOn: $weighOn)
                if weighOn {
                    Divider()
                    weekdayRow
                    mealTimeRow("Uhrzeit".loc, get: { times.weigh }, set: { times.weigh = $0 })
                }
            }
        }
    }

    /// Weekday chips ordered by the locale's first day of the week.
    private var weekdayRow: some View {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Lingo.shared.language.locale
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { weekday in
                let isSelected = times.weighWeekday == weekday
                Button {
                    withAnimation(.snappy) { times.weighWeekday = weekday }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.fredoka(13, isSelected ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? AnyShapeStyle(Theme.ink)
                                               : AnyShapeStyle(Theme.field.opacity(0.6)),
                                    in: Circle())
                        .foregroundStyle(isSelected ? Theme.onInk : .secondary)
                }
                .buttonStyle(.plain)
            }
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
            if waterOn || mealsOn || fastingOn || weighOn {
                let granted = await NotificationService.requestPermission()
                if !granted {
                    permissionDenied = true
                    waterOn = false
                    mealsOn = false
                    fastingOn = false
                    weighOn = false
                    await NotificationService.reschedule(
                        waterOn: false, mealsOn: false, fastingOn: false, weighOn: false,
                        times: times)
                    return
                }
            }
            permissionDenied = false
            await NotificationService.reschedule(
                waterOn: waterOn, mealsOn: mealsOn, fastingOn: fastingOn, weighOn: weighOn,
                times: times)
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.appAccent)
                Text("Zwäg")
                    .font(.fredoka(22, .semibold))
                Text("Version %@ · Zwäg heisst: fit und wohl. Dein Schweizer Kalorien-Tracker."
                    .loc(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                Text("Nährwertdaten: Schweizer Nährwertdatenbank V7.0, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, sowie Open Food Facts (Open Database License, ODbL). Avatare erstellt mit DiceBear (dicebear.com), Stile Thumbs (CC0) und Avataaars von Pablo Stanley. Schrift: Fredoka (SIL Open Font License). Alle persönlichen Daten bleiben auf deinem Gerät.")
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
                SourcesCard(
                    intro: "BMI-Einordnung nach WHO, Kalorienbedarf nach Mifflin-St Jeor und FAO/WHO/UNU, Idealgewicht nach Devine, Robinson, Miller und Broca, Aktivitätsverbrauch nach dem Compendium of Physical Activities.".loc,
                    sources: CalculationSources.all)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
        .background(Theme.background)
        .navigationTitle("Hilfe & Support".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
