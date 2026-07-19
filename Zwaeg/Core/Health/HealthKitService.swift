import CoreLocation
import Foundation
import HealthKit
import Observation

/// Reads steps and active energy from Apple Health and writes logged weights back.
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// True once the user has gone through the authorization sheet.
    private(set) var isConnected: Bool

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let weightType = HKQuantityType(.bodyMass)
    private let dietaryEnergyType = HKQuantityType(.dietaryEnergyConsumed)
    private let dietaryProteinType = HKQuantityType(.dietaryProtein)
    private let dietaryCarbsType = HKQuantityType(.dietaryCarbohydrates)
    private let dietaryFatType = HKQuantityType(.dietaryFatTotal)

    private var shareTypes: Set<HKSampleType> {
        [weightType, dietaryEnergyType, dietaryProteinType, dietaryCarbsType, dietaryFatType]
    }

    private var readTypes: Set<HKObjectType> {
        [stepType, energyType, weightType, .workoutType(), HKSeriesType.workoutRoute()]
    }

    private static let connectedKey = "healthKitConnected"
    private static let nutritionAuthKey = "healthNutritionAuthRequested"
    private static let routesAuthKey = "healthRoutesAuthRequested"

    private init() {
        isConnected = UserDefaults.standard.bool(forKey: Self.connectedKey)
    }

    /// Forgets the connection (data wipe); the HealthKit permissions
    /// themselves stay managed by iOS.
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.connectedKey)
        isConnected = false
    }

    func requestAuthorization() async {
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            UserDefaults.standard.set(true, forKey: Self.connectedKey)
            UserDefaults.standard.set(true, forKey: Self.nutritionAuthKey)
            UserDefaults.standard.set(true, forKey: Self.routesAuthKey)
            isConnected = true
        } catch {
            // User can retry from the diary; read access stays off until granted.
        }
    }

    /// Users who connected before nutrition writing existed get the extra
    /// permission sheet exactly once, on the first sync attempt.
    private func ensureNutritionAuthorization() async {
        guard !UserDefaults.standard.bool(forKey: Self.nutritionAuthKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.nutritionAuthKey)
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Same pattern for the workout/route read access the routes card needs.
    private func ensureRoutesAuthorization() async {
        guard !UserDefaults.standard.bool(forKey: Self.routesAuthKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.routesAuthKey)
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Outdoor workouts and their routes

    /// Recent walks, runs and hikes; newest first.
    func recentOutdoorWorkouts(limit: Int = 5) async -> [HKWorkout] {
        guard isConnected else { return [] }
        await ensureRoutesAuthorization()
        let activities: [HKWorkoutActivityType] = [.walking, .running, .hiking]
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            activities.map { HKQuery.predicateForWorkouts(with: $0) })
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                      limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    /// The GPS trace a watch or the Workout app recorded for a workout,
    /// downsampled for drawing; empty when the workout has no route.
    func route(for workout: HKWorkout) async -> [CLLocationCoordinate2D] {
        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(),
                                      predicate: predicate, limit: 1,
                                      sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }
        guard let routeSample = routes.first else { return [] }
        return await withCheckedContinuation { continuation in
            var coordinates: [CLLocationCoordinate2D] = []
            var resumed = false
            // The route query streams batches on one queue; done fires last.
            let query = HKWorkoutRouteQuery(route: routeSample) { _, locations, done, error in
                if let locations {
                    coordinates.append(contentsOf: locations.map(\.coordinate))
                }
                guard done || error != nil, !resumed else { return }
                resumed = true
                let step = max(1, coordinates.count / 300)
                continuation.resume(returning: coordinates.enumerated()
                    .compactMap { $0.offset.isMultiple(of: step) ? $0.element : nil })
            }
            store.execute(query)
        }
    }

    struct DayActivity: Equatable {
        var steps: Int = 0
        var activeKcal: Int = 0
    }

    func activity(for day: Date) async -> DayActivity {
        async let steps = sum(of: stepType, unit: .count(), day: day)
        async let energy = sum(of: energyType, unit: .kilocalorie(), day: day)
        return await DayActivity(steps: Int(steps.rounded()), activeKcal: Int(energy.rounded()))
    }

    /// Like activity(for:), but for battles: values typed by hand into the
    /// Health app (wasUserEntered) don't count, so a leaderboard can't be
    /// beaten by editing Health. Device-measured samples are unaffected.
    func battleActivity(for day: Date) async -> DayActivity {
        async let steps = sum(of: stepType, unit: .count(), day: day, excludeUserEntered: true)
        async let energy = sum(of: energyType, unit: .kilocalorie(), day: day, excludeUserEntered: true)
        return await DayActivity(steps: Int(steps.rounded()), activeKcal: Int(energy.rounded()))
    }

    /// Step counts for the seven days ending at `day`, oldest first.
    func weekSteps(endingAt day: Date) async -> [Int] {
        var result: [Int] = []
        for offset in (0..<7).reversed() {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: day) else { continue }
            result.append(Int(await sum(of: stepType, unit: .count(), day: date).rounded()))
        }
        return result
    }

    /// Mirrors a day's eaten totals into Apple Health as one sample per
    /// nutrient spanning the day. Zwäg's earlier samples for that day are
    /// replaced first (deleteObjects only ever removes what this app wrote),
    /// so edits and deletions in the diary stay in sync.
    func saveNutrition(day: Date, kcal: Double, proteinG: Double,
                       carbsG: Double, fatG: Double) async {
        guard isConnected else { return }
        await ensureNutritionAuthorization()
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end,
                                                    options: .strictStartDate)
        let values: [(HKQuantityType, HKUnit, Double)] = [
            (dietaryEnergyType, .kilocalorie(), kcal),
            (dietaryProteinType, .gram(), proteinG),
            (dietaryCarbsType, .gram(), carbsG),
            (dietaryFatType, .gram(), fatG),
        ]
        for (type, unit, value) in values {
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
            guard value > 0 else { continue }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: end)
            try? await store.save(sample)
        }
    }

    func saveWeight(_ weightKg: Double, date: Date = .now) async {
        guard isConnected else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }

    private func sum(of type: HKQuantityType, unit: HKUnit, day: Date,
                     excludeUserEntered: Bool = false) async -> Double {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        var predicates = [HKQuery.predicateForSamples(withStart: start, end: end,
                                                     options: .strictStartDate)]
        if excludeUserEntered {
            // NOT(wasUserEntered == true) also matches samples without the
            // key, which is every device-recorded sample.
            predicates.append(NSCompoundPredicate(notPredicateWithSubpredicate:
                HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered,
                                            operatorType: .equalTo, value: true)))
        }
        let predicate = predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum) { _, statistics, _ in
                    continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
                }
            store.execute(query)
        }
    }
}
