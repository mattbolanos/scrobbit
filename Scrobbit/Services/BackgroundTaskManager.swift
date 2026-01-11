import BackgroundTasks
import Foundation

/// Manages background app refresh tasks for periodic scrobbling.
@MainActor
final class BackgroundTaskManager {
    
    /// Task identifier registered in Info.plist
    nonisolated static let scrobbleTaskIdentifier = "com.scrobbit.refresh"
    
    /// Interval between background refreshes (30 minutes)
    private static let refreshInterval: TimeInterval = 30 * 60
    
    private let lastFmService: LastFmService
    private let musicKitService: MusicKitService
    private let scrobbleServiceProvider: () -> ScrobbleService?
    
    init(
        lastFmService: LastFmService,
        musicKitService: MusicKitService,
        scrobbleServiceProvider: @escaping () -> ScrobbleService?
    ) {
        self.lastFmService = lastFmService
        self.musicKitService = musicKitService
        self.scrobbleServiceProvider = scrobbleServiceProvider
    }
    
    /// Registers the background task handler with the system.
    /// Call this in the App's init before the scene is created.
    nonisolated func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.scrobbleTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
    }
    
    /// Schedules the next background refresh.
    /// Call this after a successful sync or when the app goes to background.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.scrobbleTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundTaskManager] Failed to schedule background refresh: \(error)")
        }
    }
    
    /// Cancels any pending background refresh tasks.
    func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.scrobbleTaskIdentifier)
        print("[BackgroundTaskManager] Cancelled pending background tasks")
    }
    
    // MARK: - Private
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        print("[BackgroundTaskManager] Background task started")
        
        // Schedule the next refresh before we start work
        scheduleBackgroundRefresh()
        
        // Set up expiration handler
        task.expirationHandler = {
            print("[BackgroundTaskManager] Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Only sync if both services are connected
        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else {
            print("[BackgroundTaskManager] Not authenticated, skipping sync")
            task.setTaskCompleted(success: true)
            return
        }
        
        // Perform the sync
        guard let scrobbleService = scrobbleServiceProvider() else {
            print("[BackgroundTaskManager] ScrobbleService not available")
            task.setTaskCompleted(success: false)
            return
        }
        
        await scrobbleService.performSync()
        
        let success = scrobbleService.lastSyncError == nil
        print("[BackgroundTaskManager] Background task completed, success: \(success)")
        task.setTaskCompleted(success: success)
    }
}
