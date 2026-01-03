import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(LastFmService.self) var lastFmService
    
    @State private var isLoadingUserInfo = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !lastFmService.isAuthenticated {
                        connectButton
                    } else {
                        authenticatedContent
                    }
                }
                .padding()
            }
            .navigationTitle(lastFmService.username.isEmpty ? "Scrobbit" : lastFmService.username)
            .task {
                await loadUserInfoIfNeeded()
            }
        }
    }
    
    // MARK: - Connect Button
    
    private var connectButton: some View {
        Button {
            Task {
                try? await lastFmService.authenticate()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.red.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image("last-fm")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading) {
                    Text("Last.fm")
                        .font(.headline)
                    
                    Text(lastFmService.statusDescription)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                colorScheme == .dark ?
                Color.red.opacity(0.2) :
                Color.red.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.red.opacity(0.5), lineWidth: 2)
            )
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
        LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                title: "Scrobbles",
                value: userInfo.playcountInt,
                icon: "music.note",
                color: .red
            )
            
            StatCard(
                title: "Artists",
                value: userInfo.artistCountInt,
                icon: "person.2.fill",
                color: .purple
            )
            
            StatCard(
                title: "Albums",
                value: userInfo.albumCountInt,
                icon: "square.stack.fill",
                color: .blue
            )
            
            StatCard(
                title: "Tracks",
                value: userInfo.trackCountInt,
                icon: "waveform",
                color: .green
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
}

#Preview {
    HomeView()
        .environment(LastFmService())
}
