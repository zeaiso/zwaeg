import SwiftUI
import SwiftData

struct DiaryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var addSheetMeal: MealType?
    @State private var activity = HealthKitService.DayActivity()

    private var health: HealthKitService { HealthKitService.shared }

    private var dayEntries: [FoodEntry] {
        allEntries.filter { $0.day == selectedDay }
    }

    private var consumed: Int {
        dayEntries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    weekStrip
                    intakeCard
                    HStack(spacing: 16) {
                        stepsCard
                        waterCard
                    }
                    ForEach(MealType.allCases) { meal in
                        mealCard(meal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $addSheetMeal) { meal in
                AddFoodView(day: selectedDay, meal: meal)
            }
            .task(id: selectedDay) {
                await refreshActivity()
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return "Guten Morgen"
        case 11..<18: return "Hallo"
        default: return "Guten Abend"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(greeting)
                    Image(systemName: "hand.wave.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.73, blue: 0.2))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(profile.name.isEmpty ? "Willkommen!" : profile.name)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Text(initials)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.lime, in: Circle())
        }
        .padding(.top, 8)
    }

    private var initials: String {
        let parts = profile.name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "Z" : String(parts).uppercased()
    }

    // MARK: - Week strip

    private var lastSevenDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 8) {
            ForEach(lastSevenDays, id: \.self) { day in
                let isSelected = day == selectedDay
                Button {
                    withAnimation(.snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(isSelected ? Theme.ink : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Theme.lime : Theme.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Theme.ink.opacity(isSelected ? 0.08 : 0.03), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Intake

    private var progress: Double {
        guard profile.dailyCalorieTarget > 0 else { return 0 }
        return min(1, Double(consumed) / Double(profile.dailyCalorieTarget))
    }

    private var intakeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Tagesbilanz", systemImage: "fork.knife")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int((progress * 100).rounded())) %")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.yellow, in: Capsule())
                        .foregroundStyle(Theme.ink)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.field)
                        Capsule()
                            .fill(consumed > profile.dailyCalorieTarget ? Color.orange : Theme.lime)
                            .frame(width: max(10, geo.size.width * progress))
                            .animation(.spring(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 14)

                HStack {
                    intakeStat("Gegessen", "\(consumed)")
                    Divider().frame(height: 28)
                    intakeStat("Verbrannt", health.isConnected ? "\(activity.activeKcal)" : "–")
                    Divider().frame(height: 28)
                    intakeStat("Übrig", "\(max(0, profile.dailyCalorieTarget - consumed))")
                }

                macroRow
            }
        }
    }

    private func intakeStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var macroRow: some View {
        let protein = dayEntries.reduce(0.0) { $0 + $1.proteinG }
        let carbs = dayEntries.reduce(0.0) { $0 + $1.carbsG }
        let fat = dayEntries.reduce(0.0) { $0 + $1.fatG }
        return HStack(spacing: 14) {
            macroBadge("Protein", grams: protein, color: .blue)
            macroBadge("Kohlenh.", grams: carbs, color: .orange)
            macroBadge("Fett", grams: fat, color: .purple)
            Spacer()
        }
    }

    private func macroBadge(_ name: String, grams: Double, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(name) \(Int(grams.rounded()))g")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Steps & water

    private var stepsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Schritte")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "figure.walk")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.orange.gradient, in: Circle())
                }
                if health.isConnected {
                    Text("\(activity.steps)")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("heute")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if HealthKitService.isAvailable {
                    Spacer(minLength: 2)
                    Button {
                        Task {
                            await health.requestAuthorization()
                            await refreshActivity()
                        }
                    } label: {
                        Text("Verbinden")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.lime, in: Capsule())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("–")
                        .font(.system(.title2, design: .rounded).bold())
                }
            }
        }
    }

    private var waterEntry: WaterDay? {
        waterDays.first { $0.day == selectedDay }
    }

    private var waterCard: some View {
        let glasses = waterEntry?.glasses ?? 0
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Wasser")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "drop.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.gradient, in: Circle())
                }
                Text("\(glasses) Glas")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                HStack(spacing: 10) {
                    Button {
                        addWater(-1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(Theme.field, in: Circle())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(glasses == 0)
                    Button {
                        addWater(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(Theme.lime, in: Circle())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addWater(_ delta: Int) {
        withAnimation(.snappy) {
            if let entry = waterEntry {
                entry.glasses = max(0, entry.glasses + delta)
            } else if delta > 0 {
                context.insert(WaterDay(day: selectedDay, glasses: delta))
            }
        }
    }

    // MARK: - Meals

    private func mealCard(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.meal == meal }
        let kcal = entries.reduce(0) { $0 + $1.calories }
        return Card {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: meal.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 42, height: 42)
                        .background(Theme.limeSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.label)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text(kcal > 0 ? "\(kcal) kcal" : "Noch nichts geloggt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        addSheetMeal = meal
                    } label: {
                        Text("Add")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Theme.lime, in: Capsule())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
                if !entries.isEmpty {
                    Divider()
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer()
                            Text("\(entry.calories) kcal")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(entry)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func refreshActivity() async {
        guard health.isConnected else { return }
        activity = await health.activity(for: selectedDay)
    }
}
