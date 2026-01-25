import SwiftUI
import SwiftData

@main
struct ScrobbitApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Shared service container with lazy initialization
    private let container = ServiceContainer.shared

    init() {
        // Register background task handler before app finishes launching
        BackgroundTaskManager.registerBackgroundTaskHandler()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(container.lastFmService)
                .environment(container.musicKitService)
                .environment(container.scrobbleService)
                .modelContainer(container.modelContainer)
                .onAppear {
                    BackgroundTaskManager.scheduleBackgroundRefresh()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        BackgroundTaskManager.scheduleBackgroundRefresh()
                    }
                }
        }
    }
}
