import MusicKit
import Foundation
import Observation
import UIKit

@Observable
final class MusicKitService {

    // MARK: - Properties
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

    // MARK: - Initialization
    init() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    // MARK: - Authorization
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
}
