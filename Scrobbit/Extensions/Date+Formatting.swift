import Foundation

extension Date {
    /// Returns a human-readable relative time string (e.g., "5 mins ago", "2 hours ago")
    /// Falls back to "MMM dd HH:mm" format for dates older than 24 hours
    var relativeTimeString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)

        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) \(minutes == 1 ? "min" : "mins") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd HH:mm"
            return formatter.string(from: self)
        }
    }
}
