import SwiftUI

struct ConnectAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService

    /// Called when both accounts become connected, before dismissing
    var onFullyConnected: (() -> Void)?

    private var isFullyConnected: Bool {
        lastFmService.isAuthenticated && appleMusicService.isAuthorized
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Connect Accounts")
                        .font(.title2.weight(.bold))
                    
                    
                    Text("Link your music services to start scrobbling")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.sm)
                
                // Service rows
                VStack(spacing: Theme.Spacing.md) {
                    lastFmRow
                    appleMusicRow
                }
                .padding(.horizontal, Theme.Spacing.xs)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .font(.system(size: Theme.Spacing.lg, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.ultraThickMaterial)
    }
    
    // MARK: - Last.fm Row
    
    private var lastFmRow: some View {
        Button {
            Task {
                try? await lastFmService.authenticate()
                if lastFmService.isAuthenticated && appleMusicService.isAuthorized {
                    onFullyConnected?()
                    dismiss()
                }
            }
        } label: {
            ServiceRow(
                icon: {
                    Image("last-fm")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Theme.Size.iconMedium, height: Theme.Size.iconMedium)
                },
                serviceName: "Last.fm",
                statusText: lastFmService.statusDescription,
                isConnected: lastFmService.isAuthenticated,
                isConnecting: lastFmService.isAuthenticating,
                accentColor: Theme.Colors.accent
            )
        }
        .buttonStyle(.plain)
        .disabled(lastFmService.isAuthenticated || lastFmService.isAuthenticating)
    }
    
    // MARK: - Apple Music Row
    
    private var appleMusicRow: some View {
        Button {
            Task {
                await appleMusicService.requestAuthorization()
                if lastFmService.isAuthenticated && appleMusicService.isAuthorized {
                    onFullyConnected?()
                    dismiss()
                }
            }
        } label: {
            ServiceRow(
                icon: {
                    Image("apple-music")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Theme.Size.iconMedium, height: Theme.Size.iconMedium)
                },
                serviceName: "Apple Music",
                statusText: appleMusicService.statusDescription,
                isConnected: appleMusicService.isAuthorized,
                isConnecting: appleMusicService.isAuthorizing,
                accentColor: Theme.Colors.accent
            )
        }
        .buttonStyle(.plain)
        .disabled(appleMusicService.isAuthorized || appleMusicService.isAuthorizing)
    }
}

#Preview {
    ConnectAccountsSheet()
        .environment(LastFmService())
        .environment(MusicKitService())
}
