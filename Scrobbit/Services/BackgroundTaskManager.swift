import BackgroundTasks
import Foundation
import Network
import os.log
import UIKit

/// Manages background app refresh tasks for periodic scrobbling.
enum BackgroundTaskManager {

    /// Task identifier registered in Info.plist
    static let scrobbleTaskIdentifier = "com.scrobbit.refresh"

    /// Interval between background refreshes (Set to minimum to let iOS decide)
    private static let refreshInterval: TimeInterval = UIApplication.backgroundFetchIntervalMinimum

    private static let logger = Logger(subsystem: "com.scrobbit", category: "BackgroundTask")

    // MARK: - Registration

    /// Registers the background task handler. Call this in App.init().
    static func registerBackgroundTaskHandler() {
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: scrobbleTaskIdentifier,
            using: nil
        ) { task in
            // Downcast to BGAppRefreshTask
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            
            // Start the async work immediately without forcing MainActor
            Task {
                await handleBackgroundTask(refreshTask)
            }
        }
        
        if success {
            logger.info("Registered background task handler")
        } else {
            logger.error("Failed to register background task handler")
        }
    }

    // MARK: - Task Handler

    /// Handles the background task. Note: Removed @MainActor for performance.
    private static func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("Background task started")

        // 1. Immediately schedule the next window
        scheduleBackgroundRefresh()

        // 2. Setup expiration handler
        task.expirationHandler = {
            logger.warning("Background task expired by system")
            task.setTaskCompleted(success: false)
        }

        // 3. Perform network check
        let isConnected = await checkNetworkConnectivity()
        guard isConnected else {
            logger.info("No network - skipping sync")
            task.setTaskCompleted(success: true)
            return
        }

        // 4. Perform Sync
        let container = ServiceContainer.shared

        // If authentication checks must be on MainActor, wrap ONLY those checks
        let (isAuthed, isMusicAuthed) = await MainActor.run {
            return (container.lastFmService.isAuthenticated,
                    container.musicKitService.isAuthorized)
        }

        guard isAuthed && isMusicAuthed else {
            logger.info("Not authenticated - skipping sync")
            task.setTaskCompleted(success: true)
            return
        }

        // Execute the scrobble sync (logging handled by ScrobbleService)
        let result = await container.scrobbleService.performSync(includeNonCritical: false, source: .background)
        let scrobblesCount = result?.scrobbledCount ?? 0
        let success = result?.error == nil

        if success {
            logger.info("Background sync completed: \(scrobblesCount) scrobbles")
        } else {
            let errorMsg = result?.error?.localizedDescription ?? "unknown error"
            logger.error("Background sync failed: \(errorMsg)")
        }

        task.setTaskCompleted(success: success)
    }

    // MARK: - Scheduling

    /// Schedules the next background refresh.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: scrobbleTaskIdentifier)
        
        // Suggest the earliest date. Using refreshInterval (min) increases 
        // the frequency iOS might grant you.
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background refresh request")
        } catch {
            logger.error("Could not schedule background refresh: \(error)")
        }
    }

    static func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: scrobbleTaskIdentifier)
        logger.info("Cancelled pending tasks")
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
