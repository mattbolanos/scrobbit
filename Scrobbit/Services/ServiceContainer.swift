import Foundation

/// A container for services that need to be accessed by background tasks.
/// This allows background task handlers to be registered early (in App.init)
/// while services are initialized later.
@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    var lastFmService: LastFmService?
    var musicKitService: MusicKitService?
    var scrobbleService: ScrobbleService?

    private init() {}
}
