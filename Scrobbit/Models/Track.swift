import Foundation
import MusicKit
import SwiftData

/// Unified track model used for both MusicKit tracks and cached Last.fm scrobbles.
/// When used transiently (e.g., from MusicKit), instances don't need to be persisted.
/// When used for history display, instances are persisted to SwiftData.
@Model
final class Track {
    var id: String
    var title: String
    var artistName: String
    var albumTitle: String
    var duration: TimeInterval?
    var artworkURL: URL?
    var url: URL?
    var contentRating: ContentRating?
    var genreNames: [String]?
    var playCount: Int?
    var lastPlayedDate: Date?
    
    /// Timestamp when this track was played/scrobbled.
    /// For MusicKit tracks, this is estimated by working backwards from "now".
    /// For Last.fm scrobbles, this is the actual scrobble timestamp.
    var scrobbledAt: Date?
    
    /// URL to the track's Last.fm page (only set for cached scrobbles).
    var lastFmURL: URL?
    
    /// Unique constraint to prevent duplicate scrobbles in history.
    /// Format: "{artistName}-{trackName}-{timestamp}"
    @Attribute(.unique) var scrobbleID: String?
    
    /// Creates a Track from a MusicKit Song.
    convenience init(from song: Song) {
        self.init(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle ?? "",
            duration: song.duration,
            artworkURL: song.artwork?.url(width: 300, height: 300),
            url: song.url,
            contentRating: song.contentRating,
            genreNames: song.genreNames,
            playCount: song.playCount,
            lastPlayedDate: song.lastPlayedDate
        )
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        url: URL? = nil,
        contentRating: ContentRating? = nil,
        genreNames: [String]? = nil,
        scrobbledAt: Date? = nil,
        playCount: Int? = nil,
        lastFmURL: URL? = nil,
        scrobbleID: String? = nil,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.artworkURL = artworkURL
        self.url = url
        self.contentRating = contentRating
        self.genreNames = genreNames
        self.scrobbledAt = scrobbledAt
        self.playCount = playCount
        self.lastFmURL = lastFmURL
        self.scrobbleID = scrobbleID
        self.lastPlayedDate = lastPlayedDate
    }
    
    /// Generates a unique ID for de-duplication of scrobbles.
    static func generateScrobbleID(artistName: String, trackName: String, timestamp: Date) -> String {
        let timestampInt = Int(timestamp.timeIntervalSince1970)
        return "\(artistName)-\(trackName)-\(timestampInt)"
    }
}
