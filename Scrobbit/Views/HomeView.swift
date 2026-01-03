import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    
    @State private var isLoadingUserInfo = false
    @State private var isLoadingRecentlyPlayed = false
    @State private var recentlyPlayedTracks: [Track] = []
    @State private var showConnectSheet = false
    
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]
    
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
                        connectAccountsButton
                    }
                    
                    if lastFmService.isAuthenticated {
                        authenticatedContent
                    }
                    
                    if appleMusicService.isAuthorized {
                        recentlyPlayedSection
                    }
                }
                .padding()
            }
            .navigationTitle(lastFmService.username.isEmpty ? "Scrobbit" : lastFmService.username)
            .task {
                await loadUserInfoIfNeeded()
                await fetchRecentlyPlayedIfNeeded()
            }
            .sheet(isPresented: $showConnectSheet) {
                ConnectAccountsSheet()
            }
        }
    }
    
    // MARK: - Connect Accounts Button
    
    private var connectAccountsButton: some View {
        Button {
            showConnectSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(Theme.Opacity.medium))
                        .frame(width: Theme.Size.iconContainer, height: Theme.Size.iconContainer)
                    
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: Theme.Size.iconSmall, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Connect Accounts")
                        .font(.headline)
                    
                    Text("Link your music services")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(Theme.Opacity.border), lineWidth: Theme.StrokeWidth.thick)
                        .frame(width: Theme.Size.progressIndicator, height: Theme.Size.progressIndicator)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(connectedCount) / 2.0)
                        .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: Theme.StrokeWidth.thick, lineCap: .round))
                        .frame(width: Theme.Size.progressIndicator, height: Theme.Size.progressIndicator)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(connectedCount)/2")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.footnote.weight(.semibold))
            }
            .actionButtonStyle(color: Theme.Colors.accent, colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private var authenticatedContent: some View {
        if let userInfo = lastFmService.userInfo {
            statsGrid(userInfo: userInfo)
        } else if isLoadingUserInfo {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
    
    // MARK: - Stats Grid
    
    private func statsGrid(userInfo: User) -> some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            StatCard(
                title: "Scrobbles",
                value: userInfo.playcountInt,
                icon: "waveform",
                color: Theme.Colors.scrobbles
            )
            
            StatCard(
                title: "Artists",
                value: userInfo.artistCountInt,
                icon: "music.microphone",
                color: Theme.Colors.artists
            )
            
            StatCard(
                title: "Albums",
                value: userInfo.albumCountInt,
                icon: "music.note.square.stack.fill",
                color: Theme.Colors.albums
            )
            
            StatCard(
                title: "Tracks",
                value: userInfo.trackCountInt,
                icon: "music.note.list",
                color: Theme.Colors.tracks
            )
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
    
    // MARK: - Recently Played Section
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recently Played")
                .font(.title2.weight(.bold))
            
            if isLoadingRecentlyPlayed {
                recentlyPlayedLoadingView
            } else if recentlyPlayedTracks.isEmpty {
                recentlyPlayedEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(recentlyPlayedTracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                            .padding(.bottom, index == recentlyPlayedTracks.count - 1 ? -Theme.Spacing.sm : 0)
                        
                        if index < recentlyPlayedTracks.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }
    
    private var recentlyPlayedLoadingView: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                        .fill(Color(.systemGray5))
                        .frame(width: Theme.Size.artwork, height: Theme.Size.artwork)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(width: 140, height: 14)
                        
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                            .fill(Color(.systemGray6))
                            .frame(width: 100, height: 12)
                    }
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(width: 32, height: 12)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                .padding(.bottom, index == 4 ? -Theme.Spacing.sm : 0)
                
                if index < 4 {
                    Divider()
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shimmering()
    }
    
    private var recentlyPlayedEmptyView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            
            Text("No recently played tracks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
