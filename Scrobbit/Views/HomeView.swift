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
                        lastSyncLabel
                    }
                }
            }
            .task {
                await loadUserInfoIfNeeded()
                await loadRecentScrobbles()
            }
            .refreshable {
                await performSyncWithFeedback()
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet()
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
    
    // MARK: - Last Sync Label

    private var lastSyncLabel: some View {
        Group {
            if let lastSync = scrobbleService?.lastSyncDate {
                Text("Synced \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

    // MARK: - Sync

    private func performSyncWithFeedback() async {
        guard isFullyConnected else { return }

        print("[HomeView] Starting sync...")
        if let result = await scrobbleService?.performSync() {
            print("[HomeView] Sync result: scrobbledCount=\(result.scrobbledCount), error=\(String(describing: result.error))")
            if result.scrobbledCount > 0 {
                syncToastMessage = "Scrobbled \(result.scrobbledCount) new track\(result.scrobbledCount == 1 ? "" : "s")"
            } else {
                syncToastMessage = "Already up to date"
            }
            showSyncToast = true
        } else {
            print("[HomeView] performSync returned nil")
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
