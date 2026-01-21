import Foundation

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
