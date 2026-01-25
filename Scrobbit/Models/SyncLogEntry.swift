import Foundation

/// Represents the outcome of a sync execution.
enum SyncEvent: String, Codable {
    case completed = "completed"
    case failed = "failed"

    var displayText: String {
        switch self {
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var isSuccess: Bool {
        self == .completed
    }
}

/// A single log entry for a sync execution.
struct SyncLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let event: SyncEvent
    let scrobblesCount: Int
    let message: String?

    init(event: SyncEvent, scrobblesCount: Int = 0, message: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.scrobblesCount = scrobblesCount
        self.message = message
    }
}
