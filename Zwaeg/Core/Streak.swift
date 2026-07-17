import Foundation

/// Day streak with freezes: every seventh logged day banks a freeze (at most
/// two at a time) and a missed day automatically spends one, so the streak
/// survives the gap. Spent freezes are persisted as the days they bridged;
/// everything else derives from the logged days, so the accounting can't
/// drift and recomputing is idempotent.
enum Streak {
    static let daysPerFreeze = 7
    static let maxBanked = 2

    private static let frozenDaysKey = "streakFrozenDays"

    /// Days bridged by a freeze, as start-of-day dates.
    static func frozenDays(defaults: UserDefaults = .standard) -> Set<Date> {
        let stamps = defaults.array(forKey: frozenDaysKey) as? [Double] ?? []
        return Set(stamps.map(Date.init(timeIntervalSinceReferenceDate:)))
    }

    /// Freezes in the bank: earned by logged days, minus the spent ones.
    static func availableFreezes(loggedDays: Set<Date>,
                                 defaults: UserDefaults = .standard) -> Int {
        available(loggedDays: loggedDays, frozen: frozenDays(defaults: defaults))
    }

    /// Consecutive days ending today or yesterday. Logged days count, frozen
    /// days keep the chain alive without counting, and fresh gaps are bridged
    /// by spending banked freezes — but only when the bridge reaches a logged
    /// day, so a gap too wide to close wastes nothing. Newly spent (or
    /// refunded, when a frozen day gets backfilled) freezes are persisted.
    static func current(loggedDays: Set<Date>, now: Date = .now,
                        defaults: UserDefaults = .standard) -> Int {
        let calendar = Calendar.current
        var frozen = frozenDays(defaults: defaults)
        var budget = available(loggedDays: loggedDays, frozen: frozen)
        var changed = false
        var count = 0

        var day = calendar.startOfDay(for: now)
        // An unlogged today is still pending, not missed.
        if !loggedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while true {
            if loggedDays.contains(day) {
                count += 1
                if frozen.remove(day) != nil {
                    // The day was frozen but has been backfilled since;
                    // give the freeze back.
                    budget = available(loggedDays: loggedDays, frozen: frozen)
                    changed = true
                }
            } else if frozen.contains(day) {
                // Bridged on an earlier computation; keeps the chain alive.
            } else {
                var gap = [day]
                var probe = day
                var reachable = false
                while gap.count <= budget {
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: probe) else { break }
                    probe = previous
                    if loggedDays.contains(probe) || frozen.contains(probe) {
                        reachable = true
                        break
                    }
                    gap.append(probe)
                }
                guard reachable else { break }
                budget -= gap.count
                frozen.formUnion(gap)
                changed = true
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        if changed {
            defaults.set(frozen.map(\.timeIntervalSinceReferenceDate).sorted(),
                         forKey: frozenDaysKey)
        }
        return count
    }

    private static func available(loggedDays: Set<Date>, frozen: Set<Date>) -> Int {
        max(0, min(maxBanked, loggedDays.count / daysPerFreeze - frozen.count))
    }
}
