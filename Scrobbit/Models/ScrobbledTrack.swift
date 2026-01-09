import Foundation
import SwiftData

/// Cached scrobble from Last.fm for offline display in History view.
@Model
final class ScrobbledTrack {
    var trackName: String
    var artistName: String
    var albumName: String
    var scrobbledAt: Date
    var artworkURL: URL?
    var lastFmURL: URL?
    
    /// Unique constraint to prevent duplicates.
    /// Format: "{artistName}-{trackName}-{timestamp}"
    @Attribute(.unique) var scrobbleID: String
    
    init(
        trackName: String,
        artistName: String,
        albumName: String,
        scrobbledAt: Date,
        artworkURL: URL? = nil,
        lastFmURL: URL? = nil
    ) {
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.scrobbledAt = scrobbledAt
        self.artworkURL = artworkURL
        self.lastFmURL = lastFmURL
        self.scrobbleID = ScrobbledTrack.generateID(
            artistName: artistName,
            trackName: trackName,
            timestamp: scrobbledAt
        )
    }
    
    /// Generates a unique ID for de-duplication.
    static func generateID(artistName: String, trackName: String, timestamp: Date) -> String {
        let timestampInt = Int(timestamp.timeIntervalSince1970)
        return "\(artistName)-\(trackName)-\(timestampInt)"
    }
}
