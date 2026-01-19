import Foundation
import os.log

/// Represents the outcome of a background task execution.
enum BackgroundTaskEvent: String, Codable {
    case completed = "completed"
    case failed = "failed"
    case expired = "expired"
    case skippedNoNetwork = "skipped_no_network"
    case skippedNotAuthenticated = "skipped_not_authenticated"

    var displayText: String {
        switch self {
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .expired: return "Expired"
        case .skippedNoNetwork: return "Skipped (No Network)"
        case .skippedNotAuthenticated: return "Skipped (Not Authenticated)"
        }
    }

    var isSuccess: Bool {
        switch self {
        case .completed, .skippedNoNetwork, .skippedNotAuthenticated:
            return true
        case .failed, .expired:
            return false
        }
    }
}

/// A single log entry for a background task execution.
struct BackgroundTaskLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let event: BackgroundTaskEvent
    let scrobblesCount: Int
    let message: String?

    init(event: BackgroundTaskEvent, scrobblesCount: Int = 0, message: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.scrobblesCount = scrobblesCount
        self.message = message
    }
}

/// Manages persistent logging of background task executions.
/// Logs are stored in UserDefaults and capped at the most recent 50 entries.
final class BackgroundTaskLog {
    static let shared = BackgroundTaskLog()

    private let userDefaultsKey = "com.scrobbit.backgroundTaskLog"
    private let maxEntries = 50
    private let logger = Logger(subsystem: "com.scrobbit", category: "BackgroundTask")

    private init() {}

    /// Records a new background task event.
    func record(event: BackgroundTaskEvent, scrobblesCount: Int = 0, message: String? = nil) {
        let entry = BackgroundTaskLogEntry(
            event: event,
            scrobblesCount: scrobblesCount,
            message: message
        )

        // Log to system console for debugging
        logger.info("Background task: \(event.rawValue), scrobbles: \(scrobblesCount), message: \(message ?? "none")")

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
