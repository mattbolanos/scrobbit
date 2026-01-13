import Foundation
import SwiftData
import UIKit

/// Local cache of library songs from MediaPlayer for tracking play history.
/// Uses persistentID and playCount to detect new plays between syncs.
@Model
final class LibraryCache {
    /// MediaPlayer persistent ID - unique and stable across sessions
    @Attribute(.unique) var persistentID: String
    
    /// Track metadata for display and scrobbling
    var title: String
    var artistName: String
    var albumTitle: String
    
    /// Album artwork stored as JPEG data
    @Attribute(.externalStorage) var artworkData: Data?
    
    /// Duration in seconds - used to estimate timestamps for multiple plays
    var playbackDuration: TimeInterval
    
    /// The play count from MediaPlayer when we last synced
    var playCount: Int
    
    /// The last played date from MediaPlayer when we last synced
    var lastPlayedDate: Date?
    
    /// When this entry was last synced (for determining what's new)
    var lastSyncedAt: Date
    
    init(
        persistentID: String,
        title: String,
        artistName: String,
        albumTitle: String,
        artworkData: Data?,
        playbackDuration: TimeInterval,
        playCount: Int,
        lastPlayedDate: Date?,
        lastSyncedAt: Date
    ) {
        self.persistentID = persistentID
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artworkData = artworkData
        self.playbackDuration = playbackDuration
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Creates a LibraryCache entry from a MediaPlayerItem
    convenience init(from item: MediaPlayerItem, syncedAt: Date) {
        self.init(
            persistentID: item.id,
            title: item.title,
            artistName: item.artistName,
            albumTitle: item.albumTitle,
            artworkData: item.artworkImage?.jpegData(compressionQuality: 0.8),
            playbackDuration: item.playbackDuration,
            playCount: item.playCount,
            lastPlayedDate: item.lastPlayedDate,
            lastSyncedAt: syncedAt
        )
    }
    
    /// Updates this cache entry with new data from MediaPlayer
    func update(from item: MediaPlayerItem, syncedAt: Date) {
        self.title = item.title
        self.artistName = item.artistName
        self.albumTitle = item.albumTitle
        self.artworkData = item.artworkImage?.jpegData(compressionQuality: 0.8)
        self.playbackDuration = item.playbackDuration
        self.playCount = item.playCount
        self.lastPlayedDate = item.lastPlayedDate
        self.lastSyncedAt = syncedAt
    }
    
    /// Returns the artwork as a UIImage if available
    var artworkImage: UIImage? {
        guard let data = artworkData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - DisplayableTrack Conformance

extension LibraryCache: DisplayableTrack {
    var displayTitle: String { title }
    var displayArtist: String { artistName }
    var displayAlbum: String { albumTitle }
    var displayDate: Date? { lastPlayedDate }
    var displayArtworkURL: URL? { nil }
    var displayArtworkImage: UIImage? { artworkImage }
}
