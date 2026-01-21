import Foundation
import UIKit


protocol DisplayableTrack {
    var displayTitle: String { get }
    var displayArtist: String { get }
    var displayAlbum: String { get }
    var displayDate: Date? { get }
    var displayArtworkURL: URL? { get }
    var displayArtworkImage: UIImage? { get }
}
