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

    private static let connectedKey = "healthKitConnected"

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
            try await store.requestAuthorization(
                toShare: [weightType],
                read: [stepType, energyType, weightType])
            UserDefaults.standard.set(true, forKey: Self.connectedKey)
            isConnected = true
        } catch {
            // User can retry from the diary; read access stays off until granted.
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
