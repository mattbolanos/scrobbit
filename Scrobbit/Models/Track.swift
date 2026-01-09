import Foundation
import MusicKit

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval?
    let artworkURL: URL?
    let url: URL?
    let contentRating: MusicKit.ContentRating?
    let genreNames: [String]?
    let playCount: Int?
    
    /// Estimated timestamp when this track was played.
    /// Assigned during sync by working backwards from "now" using track durations.
    var estimatedPlayTime: Date?
    
    init(from song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle ?? ""
        self.duration = song.duration
        self.artworkURL = song.artwork?.url(width: 300, height: 300)
        self.url = song.url
        self.contentRating = song.contentRating
        self.genreNames = song.genreNames
        self.estimatedPlayTime = nil
        self.playCount = song.playCount
    }
    
    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        url: URL? = nil,
        contentRating: MusicKit.ContentRating? = nil,
        genreNames: [String]? = nil,
        estimatedPlayTime: Date? = nil,
        playCount: Int? = nil
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
        self.estimatedPlayTime = estimatedPlayTime
        self.playCount = playCount
    }
}
