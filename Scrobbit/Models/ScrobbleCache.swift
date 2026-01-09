import Foundation
import SwiftData

/// Local cache of recently scrobbled tracks for de-duplication.
/// Uses Apple Music track IDs and play counts for precise matching.
@Model
final class ScrobbleCache {
    /// Apple Music track ID - stable and unique
    var appleMusicID: String
    
    /// The estimated timestamp we used when scrobbling
    var estimatedTimestamp: Date
    
    /// When this entry was created (for pruning old entries)
    var createdAt: Date
    
    /// The play count from MusicKit when we last scrobbled this track.
    /// Used to detect legitimate replays (playCount increased = new play).
    var lastKnownPlayCount: Int?
    
    /// Unique key for de-duplication: "{appleMusicID}-{timestamp_unix}"
    @Attribute(.unique) var cacheKey: String
    
    init(appleMusicID: String, estimatedTimestamp: Date, playCount: Int? = nil) {
        self.appleMusicID = appleMusicID
        self.estimatedTimestamp = estimatedTimestamp
        self.createdAt = Date()
        self.lastKnownPlayCount = playCount
        self.cacheKey = ScrobbleCache.generateKey(
            appleMusicID: appleMusicID,
            timestamp: estimatedTimestamp
        )
    }
    
    /// Generates a unique cache key for de-duplication.
    static func generateKey(appleMusicID: String, timestamp: Date) -> String {
        let timestampUnix = Int(timestamp.timeIntervalSince1970)
        return "\(appleMusicID)-\(timestampUnix)"
    }
}
