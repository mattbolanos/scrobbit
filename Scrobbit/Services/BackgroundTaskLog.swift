import Foundation
import os.log

/// Manages persistent logging of background task executions.
/// Logs are stored in UserDefaults and capped at the most recent 50 entries.
final class BackgroundTaskLog {
    static let shared = BackgroundTaskLog()

    private let userDefaultsKey = "com.scrobbit.backgroundTaskLog"
    private let maxEntries = 50
    private let logger = Logger(subsystem: "com.scrobbit", category: "BackgroundTask")

    private init() {}

    /// Records a new background task event.
    /// Only persists entries where scrobblesCount > 0 to avoid cluttering the log.
    func record(event: BackgroundTaskEvent, scrobblesCount: Int = 0, message: String? = nil) {
        // Log to system console for debugging (always)
        logger.info("Background task: \(event.rawValue), scrobbles: \(scrobblesCount), message: \(message ?? "none")")

        // Only persist entries that actually scrobbled something
        guard scrobblesCount > 0 else { return }

        let entry = BackgroundTaskLogEntry(
            event: event,
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
    func fetchEntries() -> [BackgroundTaskLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([BackgroundTaskLogEntry].self, from: data)
        } catch {
            logger.error("Failed to decode background task log: \(error.localizedDescription)")
            return []
        }
    }

    /// Returns the most recent entry, if any.
    var lastEntry: BackgroundTaskLogEntry? {
        fetchEntries().first
    }

    /// Clears all log entries.
    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func save(entries: [BackgroundTaskLogEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            logger.error("Failed to encode background task log: \(error.localizedDescription)")
        }
    }
}
