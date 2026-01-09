import MusicKit
import Foundation
import Observation
import UIKit

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
                return ""
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

