import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    @Environment(\.scrobbleService) private var scrobbleService
    
    @Query(sort: \ScrobbledTrack.scrobbledAt, order: .reverse)
    private var recentScrobbles: [ScrobbledTrack]
    
    @State private var isLoadingUserInfo = false
    @State private var showConnectSheet = false
    
    /// Limit recent scrobbles shown on home view
    private var displayedScrobbles: [ScrobbledTrack] {
        Array(recentScrobbles.prefix(10))
    }
    
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
                    
                    if isFullyConnected {
                        scrobbleButton
                    }
                    
                    if lastFmService.isAuthenticated {
                        RecentlyPlayedSection(
                            scrobbles: displayedScrobbles,
                            isLoading: scrobbleService?.isSyncing ?? false
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Scrobbit")
            .task {
                await loadUserInfoIfNeeded()
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet()
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
    
    // MARK: - Scrobble Button
    
    private var scrobbleButton: some View {
        Button {
            Task {
                await scrobbleService?.performSync()
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if scrobbleService?.isSyncing == true {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(scrobbleService?.isSyncing == true ? "Scrobbling..." : "Scrobble Now")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .fill(Theme.Colors.accent)
            )
        }
        .disabled(scrobbleService?.isSyncing == true)
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
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
        .modelContainer(for: ScrobbledTrack.self, inMemory: true)
}
