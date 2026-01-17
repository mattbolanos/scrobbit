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
            modelContainer = try ModelContainer(for: Track.self, LibraryCache.self)
        } catch {
            fatalError("Failed to initialize SwiftData model container: \(error)")
        }
        BackgroundTaskManager.registerBackgroundTaskHandler()
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

                    // Initialize BackgroundTaskManager and populate ServiceContainer
                    if backgroundTaskManager == nil {
                        backgroundTaskManager = BackgroundTaskManager(
                            lastFmService: lastFmService,
                            musicKitService: appleMusicService,
                            scrobbleServiceProvider: { [scrobbleService] in scrobbleService }
                        )
                        backgroundTaskManager?.populateServiceContainer()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        backgroundTaskManager?.scheduleBackgroundRefresh()
                    }
                }
        }
    }
}
