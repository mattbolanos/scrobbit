import Foundation
import SwiftData
import SwiftUI

/// Result of a sync operation
struct SyncResult: Equatable {
    let scrobbledCount: Int
    let error: Error?

    static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
        lhs.scrobbledCount == rhs.scrobbledCount &&
        lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
}

/// Orchestrates the scrobbling flow between Apple Music and Last.fm.
/// Uses LibraryCache to track play counts and detect new plays.
@Observable
final class ScrobbleService {

    /// Maximum age for cache entries (30 days)
    private static let cacheMaxAge: TimeInterval = 30 * 24 * 60 * 60

    /// How often to prune cache (every 6 hours)
    private static let pruneInterval: TimeInterval = 6 * 60 * 60

    private let lastFmService: LastFmService
    private let musicKitService: MusicKitService
    private let modelContext: ModelContext

    private static let lastSyncDateKey = "lastSyncDate"

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncError: Error?
    private(set) var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: Self.lastSyncDateKey)
            }
        }
    }
    private var lastPruneDate: Date?

    /// Pending scrobbles waiting to be sent to Last.fm (for UI display)
    private(set) var pendingScrobbles: [PendingScrobble] = []
    
    init(
        lastFmService: LastFmService,
        musicKitService: MusicKitService,
        modelContext: ModelContext
    ) {
        self.lastFmService = lastFmService
        self.musicKitService = musicKitService
        self.modelContext = modelContext
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date
    }
    
    // MARK: - Sync Operations

    /// Performs a full sync: scrobbles new tracks and refreshes the history cache.
    /// This is the main entry point for background refresh and manual sync.
    /// - Parameters:
    ///   - includeNonCritical: If true, also refreshes history cache and prunes old entries.
    ///                         Set to false for background tasks with limited execution time.
    /// Returns the number of tracks scrobbled, or nil if sync was skipped/failed.
    @discardableResult
    func performSync(includeNonCritical: Bool = true) async -> SyncResult? {
        guard !isSyncing else { return nil }
        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else { return nil }

        isSyncing = true
        lastSyncError = nil

        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        var scrobbledCount = 0

        do {
            // Step 1: Detect and scrobble new plays from library (critical path)
            scrobbledCount = try await scrobbleNewPlays()

            // Step 2 & 3: Only run non-critical tasks when time permits (foreground)
            if includeNonCritical {
                // Refresh history cache in the background (non-blocking)
                Task.detached(priority: .utility) { [weak self] in
                    try? await self?.refreshHistoryCache()
                }

                // Prune old cache entries periodically (non-blocking)
                if shouldPrune() {
                    Task.detached(priority: .background) { [weak self] in
                        try? await self?.pruneOldCacheEntries()
                    }
                    lastPruneDate = Date()
                }
            }

            // Log successful sync
            SyncLog.shared.record(event: .completed, scrobblesCount: scrobbledCount)

            return SyncResult(scrobbledCount: scrobbledCount, error: nil)
        } catch {
            lastSyncError = error
            // Log failed sync
            SyncLog.shared.record(
                event: .failed,
                scrobblesCount: scrobbledCount,
                message: error.localizedDescription
            )
            return SyncResult(scrobbledCount: scrobbledCount, error: error)
        }
    }

    private func shouldPrune() -> Bool {
        guard let lastPrune = lastPruneDate else { return true }
        return Date().timeIntervalSince(lastPrune) > Self.pruneInterval
    }
    
    // MARK: - Library-Based Scrobbling

    /// Detects new plays by comparing MediaPlayer library state against LibraryCache,
    /// then scrobbles any new plays to Last.fm.
    /// Returns the number of tracks successfully scrobbled.
    private func scrobbleNewPlays() async throws -> Int {
        let syncTime = Date()

        // 1. Fetch library songs from MediaPlayer (these have trusted timestamps)
        let (recentLibrarySongs, _) = try await musicKitService.fetchLastPlayedSongsFromMediaPlayer()

        guard !recentLibrarySongs.isEmpty else { return 0 }

        // 2. Fetch all LibraryCache entries and build lookup in memory
        // (SwiftData predicates don't support .contains() with arrays)
        let cacheDescriptor = FetchDescriptor<LibraryCache>()
        let cachedEntries = try modelContext.fetch(cacheDescriptor)
        let cacheLookup = Dictionary(uniqueKeysWithValues: cachedEntries.map { ($0.persistentID, $0) })

        // Check if this is the first sync (no cache entries exist)
        let isFirstSync = cachedEntries.isEmpty

        // 3. Compare against cache and generate pending scrobbles
        var newPendingScrobbles: [PendingScrobble] = []

        for item in recentLibrarySongs {
            let scrobbles = processLibraryItem(
                item,
                cachedEntry: cacheLookup[item.id],
                isFirstSync: isFirstSync,
                syncTime: syncTime
            )
            newPendingScrobbles.append(contentsOf: scrobbles)
        }

        // 4. Update UI with pending scrobbles
        pendingScrobbles = newPendingScrobbles.sorted { $0.scrobbleAt > $1.scrobbleAt }
        var scrobbledCount = 0

        // 5. Send to Last.fm if we have any
        if !pendingScrobbles.isEmpty {
            scrobbledCount = try await lastFmService.scrobble(pendingScrobbles)

            if scrobbledCount > 0 {
                // Clear pending after successful scrobble
                pendingScrobbles = []
            }
        }

        // 6. Save cache changes
        try modelContext.save()

        return scrobbledCount
    }
    
    /// Processes a single library item, comparing against cache and generating scrobbles.
    /// Returns pending scrobbles for any new plays detected.
    private func processLibraryItem(
        _ item: MediaPlayerItem,
        cachedEntry: LibraryCache?,
        isFirstSync: Bool,
        syncTime: Date
    ) -> [PendingScrobble] {
        if let cachedEntry = cachedEntry {
            // Existing song - check for new plays
            return updateExistingEntry(cachedEntry, with: item, syncTime: syncTime)
        } else {
            // New song - add to cache
            return addNewEntry(for: item, isFirstSync: isFirstSync, syncTime: syncTime)
        }
    }
    
    /// Updates an existing cache entry and returns scrobbles for any new plays.
    private func updateExistingEntry(
        _ cachedEntry: LibraryCache,
        with item: MediaPlayerItem,
        syncTime: Date
    ) -> [PendingScrobble] {
        let playCountDelta = item.playCount - cachedEntry.playCount
        
        var scrobbles: [PendingScrobble] = []
        
        // Only generate scrobbles if playCount increased
        if playCountDelta > 0, let lastPlayed = item.lastPlayedDate {
            scrobbles = generateScrobblesForMultiplePlays(
                item: item,
                numberOfPlays: playCountDelta,
                lastPlayedDate: lastPlayed
            )
        }
        
        // Update cache entry with current state
        cachedEntry.update(from: item, syncedAt: syncTime)
        
        return scrobbles
    }
    
    /// Adds a new cache entry for a song not previously tracked.
    /// On first sync, we don't scrobble historical plays.
    /// On subsequent syncs, we scrobble if the song was played within Last.fm's 2-week window.
    private func addNewEntry(
        for item: MediaPlayerItem,
        isFirstSync: Bool,
        syncTime: Date
    ) -> [PendingScrobble] {
        // Create cache entry
        let newEntry = LibraryCache(from: item, syncedAt: syncTime)
        modelContext.insert(newEntry)

        // On first sync, don't scrobble - just establish baseline
        guard !isFirstSync else { return [] }

        // Scrobble if the song has been played and timestamp is within Last.fm's 2-week window
        guard item.playCount > 0, let lastPlayed = item.lastPlayedDate else { return [] }

        let twoWeeksAgo = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        guard lastPlayed > twoWeeksAgo else { return [] }

        return [PendingScrobble(
            title: item.title,
            artistName: item.artistName,
            albumTitle: item.albumTitle,
            scrobbleAt: lastPlayed
        )]
    }
    
    /// Generates scrobbles for multiple plays of the same song.
    /// Works backwards from lastPlayedDate using playbackDuration to estimate timestamps.
    private func generateScrobblesForMultiplePlays(
        item: MediaPlayerItem,
        numberOfPlays: Int,
        lastPlayedDate: Date
    ) -> [PendingScrobble] {
        var scrobbles: [PendingScrobble] = []
        var currentTimestamp = lastPlayedDate
        
        for _ in 0..<numberOfPlays {
            scrobbles.append(PendingScrobble(
                title: item.title,
                artistName: item.artistName,
                albumTitle: item.albumTitle,
                scrobbleAt: currentTimestamp
            ))
            
            // Work backwards by the track duration for the previous play
            currentTimestamp = currentTimestamp.addingTimeInterval(-item.playbackDuration)
        }
        
        return scrobbles
    }
    
    /// Removes cache entries older than 30 days to prevent unbounded growth.
    @MainActor
    private func pruneOldCacheEntries() async throws {
        let cutoffDate = Date().addingTimeInterval(-Self.cacheMaxAge)

        let descriptor = FetchDescriptor<LibraryCache>(
            predicate: #Predicate { $0.lastSyncedAt < cutoffDate }
        )

        let oldEntries = try modelContext.fetch(descriptor)

        for entry in oldEntries {
            modelContext.delete(entry)
        }

        if !oldEntries.isEmpty {
            try modelContext.save()
        }
    }
    
    // MARK: - History Cache (Last.fm scrobbles for display)

    /// Fetches recent scrobbles from Last.fm and updates the local history cache.
    func refreshHistoryCache() async throws {
        let scrobbles = try await lastFmService.fetchRecentScrobbles(limit: 50)

        guard !scrobbles.isEmpty else { return }

        // Generate all scrobble IDs upfront
        let scrobbleIDsAndData: [(id: String, scrobble: LastFmScrobble)] = scrobbles.map { scrobble in
            let id = Track.generateScrobbleID(
                artistName: scrobble.artistName,
                trackName: scrobble.trackName,
                timestamp: scrobble.scrobbledAt
            )
            return (id, scrobble)
        }

        // Fetch all Track entries and build lookup in memory
        // (SwiftData predicates don't support .contains() with arrays or ?? operator)
        let trackDescriptor = FetchDescriptor<Track>()
        let existingTracks = try modelContext.fetch(trackDescriptor)
        let trackLookup = Dictionary(uniqueKeysWithValues: existingTracks.compactMap { track -> (String, Track)? in
            guard let scrobbleID = track.scrobbleID else { return nil }
            return (scrobbleID, track)
        })

        // Upsert into SwiftData
        for (scrobbleID, scrobble) in scrobbleIDsAndData {
            if let existingTrack = trackLookup[scrobbleID] {
                // Update existing record (artwork might have changed)
                existingTrack.artworkURL = scrobble.artworkURL
                existingTrack.lastFmURL = scrobble.lastFmURL
            } else {
                // Insert new record
                let track = Track(
                    title: scrobble.trackName,
                    artistName: scrobble.artistName,
                    albumTitle: scrobble.albumName,
                    artworkURL: scrobble.artworkURL,
                    scrobbledAt: scrobble.scrobbledAt,
                    lastFmURL: scrobble.lastFmURL,
                    scrobbleID: scrobbleID
                )
                modelContext.insert(track)
            }
        }

        try modelContext.save()
    }
    
    // MARK: - Cache Management
    
    /// Clears the library cache (forces re-sync from scratch on next sync)
    func clearLibraryCache() throws {
        try modelContext.delete(model: LibraryCache.self)
        try modelContext.save()
    }
}
