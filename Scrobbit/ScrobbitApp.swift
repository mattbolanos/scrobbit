import SwiftUI
import SwiftData

@main
struct ScrobbitApp: App {
    @State private var lastFmService = LastFmService()
    @State private var appleMusicService = MusicKitService()
    @State private var scrobbleService: ScrobbleService?
    
    private let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: ScrobbledTrack.self, ScrobbleCache.self)
        } catch {
            fatalError("Failed to initialize SwiftData model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(lastFmService)
                .environment(appleMusicService)
                .environment(\.scrobbleService, scrobbleService)
                .modelContainer(modelContainer)
                .task {
                    // Initialize ScrobbleService with modelContext
                    if scrobbleService == nil {
                        scrobbleService = ScrobbleService(
                            lastFmService: lastFmService,
                            musicKitService: appleMusicService,
                            modelContext: modelContainer.mainContext
                        )
                        
                        // Auto-sync on launch if both services are connected
                        if lastFmService.isAuthenticated && appleMusicService.isAuthorized {
                            await scrobbleService?.performSync()
                        }
                    }
                }
        }
    }
}
