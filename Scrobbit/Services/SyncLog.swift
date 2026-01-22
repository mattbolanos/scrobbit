import Foundation
import os.log

/// Manages persistent logging of sync executions.
/// Logs are stored in UserDefaults and capped at the most recent 50 entries.
final class SyncLog {
    static let shared = SyncLog()

    private let userDefaultsKey = "com.scrobbit.syncLog"
    private let maxEntries = 50
    private let logger = Logger(subsystem: "com.scrobbit", category: "SyncLog")

    private init() {}

    /// Records a new sync event.
    /// Only persists entries where scrobblesCount > 0 to avoid cluttering the log.
    func record(event: SyncEvent, source: SyncSource, scrobblesCount: Int = 0, message: String? = nil) {
        // Log to system console for debugging (always)
        logger.info("Sync: \(event.rawValue), source: \(source.rawValue), scrobbles: \(scrobblesCount), message: \(message ?? "none")")

        // Only persist entries that actually scrobbled something
        guard scrobblesCount > 0 else { return }

        let entry = SyncLogEntry(
            event: event,
            source: source,
            scrobblesCount: scrobblesCount,
            message: message
        )

        // Persist to UserDefaults
        var entries = fetchEntries()
        entries.insert(entry, at: 0)

        // Cap at maxEntries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save(entries: entries)
    }

    /// Fetches all logged entries, most recent first.
    func fetchEntries() -> [SyncLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SyncLogEntry].self, from: data)
        } catch {
            logger.error("Failed to decode sync log: \(error.localizedDescription)")
            return []
        }
    }

    /// Returns the most recent entry, if any.
    var lastEntry: SyncLogEntry? {
        fetchEntries().first
    }

    /// Clears all log entries.
    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func save(entries: [SyncLogEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            logger.error("Failed to encode sync log: \(error.localizedDescription)")
        }
    }
}
