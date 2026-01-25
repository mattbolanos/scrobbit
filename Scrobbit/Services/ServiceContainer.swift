import Foundation
import SwiftData

/// A container for services that lazily initializes on first access.
/// This ensures services are always available, whether the app is launched
/// in foreground or woken for a background task.
@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    // MARK: - Model Container

    private var _modelContainer: ModelContainer?

    var modelContainer: ModelContainer {
        if _modelContainer == nil {
            do {
                _modelContainer = try ModelContainer(for: Track.self, LibraryCache.self)
            } catch {
                fatalError("Failed to initialize SwiftData model container: \(error)")
            }
        }
        return _modelContainer!
    }

    // MARK: - Services (Lazy Initialized)

    private var _lastFmService: LastFmService?
    private var _musicKitService: MusicKitService?
    private var _scrobbleService: ScrobbleService?

    var lastFmService: LastFmService {
        if _lastFmService == nil {
            _lastFmService = LastFmService()
        }
        return _lastFmService!
    }

    var musicKitService: MusicKitService {
        if _musicKitService == nil {
            _musicKitService = MusicKitService()
        }
        return _musicKitService!
    }

    var scrobbleService: ScrobbleService {
        if _scrobbleService == nil {
            _scrobbleService = ScrobbleService(
                lastFmService: lastFmService,
                musicKitService: musicKitService,
                modelContext: modelContainer.mainContext
            )
        }
        return _scrobbleService!
    }

    private init() {}
}
