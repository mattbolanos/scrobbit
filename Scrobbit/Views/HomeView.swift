import SwiftUI

struct HomeView: View {
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    
    @State private var isLoadingUserInfo = false
    @State private var isLoadingRecentlyPlayed = false
    @State private var recentlyPlayedTracks: [Track] = []
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
                        authenticatedContent
                    }
                    
                    if appleMusicService.isAuthorized {
                        RecentlyPlayedSection(
                            tracks: recentlyPlayedTracks,
                            isLoading: isLoadingRecentlyPlayed
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Scrobbit")
            .task {
                await loadUserInfoIfNeeded()
                await fetchRecentlyPlayedIfNeeded()
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet()
            }
            .onChange(of: appleMusicService.isAuthorized) { oldValue, newValue in
                if !oldValue && newValue {
                    Task {
                        await fetchRecentlyPlayedIfNeeded()
                    }
                }
            }
        }
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private var authenticatedContent: some View {
        if let userInfo = lastFmService.userInfo {
            StatsGrid(userInfo: userInfo)
        } else if isLoadingUserInfo {
            StatsGridSkeleton()
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
            print("Failed to load user info: \(error)")
        }
    }
    
    // MARK: - Fetch Recently Played
    
    private func fetchRecentlyPlayedIfNeeded() async {
        guard appleMusicService.isAuthorized else { return }
        
        isLoadingRecentlyPlayed = true
        defer { isLoadingRecentlyPlayed = false }
        
        do {
            recentlyPlayedTracks = try await appleMusicService.fetchRecentlyPlayed()
        } catch {
            print("Failed to fetch recently played: \(error)")
        }
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
