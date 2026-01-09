import Foundation
import SwiftData

/// Orchestrates the scrobbling flow between Apple Music and Last.fm.
/// Handles timestamp estimation and de-duplication via local cache.
@Observable
@MainActor
final class ScrobbleService {
    
    /// Default track duration when unknown (3 minutes)
    private static let defaultDuration: TimeInterval = 180
    
    /// Maximum age for cache entries (7 days)
    private static let cacheMaxAge: TimeInterval = 7 * 24 * 60 * 60
    
    private let lastFmService: LastFmService
    private let musicKitService: MusicKitService
    private let modelContext: ModelContext
    
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncError: Error?
    private(set) var lastSyncDate: Date?
    
    init(
        lastFmService: LastFmService,
        musicKitService: MusicKitService,
        modelContext: ModelContext
    ) {
        self.lastFmService = lastFmService
        self.musicKitService = musicKitService
        self.modelContext = modelContext
    }
    
    // MARK: - Sync Operations
    
    /// Performs a full sync: scrobbles new tracks and refreshes the history cache.
    /// This is the main entry point for background refresh and manual sync.
    func performSync() async {
        guard !isSyncing else {
            print("[ScrobbleService] Sync already in progress")
            return
        }
        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else {
            print("[ScrobbleService] Not authenticated - Last.fm: \(lastFmService.isAuthenticated), Apple Music: \(musicKitService.isAuthorized)")
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }
        
        do {
            // Step 1: Scrobble new tracks from Apple Music
            print("[ScrobbleService] Starting scrobble of new tracks...")
            try await scrobbleNewTracks()
            
            // Step 2: Refresh local history cache from Last.fm
            print("[ScrobbleService] Refreshing history cache from Last.fm...")
            try await refreshHistoryCache()
            
            print("[ScrobbleService] Sync completed successfully")
        } catch {
            print("[ScrobbleService] Sync failed: \(error)")
            lastSyncError = error
        }
    }
    
    /// Scrobbles tracks from Apple Music that haven't been scrobbled yet.
    private func scrobbleNewTracks() async throws {
        // 1. Fetch recently played from Apple Music
        print("[ScrobbleService] Fetching recently played from Apple Music...")
        let recentTracks: [Track]
        do {
            recentTracks = try await musicKitService.fetchRecentlyPlayed()
            print("[ScrobbleService] Fetched \(recentTracks.count) tracks from Apple Music")
        } catch {
            print("[ScrobbleService] Failed to fetch from Apple Music: \(error)")
            throw error
        }
        
        // 2. Estimate timestamps (newest first, work backwards from now)
        let tracksWithTimestamps = estimateTimestamps(for: recentTracks)
        
        // 3. Filter out tracks already in local cache
        let newTracks = try filterAgainstCache(tracksWithTimestamps)
        print("[ScrobbleService] \(newTracks.count) new tracks to scrobble (after de-duplication)")
        
        guard !newTracks.isEmpty else {
            print("[ScrobbleService] No new tracks to scrobble")
            return
        }
        
        // 4. Scrobble to Last.fm
        print("[ScrobbleService] Scrobbling \(newTracks.count) tracks to Last.fm...")
        let accepted: Int
        do {
            accepted = try await lastFmService.scrobble(newTracks)
            print("[ScrobbleService] Last.fm accepted \(accepted) scrobbles")
        } catch {
            print("[ScrobbleService] Failed to scrobble to Last.fm: \(error)")
            throw error
        }
        
        // 5. Add scrobbled tracks to local cache
        if accepted > 0 {
            try addToCache(newTracks)
            try pruneOldCacheEntries()
        }
    }
    
    // MARK: - Timestamp Estimation
    
    /// Estimates play timestamps by working backwards from "now" using track durations.
    /// Assumes tracks are ordered most-recent-first from MusicKit.
    private func estimateTimestamps(for tracks: [Track]) -> [Track] {
        var currentTime = Date()
        
        return tracks.map { track in
            let duration = track.duration ?? Self.defaultDuration
            let startTime = currentTime.addingTimeInterval(-duration)
            
            var updatedTrack = track
            updatedTrack.estimatedPlayTime = startTime
            
            // Next track ended when this one started
            currentTime = startTime
            return updatedTrack
        }
    }
    
    // MARK: - Cache De-duplication
    
    /// De-duplication window: if we scrobbled a track within this window, don't scrobble again.
    /// Set to 4 hours to cover the typical "recently played" list span while still
    /// allowing legitimate re-plays of the same song later in the day.
    private static let deduplicationWindow: TimeInterval = 4 * 60 * 60
    
