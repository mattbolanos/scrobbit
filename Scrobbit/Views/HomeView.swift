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

                    if isFullyConnected {
                        lastSyncLabel
                    }

                    recentTracksSection
                }
                .padding()
            }
            .navigationTitle("Scrobbit")
            .task {
                await loadUserInfoIfNeeded()
                await loadRecentScrobbles()
            }
            .refreshable {
                if isFullyConnected {
                    await scrobbleService?.performSync()
                }
                await loadRecentScrobbles()
            }
            .onChange(of: isFullyConnected) { wasConnected, isNowConnected in
                // Trigger initial sync when user connects both accounts
                if !wasConnected && isNowConnected {
                    Task {
                        await scrobbleService?.performSync()
                        await loadRecentScrobbles()
                    }
                }
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet()
            }
        }
    }
    
    // MARK: - Recent Tracks Section
    
    @ViewBuilder
    private var recentTracksSection: some View {
        if !libraryCache.isEmpty {
            // Show library cache data (prioritized)
            RecentlyPlayedSection(
                tracks: Array(libraryCache.prefix(30)),
                title: "Recent from Library",
                emptyMessage: "No tracks found",
                isLoading: false
            )
        } else if lastFmService.isAuthenticated {
            // Fallback to Last.fm scrobbles
            RecentlyPlayedSection(
                tracks: recentScrobbles,
                title: "Latest from Last.fm",
                emptyMessage: "No scrobbles found",
                isLoading: isLoadingScrobbles
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
    
    // MARK: - Last Sync Label

    private var lastSyncLabel: some View {
        Group {
            if let lastSync = scrobbleService?.lastSyncDate {
                Text("Last synced \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pull down to sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Load User Info
    
    private func loadUserInfoIfNeeded() async {
        guard lastFmService.isAuthenticated, lastFmService.userInfo == nil else { return }
        
        isLoadingUserInfo = true
        defer { isLoadingUserInfo = false }
        
        do {
            try await lastFmService.fetchUserInfo()
        } catch {
        }
    }
    
    // MARK: - Load Recent Scrobbles
    
    private func loadRecentScrobbles() async {
        guard lastFmService.isAuthenticated else { return }
        
        isLoadingScrobbles = true
        defer { isLoadingScrobbles = false }
        
        do {
            recentScrobbles = try await lastFmService.fetchRecentScrobbles(limit: 30)
        } catch {
            // Silently fail - empty state will be shown
        }
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
