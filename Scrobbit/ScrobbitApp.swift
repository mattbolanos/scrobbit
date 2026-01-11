import SwiftUI
import SwiftData

@main
struct ScrobbitApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var lastFmService = LastFmService()
    @State private var appleMusicService = MusicKitService()
    @State private var scrobbleService: ScrobbleService?
    @State private var backgroundTaskManager: BackgroundTaskManager?
    
    private let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: Track.self, ScrobbleCache.self)
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
                    }
                    
                    // Initialize and register BackgroundTaskManager
                    if backgroundTaskManager == nil {
                        backgroundTaskManager = BackgroundTaskManager(
                            lastFmService: lastFmService,
                            musicKitService: appleMusicService,
                            scrobbleServiceProvider: { [scrobbleService] in scrobbleService }
                        )
                        backgroundTaskManager?.registerBackgroundTask()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        // Schedule background refresh when app goes to background
                        backgroundTaskManager?.scheduleBackgroundRefresh()
                    }
                }
        }
    }
}
