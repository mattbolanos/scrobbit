import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    @Environment(\.scrobbleService) private var scrobbleService
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \LibraryCache.lastPlayedDate, order: .reverse)
    private var libraryCache: [LibraryCache]

    @State private var recentScrobbles: [LastFmScrobble] = []
    @State private var isLoadingScrobbles = false
    @State private var isLoadingUserInfo = false
    @State private var showConnectSheet = false

    // Sync state
    @State private var syncState: SyncState = .idle

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
                        SyncButton(state: $syncState) {
                            await performSync()
                        }
                    }
                }
            }
            .task {
                initializeFromCache()
                await loadUserInfoIfNeeded()
                await loadRecentScrobbles()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await refreshScrobblesInBackground()
                    }
                }
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet(onFullyConnected: {
                    Task { await performSync() }
                })
            }
        }
    }

    // MARK: - Recent Tracks Section

    @ViewBuilder
    private var recentTracksSection: some View {
        if lastFmService.isAuthenticated {
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

    // MARK: - Cache Initialization

    private func initializeFromCache() {
        if recentScrobbles.isEmpty && !lastFmService.cachedRecentScrobbles.isEmpty {
            recentScrobbles = lastFmService.cachedRecentScrobbles
        }
    }

    // MARK: - Load User Info

    private func loadUserInfoIfNeeded() async {
        guard lastFmService.isAuthenticated else { return }

        let hasCachedData = lastFmService.userInfo != nil
        if !hasCachedData {
            isLoadingUserInfo = true
        }
        defer { isLoadingUserInfo = false }

        do {
            try await lastFmService.fetchUserInfo()
        } catch {
            // Silently fail - cached data remains displayed
        }
    }

    // MARK: - Sync

    private func performSync() async {
        guard isFullyConnected else { return }
        guard syncState == .idle else { return }

        syncState = .syncing

        let result = await scrobbleService?.performSync()

        if let result {
            if let error = result.error {
                syncState = .error(message: error.localizedDescription)
            } else if result.scrobbledCount > 0 {
                syncState = .success(count: result.scrobbledCount)
                await loadRecentScrobbles()
            } else {
                syncState = .empty
            }
        } else {
            syncState = .idle
        }
    }

    // MARK: - Load Recent Scrobbles

    private func refreshScrobblesInBackground() async {
        guard lastFmService.isAuthenticated else { return }

        do {
            let freshScrobbles = try await lastFmService.fetchRecentScrobbles(limit: 25)
            withAnimation(Theme.Animation.standard) {
                recentScrobbles = freshScrobbles
            }
        } catch {
            // Silently fail - cached data remains displayed
        }
    }

    private func loadRecentScrobbles() async {
        guard lastFmService.isAuthenticated else { return }

        let hasCachedData = !recentScrobbles.isEmpty
        if !hasCachedData {
            isLoadingScrobbles = true
        }
        defer { isLoadingScrobbles = false }

        do {
            let freshScrobbles = try await lastFmService.fetchRecentScrobbles(limit: 25)
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
