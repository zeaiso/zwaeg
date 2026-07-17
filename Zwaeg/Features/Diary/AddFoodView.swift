import SwiftUI
import SwiftData

/// Munch-style add-food page: search, meal filter chips, scan banner and
/// what is already logged in the meal.
/// Manual entry is a fallback for foods that cannot be scanned.
struct AddFoodView: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \CustomFood.createdAt, order: .reverse) private var customFoods: [CustomFood]
    @Query(sort: \CachedProduct.fetchedAt, order: .reverse) private var cachedProducts: [CachedProduct]

    @State private var meal: MealType
    @AppStorage(MealPlan.storageKey) private var enabledMealsRaw = ""
    @State private var query = ""
    @State private var justAdded: String?
    @State private var showManual = false
    @State private var showCustomForm = false
    @State private var pendingProduct: FoodProduct?
    @State private var detailProduct: FoodProduct?

    @State private var manualName = ""
    @State private var manualKcal = ""

    /// Open Food Facts name search, filling in what the offline data lacks.
    @State private var onlineResults: [FoodProduct] = []
    @State private var onlineLoading = false

    init(day: Date, meal: MealType) {
        self.day = day
        _meal = State(initialValue: meal)
    }

    private var searchResults: [FoodProduct] {
        Array(SwissFoodDatabase.shared.search(query).prefix(8))
    }

    /// Own products matching the query; listed before the database results.
    private var customMatches: [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return customFoods
            .filter { $0.name.range(of: trimmed, options: options) != nil }
            .prefix(4)
            .map(\.asProduct)
    }

    /// Previously scanned products; searchable like the database.
    private var cachedMatches: [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return cachedProducts
            .filter { $0.name.range(of: trimmed, options: options) != nil }
            .prefix(4)
            .map(\.asProduct)
    }

    /// Entries already logged for this day and the selected meal.
    private var mealEntries: [FoodEntry] {
        allEntries.filter { $0.day == day && $0.meal == meal }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                searchField
                mealChips
                scanBanner
                copyYesterdayBanner
                loggedSection
                if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                    sectionLabel("ERGEBNISSE".loc)
                    if searchResults.isEmpty, customMatches.isEmpty, cachedMatches.isEmpty,
                       onlineResults.isEmpty, !onlineLoading {
                        Text("Nichts gefunden. Scanne den Barcode oder trage es als eigenes Lebensmittel ein.".loc)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(customMatches + cachedMatches + searchResults) { product in
                        productRow(product, onDelete: customDeleteAction(for: product))
                    }
                    if onlineLoading, onlineResults.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Open Food Facts")
                                .font(.fredoka(12))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    if !onlineResults.isEmpty {
                        sectionLabel("OPEN FOOD FACTS")
                        ForEach(onlineResults) { product in
                            productRow(product)
                        }
                    }
                } else {
                    myFoodsSection
                }
                manualFallback
                customFoodButton
            }
            .padding(20)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detailProduct) { product in
            ProductPortionSheet(product: product, day: day, initialMeal: meal)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCustomForm, onDismiss: {
            if let product = pendingProduct {
                pendingProduct = nil
                detailProduct = product
            }
        }) {
            CustomFoodForm(barcode: nil) { pendingProduct = $0 }
                .presentationDetents([.large])
        }
        .onAppear {
            // Debug: -search <term> prefills the query for screenshots.
            if let flagIndex = LaunchArgs.all.firstIndex(of: "-search"),
               LaunchArgs.all.indices.contains(flagIndex + 1) {
                query = LaunchArgs.all[flagIndex + 1]
            }
        }
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else {
                onlineResults = []
                onlineLoading = false
                return
            }
            onlineLoading = true
            // Debounce: typing cancels this task via task(id:).
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let results = await OpenFoodFactsClient.searchProducts(name: trimmed)
            guard !Task.isCancelled else { return }
            let localIDs = Set((customMatches + cachedMatches + searchResults).map(\.id))
            onlineResults = results.filter { !localIDs.contains($0.id) }
            onlineLoading = false
        }
    }

    // MARK: - Own products (reusable, created via CustomFoodForm)

    @ViewBuilder
    private var myFoodsSection: some View {
        if !customFoods.isEmpty {
            sectionLabel("MEINE LEBENSMITTEL".loc)
            ForEach(customFoods.prefix(4)) { food in
                productRow(food.asProduct, onDelete: { context.delete(food) })
            }
        }
    }

    /// Deleting stays possible when an own product surfaces in the search.
    private func customDeleteAction(for product: FoodProduct) -> (() -> Void)? {
        guard product.source == .custom,
              let food = customFoods.first(where: { product.id == "custom-\($0.uid)" }) else {
            return nil
        }
        return { context.delete(food) }
    }

    private var customFoodButton: some View {
        Button {
            showCustomForm = true
        } label: {
            Text("Eigenes Produkt erstellen".loc)
                .font(.fredoka(13, .medium))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header & search

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.05), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            Text("Essen hinzufügen".loc)
                .font(.fredoka(22, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if !mealEntries.isEmpty {
                Text("\(mealEntries.count)")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.gradient, in: Circle())
                    .contentTransition(.numericText())
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Was hast du gegessen?".loc, text: $query)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    /// Enabled meals, plus the preselected one if it is disabled but was
    /// opened from a meal card that still holds entries.
    private var selectableMeals: [MealType] {
        let enabled = MealPlan.enabled(from: enabledMealsRaw)
        return MealType.allCases.filter { enabled.contains($0) || $0 == meal }
    }

    private var mealChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectableMeals) { type in
                    Button {
                        withAnimation(.snappy) { meal = type }
                    } label: {
                        Text(type.label)
                            .font(.fredoka(15, .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(meal == type ? Theme.ink : Theme.card, in: Capsule())
                            .foregroundStyle(meal == type ? Theme.onInk : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Scan banner

    private var scanBanner: some View {
        Button {
            dismiss()
            TabRouter.shared.selection = 2
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.fredoka(19, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanne dein Essen".loc)
                        .font(.fredoka(17, .semibold))
                    Text("Barcode scannen, in Sekunden geloggt".loc)
                        .font(.fredoka(12))
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.fredoka(15, .semibold))
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(
                LinearGradient(colors: [Theme.accentLight, Theme.accent],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Copy yesterday (one tap repeats the same meal from the day before)

    private var yesterdayEntries: [FoodEntry] {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) else { return [] }
        return allEntries.filter { $0.day == yesterday && $0.meal == meal }
    }

    @ViewBuilder
    private var copyYesterdayBanner: some View {
        if mealEntries.isEmpty, !yesterdayEntries.isEmpty {
            let kcal = yesterdayEntries.reduce(0) { $0 + $1.calories }
            Button {
                copyFromYesterday()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wie gestern".loc)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text((yesterdayEntries.count == 1
                                ? "%d Eintrag · %d kcal übernehmen"
                                : "%d Einträge · %d kcal übernehmen").loc(yesterdayEntries.count, kcal))
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 32, height: 32)
                        .background(Theme.accentSoft, in: Circle())
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyFromYesterday() {
        withAnimation(.snappy) {
            for entry in yesterdayEntries {
                context.insert(FoodEntry(day: day, meal: meal, name: entry.name,
                                         calories: entry.calories, proteinG: entry.proteinG,
                                         carbsG: entry.carbsG, fatG: entry.fatG,
                                         sugarG: entry.sugarG, saltG: entry.saltG,
                                         fiberG: entry.fiberG))
            }
        }
    }

    // MARK: - Already logged in this meal

    @ViewBuilder
    private var loggedSection: some View {
        if !mealEntries.isEmpty {
            let total = mealEntries.reduce(0) { $0 + $1.calories }
            sectionLabel("IN %@ · %d KCAL".loc(meal.label.uppercased(), total))
            ForEach(mealEntries) { entry in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(thumbColor(for: entry.name))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(entry.calories) kcal")
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy) { context.delete(entry) }
                    } label: {
                        Image(systemName: "minus")
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Theme.field, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
            }
        }
    }

    // MARK: - Rows

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.fredoka(12, .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private static let thumbColors: [Color] = [
        Color(red: 0.99, green: 0.87, blue: 0.6),
        Color(red: 0.78, green: 0.92, blue: 0.66),
        Color(red: 1.0, green: 0.8, blue: 0.79),
        Color(red: 0.75, green: 0.87, blue: 0.99),
        Color(red: 0.93, green: 0.83, blue: 0.99),
    ]

    private func thumbColor(for name: String) -> Color {
        var hash: UInt64 = 5381
        for byte in name.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Self.thumbColors[Int(hash % UInt64(Self.thumbColors.count))]
    }

    private func foodRow(name: String, subtitle: String, added: Bool,
                         onDelete: (() -> Void)? = nil,
                         onOpen: @escaping () -> Void, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(thumbColor(for: name))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.fredoka(15, .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.fredoka(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            if let onDelete {
                Button {
                    withAnimation(.snappy) { onDelete() }
                } label: {
                    Image(systemName: "trash")
                        .font(.fredoka(13, .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.field.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Button(action: action) {
                Image(systemName: added ? "checkmark" : "plus")
                    .font(.fredoka(15, .semibold))
                    .foregroundStyle(added ? Theme.onAccent : Color.appAccent)
                    .frame(width: 32, height: 32)
                    .background(added ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accentSoft),
                                in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
    }

    private func productRow(_ product: FoodProduct, onDelete: (() -> Void)? = nil) -> some View {
        foodRow(name: product.name,
                subtitle: "100 g · \(Int(product.kcalPer100g.rounded())) kcal",
                added: justAdded == product.id
                    || mealEntries.contains { $0.name == product.displayName },
                onDelete: onDelete,
                onOpen: {
                    // Online results become part of the offline cache the
                    // moment they get attention, like scanned barcodes.
                    if product.source == .openFoodFacts, let code = product.barcode,
                       !cachedProducts.contains(where: { $0.barcode == code }) {
                        context.insert(CachedProduct(product: product, barcode: code))
                    }
                    detailProduct = product
                }) {
            add(name: product.displayName,
                calories: product.kcal(for: 100),
                protein: product.protein(for: 100),
                carbs: product.carbs(for: 100),
                fat: product.fat(for: 100),
                flashID: product.id)
        }
    }

    // MARK: - Manual entry (fallback when scanning is not possible)

    @ViewBuilder
    private var manualFallback: some View {
        if showManual {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("EIGENES LEBENSMITTEL".loc)
                VStack(spacing: 10) {
                    TextField("Name (z.B. Zopf mit Butter)".loc, text: $manualName)
                        .padding(12)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 10) {
                        TextField("Kalorien".loc, text: $manualKcal)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            addManual()
                        } label: {
                            Text("Hinzufügen".loc)
                                .font(.fredoka(15, .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(Theme.onAccent)
                        }
                        .buttonStyle(.plain)
                        .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty || Int(manualKcal) == nil)
                        .opacity(manualName.trimmingCharacters(in: .whitespaces).isEmpty || Int(manualKcal) == nil ? 0.5 : 1)
                    }
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.shadow.opacity(0.04), radius: 6, y: 2)
            }
        } else {
            Button {
                withAnimation(.snappy) { showManual = true }
            } label: {
                Text("Nicht scannbar? Eigenes Lebensmittel eintragen".loc)
                    .font(.fredoka(13, .medium))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Saving

    private func add(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, flashID: String) {
        let entry = FoodEntry(day: day, meal: meal, name: name, calories: calories,
                              proteinG: protein, carbsG: carbs, fatG: fat)
        context.insert(entry)
        withAnimation(.snappy) { justAdded = flashID }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { justAdded = nil }
        }
    }

    private func addManual() {
        guard let kcal = Int(manualKcal) else { return }
        add(name: manualName.trimmingCharacters(in: .whitespaces),
            calories: kcal, protein: 0, carbs: 0, fat: 0, flashID: "manual")
        manualName = ""
        manualKcal = ""
        withAnimation { showManual = false }
    }
}
