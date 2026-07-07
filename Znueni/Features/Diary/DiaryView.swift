import SwiftUI
import SwiftData

struct DiaryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var addSheetMeal: MealType?

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
                    summaryCard
                    ForEach(MealType.allCases) { meal in
                        mealCard(meal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tagebuch")
            .toolbar {
                ToolbarItem(placement: .principal) { dayPicker }
            }
            .sheet(item: $addSheetMeal) { meal in
                AddFoodView(day: selectedDay, meal: meal)
            }
        }
    }

    // MARK: - Day navigation

    private var dayPicker: some View {
        HStack(spacing: 16) {
            Button {
                shift(days: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Text(dayLabel)
                .font(.headline)
                .frame(minWidth: 110)
            Button {
                shift(days: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedDay >= Calendar.current.startOfDay(for: .now))
        }
        .tint(.appAccent)
    }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "Heute" }
        if cal.isDateInYesterday(selectedDay) { return "Gestern" }
        return selectedDay.formatted(.dateTime.weekday(.abbreviated).day().month())
    }

    private func shift(days: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) {
            withAnimation { selectedDay = Calendar.current.startOfDay(for: newDay) }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        Card {
            HStack(spacing: 20) {
                CalorieRingView(consumed: consumed, target: profile.dailyCalorieTarget)
                    .frame(width: 130, height: 130)
                VStack(alignment: .leading, spacing: 12) {
                    statRow(symbol: "fork.knife", title: "Gegessen", value: "\(consumed) kcal")
                    statRow(symbol: "target", title: "Tagesziel", value: "\(profile.dailyCalorieTarget) kcal")
                    macroRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var macroRow: some View {
        let p = dayEntries.reduce(0.0) { $0 + $1.proteinG }
        let c = dayEntries.reduce(0.0) { $0 + $1.carbsG }
        let f = dayEntries.reduce(0.0) { $0 + $1.fatG }
        return HStack(spacing: 12) {
            macroBadge("P", grams: p, color: .blue)
            macroBadge("K", grams: c, color: .orange)
            macroBadge("F", grams: f, color: .purple)
        }
    }

    private func macroBadge(_ letter: String, grams: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(color.gradient, in: Circle())
            Text("\(Int(grams.rounded()))g")
                .font(.caption.weight(.medium))
        }
    }

    private func statRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(Color.appAccent)
                .frame(width: 20)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.semibold))
        }
    }

    // MARK: - Meals

    private func mealCard(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.meal == meal }
        let kcal = entries.reduce(0) { $0 + $1.calories }
        return Card {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: meal.symbol)
                        .foregroundStyle(Color.appAccent)
                    Text(meal.label)
                        .font(.headline)
                    Spacer()
                    if kcal > 0 {
                        Text("\(kcal) kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        addSheetMeal = meal
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                    }
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
}
