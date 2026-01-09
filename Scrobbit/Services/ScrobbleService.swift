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
        guard !isSyncing else { return }
        guard lastFmService.isAuthenticated && musicKitService.isAuthorized else { return }
        
        isSyncing = true
        lastSyncError = nil
        
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }
        
        do {
            // Step 1: Scrobble new tracks from Apple Music
            try await scrobbleNewTracks()
            
            // Step 2: Refresh local history cache from Last.fm
            try await refreshHistoryCache()
        } catch {
            lastSyncError = error
        }
    }
    
    /// Scrobbles tracks from Apple Music that haven't been scrobbled yet.
    private func scrobbleNewTracks() async throws {
        // 1. Fetch recently played from Apple Music
        let recentTracks = try await musicKitService.fetchRecentlyPlayed()
        
        // 2. Estimate timestamps (newest first, work backwards from now)
        let tracksWithTimestamps = estimateTimestamps(for: recentTracks)
        
        // 3. Filter out tracks already in local cache
        let newTracks = try filterAgainstCache(tracksWithTimestamps)
        
        guard !newTracks.isEmpty else { return }
        
        // 4. Scrobble to Last.fm
        let accepted = try await lastFmService.scrobble(newTracks)
        
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
    
    /// Filters out tracks that are already in the local scrobble cache.
    private func filterAgainstCache(_ tracks: [Track]) throws -> [Track] {
        try tracks.filter { track in
            guard let timestamp = track.estimatedPlayTime else { return false }
            
            let cacheKey = ScrobbleCache.generateKey(
                appleMusicID: track.id,
                timestamp: timestamp
            )
            
            let descriptor = FetchDescriptor<ScrobbleCache>(
                predicate: #Predicate { $0.cacheKey == cacheKey }
            )
            
            let existing = try modelContext.fetch(descriptor)
            return existing.isEmpty // Keep if not in cache
        }
    }
    
    /// Adds scrobbled tracks to the local cache for future de-duplication.
    private func addToCache(_ tracks: [Track]) throws {
        for track in tracks {
            guard let timestamp = track.estimatedPlayTime else { continue }
            
            let cacheEntry = ScrobbleCache(
                appleMusicID: track.id,
                estimatedTimestamp: timestamp
            )
            modelContext.insert(cacheEntry)
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
        let scrobbles = try await lastFmService.fetchRecentScrobbles(limit: 50)
        
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
            } else if let existingTrack = existing.first {
                // Update existing record (artwork might have changed)
                existingTrack.artworkURL = scrobble.artworkURL
                existingTrack.lastFmURL = scrobble.lastFmURL
            }
        }
        
        try modelContext.save()
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
