import SwiftUI
import SwiftData
import Charts
import PhotosUI
import MapKit
import HealthKit

/// Munch-style activity screen: colored stat tiles, rounded calorie bars,
/// clean weight line.
struct ProgressScreen: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodEntries: [FoodEntry]
    @Query private var waterDays: [WaterDay]

    @State private var range: RangeOption = .week

    enum RangeOption: String, CaseIterable, Identifiable {
        case week
        case month
        case threeMonths
        case all

        var id: String { rawValue }

        var label: String {
            switch self {
            case .week: return "Letzte 7 Tage".loc
            case .month: return "Letzter Monat".loc
            case .threeMonths: return "Letzte 3 Monate".loc
            case .all: return "Alles".loc
            }
        }

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .all: return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statTiles
                caloriesCard
                weekCard
                weightCard
                routesCard
                photosCard
            }
            .padding(16)
        }
        .defaultScrollAnchor(LaunchArgs.all.contains("-scroll-bottom") ? .bottom : .top)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadRoutes() }
    }

    // MARK: - Header

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
            VStack(alignment: .leading, spacing: 1) {
                Text("Meine Aktivität".loc)
                    .font(.fredoka(22, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Diese Woche".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Routes (from Apple Health workouts; nothing tracked by Zwäg)

    struct RouteWorkout: Identifiable {
        let id: UUID
        let label: String
        let date: Date
        let distanceKm: Double
        let minutes: Int
        let coordinates: [CLLocationCoordinate2D]
    }

    @State private var routes: [RouteWorkout] = []
    @State private var selectedRoute: RouteWorkout?

    private var routesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meine Routen".loc)
                .font(.fredoka(16, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Spaziergänge und Läufe aus Apple Health — nur auf deinem Gerät.".loc)
                .font(.fredoka(12))
                .foregroundStyle(.secondary)
            if routes.isEmpty {
                Text("Zeichne einen Spaziergang oder Lauf mit der Apple Watch oder der Workout-App auf — die Route erscheint dann hier.".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(routes) { route in
                            routeTile(route)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.05), radius: 8, y: 3)
        .sheet(item: $selectedRoute) { route in
            routeDetail(route)
                .presentationDetents([.large])
        }
    }

    private func routeTile(_ route: RouteWorkout) -> some View {
        Button {
            selectedRoute = route
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                routeMap(route, interactive: false)
                    .frame(width: 210, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .allowsHitTesting(false)
                Text(route.label)
                    .font(.fredoka(13, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("%@ km · %d Min.".loc(
                    route.distanceKm.formatted(.number.precision(.fractionLength(0...1))),
                    route.minutes)
                    + " · " + route.date.formatted(.dateTime.day().month()
                        .locale(Lingo.shared.language.locale)))
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func routeDetail(_ route: RouteWorkout) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Capsule()
                    .fill(Theme.field)
                    .frame(width: 44, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                Text(route.label)
                    .font(.fredoka(22, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("%@ km · %d Min.".loc(
                    route.distanceKm.formatted(.number.precision(.fractionLength(0...1))),
                    route.minutes)
                    + " · " + route.date.formatted(.dateTime.weekday(.wide).day().month()
                        .locale(Lingo.shared.language.locale)))
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            routeMap(route, interactive: true)
        }
        .background(Theme.background)
    }

    private func routeMap(_ route: RouteWorkout, interactive: Bool) -> some View {
        Map(initialPosition: .region(Self.region(fitting: route.coordinates)),
            interactionModes: interactive ? .all : []) {
            MapPolyline(coordinates: route.coordinates)
                .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }

    private static func region(fitting coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: .init(latitude: 47.37, longitude: 8.54),
                                      span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        return MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max(0.004, (maxLat - minLat) * 1.4),
                        longitudeDelta: max(0.004, (maxLon - minLon) * 1.4)))
    }

    private func loadRoutes() async {
        // Demo fixture: the simulator's Health store has no workouts.
        if LaunchArgs.all.contains("-demo-routes") {
            routes = Self.demoRoutes()
            if LaunchArgs.all.contains("-open-route") {
                selectedRoute = routes.first
            }
            return
        }
        guard HealthKitService.shared.isConnected else { return }
        var loaded: [RouteWorkout] = []
        for workout in await HealthKitService.shared.recentOutdoorWorkouts() {
            let coordinates = await HealthKitService.shared.route(for: workout)
            guard coordinates.count > 1 else { continue }
            let label: String
            switch workout.workoutActivityType {
            case .running: label = "Lauf".loc
            case .hiking: label = "Wanderung".loc
            default: label = "Spaziergang".loc
            }
            let kilometers = (workout.statistics(for: .init(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0) / 1000
            loaded.append(RouteWorkout(
                id: workout.uuid,
                label: label,
                date: workout.startDate,
                distanceKm: kilometers,
                minutes: Int(workout.duration / 60),
                coordinates: coordinates))
        }
        routes = loaded
    }

    /// A believable lakeside loop in Zürich for screenshots.
    private static func demoRoutes() -> [RouteWorkout] {
        let base = CLLocationCoordinate2D(latitude: 47.3546, longitude: 8.5512)
        let loop = (0..<60).map { index -> CLLocationCoordinate2D in
            let angle = Double(index) / 60 * 2 * .pi
            return CLLocationCoordinate2D(
                latitude: base.latitude + 0.008 * sin(angle) + 0.003 * sin(angle * 3),
                longitude: base.longitude + 0.011 * cos(angle))
        }
        let out = (0..<40).map { index -> CLLocationCoordinate2D in
            CLLocationCoordinate2D(latitude: base.latitude + 0.02 + Double(index) * 0.0006,
                                   longitude: base.longitude + 0.01 + Double(index) * 0.0003)
        }
        return [
            RouteWorkout(id: UUID(), label: "Lauf", date: .now.addingTimeInterval(-7_200),
                         distanceKm: 5.4, minutes: 32, coordinates: loop),
            RouteWorkout(id: UUID(), label: "Spaziergang", date: .now.addingTimeInterval(-90_000),
                         distanceKm: 2.8, minutes: 41, coordinates: out),
        ]
    }

    // MARK: - Progress photos

    private var lostKg: Double {
        guard let first = weights.first?.weightKg, let last = weights.last?.weightKg else { return 0 }
        return first - last
    }

    @State private var photos = ProgressPhotos.all()
    @State private var pickedItem: PhotosPickerItem?

    /// The newest photo has fallen behind the weekly rhythm.
    private var photoDue: Bool {
        guard let newest = photos.last else { return false }
        return Date.now.timeIntervalSince(newest.date) > 6.5 * 86_400
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fortschrittsfotos".loc)
                    .font(.fredoka(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if photoDue {
                    Text("Zeit für ein neues Foto!".loc)
                        .font(.fredoka(11, .semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }
            if let first = photos.first {
                HStack(alignment: .center, spacing: 14) {
                    comparisonPhoto(first)
                    if photos.count > 1, let newest = photos.last {
                        Image(systemName: "arrow.forward")
                            .font(.fredoka(16, .semibold))
                            .foregroundStyle(.secondary)
                        comparisonPhoto(newest)
                    }
                }
                .frame(maxWidth: .infinity)
                if lostKg >= 0.3 {
                    Text("Schon %@ kg leichter!".loc(lostKg.formatted(.number.precision(.fractionLength(0...1)))))
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                if photos.count > 2 {
                    photoStrip
                }
            } else {
                Text("Mach jede Woche ein Foto von dir und sieh den Unterschied. Die Fotos bleiben nur auf deinem iPhone.".loc)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Foto hinzufügen".loc, systemImage: "camera.fill")
                    .font(.fredoka(14, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.accent.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.05), radius: 8, y: 3)
        .onChange(of: pickedItem) {
            guard let item = pickedItem else { return }
            pickedItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                ProgressPhotos.add(image)
                withAnimation(.snappy) { photos = ProgressPhotos.all() }
            }
        }
    }

    private func comparisonPhoto(_ photo: ProgressPhotos.Photo) -> some View {
        VStack(spacing: 6) {
            photoImage(photo)
                .frame(width: 132, height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    deleteButton(photo, diameter: 24)
                        .padding(5)
                }
            Text(photoCaption(photo))
                .font(.fredoka(11, .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func deleteButton(_ photo: ProgressPhotos.Photo, diameter: CGFloat) -> some View {
        Button {
            ProgressPhotos.delete(photo)
            withAnimation(.snappy) { photos = ProgressPhotos.all() }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: diameter * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(.black.opacity(0.55), in: Circle())
        }
        .buttonStyle(.plain)
    }

    /// All photos as small thumbnails, each with its own delete button.
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    VStack(spacing: 4) {
                        photoImage(photo)
                            .frame(width: 56, height: 74)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                deleteButton(photo, diameter: 18)
                                    .padding(3)
                            }
                        Text(photo.date.formatted(.dateTime.day().month()))
                            .font(.fredoka(10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoImage(_ photo: ProgressPhotos.Photo) -> some View {
        if let image = UIImage(contentsOfFile: photo.url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Theme.field
        }
    }

    /// Date plus the logged weight closest to it, when one is near enough.
    private func photoCaption(_ photo: ProgressPhotos.Photo) -> String {
        let date = photo.date.formatted(.dateTime.day().month())
        guard let nearest = weights.min(by: {
            abs($0.date.timeIntervalSince(photo.date)) < abs($1.date.timeIntervalSince(photo.date))
        }), abs(nearest.date.timeIntervalSince(photo.date)) < 3 * 86_400 else { return date }
        return "\(date) · \(nearest.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    // MARK: - Stat tiles

    private struct DayCalories: Identifiable {
        let id: Date
        let day: Date
        let kcal: Int
    }

    private var last7Days: [DayCalories] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let kcal = foodEntries.filter { $0.day == day }.reduce(0) { $0 + $1.calories }
            return DayCalories(id: day, day: day, kcal: kcal)
        }
    }

    private var weeklyAverage: Int {
        let logged = last7Days.filter { $0.kcal > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.kcal } / logged.count
    }

    private var monthWeightDelta: Double? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) else { return nil }
        let window = weights.filter { $0.date >= cutoff }
        guard let first = window.first, let last = window.last, window.count >= 2 else { return nil }
        return last.weightKg - first.weightKg
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            statTile(value: "\(weeklyAverage)",
                     label: "kcal Ø / Tag".loc,
                     background: AnyShapeStyle(LinearGradient(
                        colors: [Theme.accentLight, Theme.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
            statTile(value: monthWeightDelta.map { String(format: "%+.1f", $0) } ?? "–",
                     label: "kg diesen Monat".loc,
                     background: AnyShapeStyle(Theme.ink), foreground: Theme.onInk)
        }
    }

    private func statTile(value: String, label: String, background: AnyShapeStyle,
                          foreground: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.fredoka(27, .semibold))
                .foregroundStyle(foreground)
                .contentTransition(.numericText())
            Text(label)
                .font(.fredoka(12, .semibold))
                .foregroundStyle(foreground.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.10), radius: 10, y: 4)
    }

    // MARK: - Calories (rounded bars)

    private var caloriesCard: some View {
        let days = last7Days
        let target = max(1, profile.dailyCalorieTarget)
        let maxValue = max(days.map(\.kcal).max() ?? 0, target)
        let today = Calendar.current.startOfDay(for: .now)

        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Kalorien".loc)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("Ziel %@".loc(profile.dailyCalorieTarget.formatted()))
                        .font(.fredoka(12, .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(days) { item in
                        let isToday = item.day == today
                        let fraction = max(0.08, Double(item.kcal) / Double(maxValue))
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                VStack(spacing: 6) {
                                    Spacer(minLength: 0)
                                    if isToday && item.kcal > 0 {
                                        Text("\(Int((Double(item.kcal) / Double(target) * 100).rounded()))%")
                                            .font(.fredoka(10, .semibold))
                                            .foregroundStyle(Theme.onInk)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.ink, in: Capsule())
                                            .fixedSize()
                                            .frame(maxWidth: .infinity)
                                    }
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isToday
                                              ? AnyShapeStyle(LinearGradient(
                                                    colors: [Theme.accentLight, Theme.accent],
                                                    startPoint: .top, endPoint: .bottom))
                                              : AnyShapeStyle(Theme.accentSoft))
                                        .frame(height: max(16, geo.size.height * fraction))
                                }
                            }
                            Text(item.day.formatted(.dateTime.weekday(.narrow)))
                                .font(.fredoka(12, .semibold))
                                .foregroundStyle(isToday ? Color.appAccent : .secondary)
                        }
                    }
                }
                .frame(height: 170)
            }
        }
    }

    // MARK: - Week balance

    private var weekCard: some View {
        let days = last7Days
        let logged = days.filter { $0.kcal > 0 }
        let target = max(1, profile.dailyCalorieTarget)
        let onTarget = logged.filter { $0.kcal <= target }.count
        let balance = logged.reduce(0) { $0 + $1.kcal - target }
        let weekGlasses = days.reduce(0) { sum, item in
            sum + (waterDays.first { $0.day == item.day }?.glasses ?? 0)
        }
        let weekProtein = foodEntries
            .filter { entry in days.contains { $0.day == entry.day } }
            .reduce(0.0) { $0 + $1.proteinG }

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wochenbilanz".loc)
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                weekRow("Tage im Ziel".loc,
                        logged.isEmpty ? "–" : "\(onTarget)/\(logged.count)")
                Divider()
                weekRow("Bilanz".loc,
                        logged.isEmpty ? "–" : String(format: "%+d kcal", balance),
                        highlight: balance > 0 && !logged.isEmpty)
                Divider()
                weekRow("Wasser Ø / Tag".loc,
                        String(format: "%.2f l", Double(weekGlasses) * 0.25 / 7))
                Divider()
                weekRow("Protein Ø / Tag".loc,
                        logged.isEmpty ? "–" : String(format: "%.0f g", weekProtein / Double(logged.count)))
            }
        }
    }

    private func weekRow(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.fredoka(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.fredoka(15, .semibold))
                .foregroundStyle(highlight ? Color.appAccent : Theme.ink)
        }
    }

    // MARK: - Weight journey (clean line)

    private var filteredWeights: [WeightEntry] {
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else {
            return weights
        }
        return weights.filter { $0.date >= cutoff }
    }

    private var weightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Gewichtsverlauf".loc)
                        .font(.fredoka(17, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Menu {
                        ForEach(RangeOption.allCases) { option in
                            Button(option.label) {
                                withAnimation(.snappy) { range = option }
                            }
                        }
                    } label: {
                        Text(range.label)
                            .font(.fredoka(12, .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }

                if filteredWeights.count < 2 {
                    Text("Trage regelmässig dein Gewicht im Profil ein, um den Verlauf zu sehen.".loc)
                        .font(.fredoka(13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    weightChart
                }
            }
        }
    }

    private var weightChart: some View {
        let values = filteredWeights.map(\.weightKg)
        let minY = (values.min() ?? 0) - 1
        let maxY = (values.max() ?? 100) + 1
        return Chart {
            ForEach(filteredWeights) { entry in
                LineMark(
                    x: .value("Datum", entry.date),
                    y: .value("Gewicht", entry.weightKg))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = filteredWeights.last {
                PointMark(
                    x: .value("Datum", last.date),
                    y: .value("Gewicht", last.weightKg))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(140)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: minY...maxY)
        .frame(height: 110)
    }
}
