import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    @Environment(\.scrobbleService) private var scrobbleService

    @Query(sort: \LibraryCache.lastPlayedDate, order: .reverse)
    private var libraryCache: [LibraryCache]

    @State private var recentScrobbles: [LastFmScrobble] = []
    @State private var isLoadingScrobbles = false
    @State private var isLoadingUserInfo = false
    @State private var showConnectSheet = false

    // Sync UI state
    @State private var showSyncToast = false
    @State private var syncToastMessage = ""
    @State private var isSyncing = false
    @State private var isScanning = false
    
    private var connectedCount: Int {
        var count = 0
        if lastFmService.isAuthenticated { count += 1 }
        if appleMusicService.isAuthorized { count += 1 }
        return count
    }
    
    private var isFullyConnected: Bool {
        connectedCount == 2
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    if !isFullyConnected {
                        ConnectAccountsButton(connectedCount: connectedCount) {
                            showConnectSheet = true
                        }
                    }

                    if lastFmService.isAuthenticated {
                        lastFmStatsGrid
                    }

                    recentTracksSection
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isFullyConnected {
                        scanButton
                    }
                }
            }
            .task {
                // Initialize from cache first for instant display
                initializeFromCache()
                // Then fetch fresh data in background
                await loadUserInfoIfNeeded()
                await loadRecentScrobbles()
            }
            .refreshable {
                await performSyncWithFeedback()
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet(onFullyConnected: {
                    Task { [self] in
                        await performSyncWithFeedback()
                    }
                })
            }
        }
        .toast(isPresented: $showSyncToast, message: syncToastMessage)
    }
    
    // MARK: - Recent Tracks Section
    
    @ViewBuilder
    private var recentTracksSection: some View {
        if lastFmService.isAuthenticated {
            // Fallback to Last.fm scrobbles
            RecentlyPlayedSection(
                tracks: recentScrobbles,
                title: "Latest from Last.fm",
                emptyMessage: "No scrobbles found",
                isLoading: isLoadingScrobbles
            )
        } else {
            RecentlyPlayedSection(
                tracks: [],
                title: "Latest from Last.fm",
                emptyMessage: "Start playing music to see your recent tracks here",
                isLoading: false
            )
        }
    }
    
    @ViewBuilder
    private var lastFmStatsGrid: some View {
        if let userInfo = lastFmService.userInfo {
            StatsGrid(userInfo: userInfo)
        } else if isLoadingUserInfo {
            StatsGridSkeleton()
        }
    }
    
    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            Task {
                isScanning = true
                await performSyncWithFeedback()
                isScanning = false
            }
        } label: {
            if isScanning {
                ProgressView()
            } else {
                Text("Scan")
            }
        }
        .font(.headline)
        .disabled(isSyncing || isScanning)
    }
    
    // MARK: - Cache Initialization

    private func initializeFromCache() {
        // Use cached scrobbles from service for instant display
        if recentScrobbles.isEmpty && !lastFmService.cachedRecentScrobbles.isEmpty {
            recentScrobbles = lastFmService.cachedRecentScrobbles
        }
    }

    // MARK: - Load User Info

    private func loadUserInfoIfNeeded() async {
        guard lastFmService.isAuthenticated else { return }

        // Only show loading indicator if no cached data
        let hasCachedData = lastFmService.userInfo != nil
        if !hasCachedData {
            isLoadingUserInfo = true
        }
        defer { isLoadingUserInfo = false }

        do {
            try await lastFmService.fetchUserInfo()
        } catch {
            // Silently fail - cached data (if any) remains displayed
        }
    }

    // MARK: - Sync

    private func performSyncWithFeedback() async {
        guard isFullyConnected else { return }

        isSyncing = true
        let result = await scrobbleService?.performSync()
        isSyncing = false
        
        if let result {
            if result.scrobbledCount > 0 {
                syncToastMessage = "Scrobbled \(result.scrobbledCount) new track\(result.scrobbledCount == 1 ? "" : "s")"
            } else {
                syncToastMessage = "Already up to date"
            }
            showSyncToast = true
            if result.scrobbledCount > 0 {
                await loadRecentScrobbles()
            }
        }
    }

    // MARK: - Load Recent Scrobbles

    private func loadRecentScrobbles() async {
        guard lastFmService.isAuthenticated else { return }

        // Only show loading if no cached data
        let hasCachedData = !recentScrobbles.isEmpty
        if !hasCachedData {
            isLoadingScrobbles = true
        }
        defer { isLoadingScrobbles = false }

        do {
            let freshScrobbles = try await lastFmService.fetchRecentScrobbles(limit: 30)
            // Animate the update for smooth transitions
            withAnimation(Theme.Animation.standard) {
                recentScrobbles = freshScrobbles
            }
        } catch {
            // Silently fail - cached data remains displayed
        }
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
