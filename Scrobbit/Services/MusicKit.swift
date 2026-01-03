import MusicKit
import Foundation
import Observation
import UIKit

// MARK: - Track Model
struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval?
    let lastPlayedDate: Date?
    let artworkURL: URL?
    let url: URL?
    let contentRating: MusicKit.ContentRating?
    let genreNames: [String]?
    
    init(from song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle ?? ""
        self.duration = song.duration
        self.lastPlayedDate = song.lastPlayedDate
        self.artworkURL = song.artwork?.url(width: 300, height: 300)
        self.url = song.url
        self.contentRating = song.contentRating
        self.genreNames = song.genreNames
    }
    
    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: TimeInterval? = nil,
        lastPlayedDate: Date? = nil,
        artworkURL: URL? = nil,
        url: URL? = nil,
        contentRating: MusicKit.ContentRating? = nil,
        genreNames: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.lastPlayedDate = lastPlayedDate
        self.artworkURL = artworkURL
        self.url = url
        self.contentRating = contentRating
        self.genreNames = genreNames
    }
}

@Observable
final class MusicKitService {

    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var isAuthorizing: Bool = false

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isDenied: Bool {
        authorizationStatus == .denied
    }

    var statusDescription: String {
        switch authorizationStatus {
            case .notDetermined:
                return "Tap to connect"
            case .denied:
                return "Allow in Settings"
            case .restricted:
                return "Access restricted"
            case .authorized:
                return "Connected"
            @unknown default:
                return "Unknown status"
        }
    }

    init() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    @MainActor
    func requestAuthorization() async {
        guard !isAuthorizing else { return }

        isAuthorizing = true
        defer { isAuthorizing = false }

        if isDenied {
            openSettings()
        } else {
            let status = await MusicAuthorization.request()
            authorizationStatus = status
        }
    }

    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    @MainActor
    func refreshStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    func disconnect() {
        openSettings()
    }

    // MARK: - Fetching
    func fetchRecentlyPlayed() async throws -> [Track] {
        guard isAuthorized else {
            throw MusicKitError.notAuthorized
        }
        
        let request = MusicRecentlyPlayedRequest<MusicKit.Track>()
        let response = try await request.response()

        return response.items.compactMap { item -> Track? in
            guard case .song(let song) = item else { return nil }
            return Track(from: song)
        }

    }
}

enum MusicKitError: LocalizedError {
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Apple Music access not authorized"
        }
    }
}

