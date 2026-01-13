import Foundation
import UIKit

/// Protocol for tracks that can be displayed in the RecentlyPlayedSection.
/// Allows both LibraryCache and LastFmScrobble to be rendered uniformly.
protocol DisplayableTrack {
    var displayTitle: String { get }
    var displayArtist: String { get }
    var displayAlbum: String { get }
    var displayDate: Date? { get }
    var displayArtworkURL: URL? { get }
    var displayArtworkImage: UIImage? { get }
}