    /// Filters out tracks that are already in the local scrobble cache.
    /// Uses track ID + time-based deduplication, with playCount to detect legitimate replays.
    private func filterAgainstCache(_ tracks: [Track]) throws -> [Track] {
        let windowStart = Date().addingTimeInterval(-Self.deduplicationWindow)
        
        return try tracks.filter { track in
            guard track.estimatedPlayTime != nil else { return false }
            
            // Check if we've scrobbled this track ID within the dedup window
            let trackID = track.id
            let descriptor = FetchDescriptor<ScrobbleCache>(
                predicate: #Predicate {
                    $0.appleMusicID == trackID && $0.createdAt > windowStart
                }
            )
            
            let existing = try modelContext.fetch(descriptor)
            
            // No cache entry = new track, allow scrobble
            guard let cachedEntry = existing.first else {
                return true
            }
            
            // Cache entry exists - check if playCount increased (legitimate replay)
            if let currentPlayCount = track.playCount,
               let cachedPlayCount = cachedEntry.lastKnownPlayCount,
               currentPlayCount > cachedPlayCount {
                print("[ScrobbleService] Track '\(track.title)' has higher playCount (\(currentPlayCount) > \(cachedPlayCount)), allowing re-scrobble")
                return true
            }
            
            // Same or lower playCount (or unavailable) = duplicate, skip
            return false
        }
    }
    
    /// Adds scrobbled tracks to the local cache for future de-duplication.
    private func addToCache(_ tracks: [Track]) throws {
        let windowStart = Date().addingTimeInterval(-Self.deduplicationWindow)
        
        for track in tracks {
            guard let timestamp = track.estimatedPlayTime else { continue }
            
            // Check if there's an existing cache entry to update (for playCount tracking)
            let trackID = track.id
            let descriptor = FetchDescriptor<ScrobbleCache>(
                predicate: #Predicate {
                    $0.appleMusicID == trackID && $0.createdAt > windowStart
                }
            )
            
            let existing = try modelContext.fetch(descriptor)
            
            if let existingEntry = existing.first {
                // Update existing entry with new playCount
                existingEntry.lastKnownPlayCount = track.playCount
                existingEntry.estimatedTimestamp = timestamp
            } else {
                // Insert new cache entry
                let cacheEntry = ScrobbleCache(
                    appleMusicID: track.id,
                    estimatedTimestamp: timestamp,
                    playCount: track.playCount
                )
                modelContext.insert(cacheEntry)
            }
        }
        
        try modelContext.save()
    }
    
    /// Removes cache entries older than 7 days to prevent unbounded growth.
    private func pruneOldCacheEntries() throws {
        let cutoffDate = Date().addingTimeInterval(-Self.cacheMaxAge)
        
        let descriptor = FetchDescriptor<ScrobbleCache>(
            predicate: #Predicate { $0.createdAt < cutoffDate }
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
        print("[ScrobbleService] Fetching recent scrobbles from Last.fm...")
        let scrobbles: [LastFmScrobble]
        do {
            scrobbles = try await lastFmService.fetchRecentScrobbles(limit: 50)
            print("[ScrobbleService] Fetched \(scrobbles.count) scrobbles from Last.fm")
        } catch {
            print("[ScrobbleService] Failed to fetch scrobbles from Last.fm: \(error)")
            throw error
        }
        
        var insertedCount = 0
        var updatedCount = 0
        
        // Upsert into SwiftData
        for scrobble in scrobbles {
            let scrobbleID = ScrobbledTrack.generateID(
                artistName: scrobble.artistName,
                trackName: scrobble.trackName,
                timestamp: scrobble.scrobbledAt
            )
            
            // Check if already exists
            let descriptor = FetchDescriptor<ScrobbledTrack>(
                predicate: #Predicate { $0.scrobbleID == scrobbleID }
            )
            
            let existing = try modelContext.fetch(descriptor)
            
            if existing.isEmpty {
                // Insert new record
                let track = ScrobbledTrack(
                    trackName: scrobble.trackName,
                    artistName: scrobble.artistName,
                    albumName: scrobble.albumName,
                    scrobbledAt: scrobble.scrobbledAt,
                    artworkURL: scrobble.artworkURL,
                    lastFmURL: scrobble.lastFmURL
                )
                modelContext.insert(track)
                insertedCount += 1
            } else if let existingTrack = existing.first {
                // Update existing record (artwork might have changed)
                existingTrack.artworkURL = scrobble.artworkURL
                existingTrack.lastFmURL = scrobble.lastFmURL
                updatedCount += 1
            }
        }
        
        print("[ScrobbleService] Inserted \(insertedCount) new, updated \(updatedCount) existing tracks")
        
        do {
            try modelContext.save()
            print("[ScrobbleService] Successfully saved to SwiftData")
        } catch {
            print("[ScrobbleService] Failed to save to SwiftData: \(error)")
            throw error
        }
    }
    
    /// Clears the local scrobble cache (de-duplication cache).
    func clearScrobbleCache() throws {
        try modelContext.delete(model: ScrobbleCache.self)
        try modelContext.save()
    }
    
    /// Clears the local history cache (Last.fm display cache).
    func clearHistoryCache() throws {
        try modelContext.delete(model: ScrobbledTrack.self)
        try modelContext.save()
    }
}
