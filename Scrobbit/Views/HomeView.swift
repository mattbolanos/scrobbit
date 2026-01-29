import SwiftUI
import SwiftData

private enum SyncStatus {
    case idle
    case syncing
    case success
    case failure
}

struct HomeView: View {
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    @Environment(ScrobbleService.self) private var scrobbleService
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \LibraryCache.lastPlayedDate, order: .reverse)
    private var libraryCache: [LibraryCache]

    @State private var recentScrobbles: [LastFmScrobble] = []
    @State private var isLoadingScrobbles = false
    @State private var isLoadingUserInfo = false
    @State private var showConnectSheet = false

    // Sync state
    @State private var syncStatus: SyncStatus = .idle

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
            .navigationTitle("Scrobbit")
            .navigationBarTitleDisplayMode(.large)
            .modifier(SyncSubtitleModifier(lastSyncDate: scrobbleService.lastSyncDate))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isFullyConnected {
                        syncButton
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

    private var syncButton: some View {
        Button {
            guard syncStatus == .idle else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                syncStatus = .syncing
                let success = await performSync()
                syncStatus = success ? .success : .failure

                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(success ? .success : .error)

                try? await Task.sleep(for: .seconds(1.5))
                syncStatus = .idle
            }
        } label: {
            Group {
                switch syncStatus {
                case .idle:
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                case .syncing:
                    ProgressView()
                case .success:
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.success)
                case .failure:
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                }
            }
            .contentTransition(.symbolEffect(.replace))
        }
        .disabled(syncStatus != .idle)
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

    @discardableResult
    private func performSync() async -> Bool {
        guard isFullyConnected else { return false }

        let result = await scrobbleService.performSync()

        if let result {
            if result.error != nil {
                return false
            } else {
                await loadRecentScrobbles()
                return true
            }
        }
        return false
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

// MARK: - Sync Subtitle Modifier

private struct SyncSubtitleModifier: ViewModifier {
    let lastSyncDate: Date?

    private var subtitleText: String {
        guard let lastSync = lastSyncDate else {
            return "Play some music to get started"
        }

        let secondsAgo = Date().timeIntervalSince(lastSync)
        if secondsAgo < 60 {
            return "Last synced just now"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: .now))"
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .navigationSubtitle(Text(subtitleText))
                .animation(.default, value: lastSyncDate)
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Theme.Spacing.xs)
                }
                .animation(Theme.Animation.quick, value: lastSyncDate)
        }
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
