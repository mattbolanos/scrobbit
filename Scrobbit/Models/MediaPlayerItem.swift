import Foundation

struct MediaPlayerItem: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let playbackDuration: TimeInterval
    let playCount: Int
    let lastPlayedDate: Date?
}
