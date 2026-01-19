import BackgroundTasks
import Foundation
import Network
import os.log

/// Manages background app refresh tasks for periodic scrobbling.
/// This is a stateless enum - all state comes from ServiceContainer.shared.
enum BackgroundTaskManager {

    /// Task identifier registered in Info.plist
    static let scrobbleTaskIdentifier = "com.scrobbit.refresh"

    /// Interval between background refreshes (30 minutes)
    private static let refreshInterval: TimeInterval = 30 * 60

    private static let logger = Logger(subsystem: "com.scrobbit", category: "BackgroundTask")

    // MARK: - Registration

    /// Registers the background task handler with BGTaskScheduler.
    /// Must be called in App.init() before the app finishes launching.
    static func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: scrobbleTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
        logger.info("Registered background task handler")
    }

    // MARK: - Task Handler

    /// Handles the background task using services from ServiceContainer.
    @MainActor
    private static func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("Background task started")

        // Schedule the next refresh before we start work
        scheduleBackgroundRefresh()

        // Set up expiration handler
        task.expirationHandler = {
            logger.warning("Background task expired")
            BackgroundTaskLog.shared.record(event: .expired)
            scheduleBackgroundRefresh()
            task.setTaskCompleted(success: false)
        }

        // Quick network check - skip sync if offline to save execution time
        let isConnected = await checkNetworkConnectivity()

        guard isConnected else {
            logger.info("No network - skipping sync")
            BackgroundTaskLog.shared.record(event: .skippedNoNetwork)
            task.setTaskCompleted(success: true)
            return
        }

        // Access services from the lazy-initializing container
        let container = ServiceContainer.shared
        let lastFmService = container.lastFmService
        let musicKitService = container.musicKitService

        // Only sync if both services are authenticated
        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else {
            logger.info("Not authenticated - skipping sync")
            BackgroundTaskLog.shared.record(event: .skippedNotAuthenticated)
            task.setTaskCompleted(success: true)
            return
        }

        // Perform the sync
        let scrobbleService = container.scrobbleService
        let result = await scrobbleService.performSync(includeNonCritical: false)

        let scrobblesCount = result?.scrobbledCount ?? 0
        let success = result?.error == nil

        if success {
            logger.info("Background sync completed: \(scrobblesCount) scrobbles")
            BackgroundTaskLog.shared.record(
                event: .completed,
                scrobblesCount: scrobblesCount
            )
        } else {
            logger.error("Background sync failed: \(result?.error?.localizedDescription ?? "unknown error")")
            BackgroundTaskLog.shared.record(
                event: .failed,
                scrobblesCount: scrobblesCount,
                message: result?.error?.localizedDescription
            )
        }

        task.setTaskCompleted(success: success)
    }

    // MARK: - Scheduling

    /// Schedules the next background refresh.
    /// Call this when the app goes to background or after a successful sync.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: scrobbleTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background refresh for \(refreshInterval / 60) minutes from now")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    /// Cancels any pending background refresh tasks.
    static func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: scrobbleTaskIdentifier)
        logger.info("Cancelled pending background tasks")
    }

    // MARK: - Network Check

    private static func checkNetworkConnectivity() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.scrobbit.networkcheck")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }
}
