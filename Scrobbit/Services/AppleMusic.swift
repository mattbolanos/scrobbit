import Foundation

@Observable
final class AppleMusicService {
    
    // MARK: - Properties
    
    private(set) var isAuthorized: Bool = false
    private(set) var isAuthorizing: Bool = false
    
    var statusDescription: String {
        if isAuthorizing {
            return "Connecting..."
        } else if isAuthorized {
            return "Connected"
        } else {
            return "Tap to connect"
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // TODO: Check stored authorization status
    }
    
    // MARK: - Authorization
    
    @MainActor
    func requestAuthorization() async {
        guard !isAuthorizing else { return }
        
        isAuthorizing = true
        defer { isAuthorizing = false }
        
        // TODO: Implement MusicKit authorization
        // MusicAuthorization.request()
        
        // Placeholder: simulate authorization for UI testing
        try? await Task.sleep(for: .seconds(1))
        isAuthorized = true
    }
    
    func disconnect() {
        isAuthorized = false
    }
}

