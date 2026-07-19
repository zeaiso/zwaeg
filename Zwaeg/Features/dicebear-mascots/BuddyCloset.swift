import Foundation

/// The wardrobe closet: saved looks the user can switch between,
/// like Habbo's outfit slots. Stored as JSON in UserDefaults.
enum BuddyCloset {
    private static let key = "savedBuddies"
    static let capacity = 24

    static func load() -> [Buddy] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let buddies = try? JSONDecoder().decode([Buddy].self, from: data) else {
            return []
        }
        return buddies
    }

    static func contains(_ buddy: Buddy) -> Bool {
        load().contains(buddy)
    }

    static func add(_ buddy: Buddy) {
        var buddies = load()
        guard !buddies.contains(buddy) else { return }
        buddies.insert(buddy, at: 0)
        if buddies.count > capacity {
            buddies = Array(buddies.prefix(capacity))
        }
        persist(buddies)
    }

    static func remove(_ buddy: Buddy, keepingFileOf current: Buddy?) {
        var buddies = load()
        buddies.removeAll { $0 == buddy }
        persist(buddies)
        // Clean up the cached image unless the look is still being worn.
        if ["custom", "styled", "photo"].contains(buddy.kind), buddy != current,
           let path = buddy.customImagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// Deletes cached buddy images that no saved or worn look references
    /// anymore: renders orphaned by studio re-saves, looks trimmed by the
    /// capacity cap, and stale transparent heads. Runs once per launch.
    static func sweepOrphanedFiles(worn: Buddy) {
        let manager = FileManager.default
        guard let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? manager.contentsOfDirectory(atPath: documents.path) else { return }
        var referenced = Set<String>()
        for buddy in load() + [worn] {
            if let file = buddy.file {
                referenced.insert(file)
            }
        }
        for file in files
        where (file.hasPrefix("custom-buddy-") || file.hasPrefix("photo-")
               || file.hasPrefix("buddy-head-")) && !referenced.contains(file) {
            try? manager.removeItem(at: documents.appendingPathComponent(file))
        }
    }

    private static func persist(_ buddies: [Buddy]) {
        guard let data = try? JSONEncoder().encode(buddies) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
