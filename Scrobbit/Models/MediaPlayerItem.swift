import Foundation
import UIKit
import MediaPlayer

struct MediaPlayerItem: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let playbackDuration: TimeInterval
    let playCount: Int
    let lastPlayedDate: Date?

    /// Store artwork reference for lazy extraction (avoids blocking during scan)
    private let artwork: MPMediaItemArtwork?

    /// Lazily extracts UIImage from MPMediaItemArtwork when needed
    var artworkImage: UIImage? {
        artwork?.image(at: CGSize(width: 300, height: 300))
    }

    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        artwork: MPMediaItemArtwork?,
        playbackDuration: TimeInterval,
        playCount: Int,
        lastPlayedDate: Date?
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artwork = artwork
        self.playbackDuration = playbackDuration
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
    }
}
