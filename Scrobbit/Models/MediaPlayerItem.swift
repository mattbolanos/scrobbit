import Foundation
import UIKit
import MediaPlayer

struct MediaPlayerItem: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let artworkImage: UIImage?
    let playbackDuration: TimeInterval
    let playCount: Int
    let lastPlayedDate: Date?
    
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
        // Extract UIImage from MPMediaItemArtwork at a reasonable size
        self.artworkImage = artwork?.image(at: CGSize(width: 300, height: 300))
        self.playbackDuration = playbackDuration
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
    }
}
