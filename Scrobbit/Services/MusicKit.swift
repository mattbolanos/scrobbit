import MusicKit
import Foundation
import Observation
import UIKit
import MediaPlayer

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

    // MARK: - Fetching recently played songs from Apple Music
    func fetchRecentlyPlayed() async throws -> [Track] {
        guard isAuthorized else {
            throw MusicKitError.notAuthorized
        }
        
        let request = MusicRecentlyPlayedRequest<Song>()
        let response = try await request.response()
        return response.items.compactMap { song -> Track? in
            // Filter out songs without valid identifiers (local files, etc.)
            guard !song.id.rawValue.isEmpty else {
                return nil
            }
            
            return Track(from: song)
        }
    }
    
    // MARK: - MediaPlayer History
    func fetchLastPlayedSongsFromMediaPlayer(limit: Int = 60) async throws -> (
        recentLibrarySongs: [MediaPlayerItem], 
        nonLibrarySongs: [MediaPlayerItem]
    ) {
        guard isAuthorized else {
            throw MusicKitError.notAuthorized
        }
        
        let query = MPMediaQuery.songs()

        let emptyPlayedItems = query.items?.filter { $0.lastPlayedDate == nil }
        
        let nonLibrarySongs = emptyPlayedItems?.compactMap { item -> MediaPlayerItem? in
            return MediaPlayerItem(
                id: String(item.persistentID),
                title: item.title ?? "",
                artistName: item.artist ?? "",
                albumTitle: item.albumTitle ?? "",
                playbackDuration: item.playbackDuration,
                playCount: item.playCount,
                lastPlayedDate: nil
            )
        } ?? []

        let libraryItems = query.items?.filter { $0.lastPlayedDate != nil }
        
        // Sort by last played date (most recent first)
        let sortedLibraryItems = libraryItems?.sorted { item1, item2 in
            guard let date1 = item1.lastPlayedDate, let date2 = item2.lastPlayedDate else {
                return false
            }
            return date1 > date2
        }
        
        let recentLibraryItems = Array(sortedLibraryItems!.prefix(limit))
        
        let recentLibrarySongs = recentLibraryItems.compactMap { item -> MediaPlayerItem? in
            return MediaPlayerItem(
                id: String(item.persistentID),
                title: item.title ?? "",
                artistName: item.artist ?? "",
                albumTitle: item.albumTitle ?? "",
                playbackDuration: item.playbackDuration,
                playCount: item.playCount,
                lastPlayedDate: item.lastPlayedDate
            )
        }
        
        return (recentLibrarySongs: recentLibrarySongs, nonLibrarySongs: nonLibrarySongs)
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
