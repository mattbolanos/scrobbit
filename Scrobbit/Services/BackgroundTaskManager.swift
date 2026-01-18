import BackgroundTasks
import Foundation
import Network

/// Manages background app refresh tasks for periodic scrobbling.
@MainActor
final class BackgroundTaskManager {

    /// Task identifier registered in Info.plist
    nonisolated static let scrobbleTaskIdentifier = "com.scrobbit.refresh"

    /// Interval between background refreshes (20 minutes)
    private static let refreshInterval: TimeInterval = 20 * 60

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

    // MARK: - Static Registration

    nonisolated static func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: scrobbleTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
    }

    /// Handles the background task using services from ServiceContainer.
    private static func handleBackgroundTask(_ task: BGAppRefreshTask) async {

        // Schedule the next refresh before we start work
        scheduleNextRefresh()

        // Set up expiration handler - reschedule to maintain sync chain
        task.expirationHandler = {
            scheduleNextRefresh()
            task.setTaskCompleted(success: false)
        }

        // Quick network check - skip sync if offline to save execution time
        let isConnected = await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.scrobbit.networkcheck")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }

        guard isConnected else {
            // No network - complete successfully (not an error, just nothing to do now)
            task.setTaskCompleted(success: true)
            return
        }

        let container = ServiceContainer.shared

        // Only sync if both services are connected
        guard let lastFmService = container.lastFmService,
              let musicKitService = container.musicKitService else {
            task.setTaskCompleted(success: false)
            return
        }

        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else {
            task.setTaskCompleted(success: true)
            return
        }

        // Perform the sync
        guard let scrobbleService = container.scrobbleService else {
            task.setTaskCompleted(success: false)
            return
        }

        await scrobbleService.performSync(includeNonCritical: false)

        let success = scrobbleService.lastSyncError == nil
        task.setTaskCompleted(success: success)
    }

    /// Schedules the next background refresh (static version for use in handler).
    private static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: scrobbleTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundTaskManager] Failed to schedule background refresh: \(error)")
        }
    }

    // MARK: - Instance Methods (for foreground use)

    /// Schedules the next background refresh.
    /// Call this after a successful sync or when the app goes to background.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.scrobbleTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundTaskManager] Scheduled background refresh")
        } catch {
            print("[BackgroundTaskManager] Failed to schedule background refresh: \(error)")
        }
    }

    /// Cancels any pending background refresh tasks.
    func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.scrobbleTaskIdentifier)
    }

    /// Populates the ServiceContainer with the services for background task access.
    func populateServiceContainer() {
        let container = ServiceContainer.shared
        container.lastFmService = lastFmService
        container.musicKitService = musicKitService
        container.scrobbleService = scrobbleServiceProvider()
    }
}
