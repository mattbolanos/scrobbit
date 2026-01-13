import Foundation

/// Represents a scrobble that is pending to be sent to Last.fm.
/// Used for UI display before the scrobble is confirmed.
struct PendingScrobble: Identifiable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String
    let scrobbleAt: Date  // Estimated timestamp for this play
    
    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumTitle: String,
        scrobbleAt: Date
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.scrobbleAt = scrobbleAt
    }
}
