import Foundation

/// Source of a sync operation.
enum SyncSource: String, Codable {
    case manual = "manual"
    case background = "background"

    var displayText: String {
        switch self {
        case .manual: return "Manual"
        case .background: return "Background"
        }
    }

    var iconName: String {
        switch self {
        case .manual: return "hand.tap"
        case .background: return "arrow.clockwise"
        }
    }
}

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
    let source: SyncSource
    let scrobblesCount: Int
    let message: String?

    init(event: SyncEvent, source: SyncSource, scrobblesCount: Int = 0, message: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.source = source
        self.scrobblesCount = scrobblesCount
        self.message = message
    }
}
