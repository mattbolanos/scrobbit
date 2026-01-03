import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Last.fm Row
                    Button {
                        if lastFmService.isAuthenticated {
                            lastFmService.signOut()
                        } else {
                            Task {
                                try? await lastFmService.authenticate()
                            }
                        }
                    } label: {
                        AccountRow(
                            icon: {
                                Image("last-fm")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: Theme.Size.iconMedium, height: Theme.Size.iconMedium)
                            },
                            title: "Last.fm",
                            subtitle: lastFmService.statusDescription,
                            accentColor: Theme.Colors.accent,
                            isConnected: lastFmService.isAuthenticated,
                            isConnecting: lastFmService.isAuthenticating
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(lastFmService.isAuthenticating)
                    
                    // Apple Music Row
                    Button {
                        if appleMusicService.isAuthorized {
                            appleMusicService.disconnect()
                        } else {
                            Task {
                                await appleMusicService.requestAuthorization()
                            }
                        }
                    } label: {
                        AccountRow(
                            icon: {
                                Image("apple-music")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: Theme.Size.iconMedium, height: Theme.Size.iconMedium)
                            },
                            title: "Apple Music",
                            subtitle: appleMusicService.statusDescription,
                            accentColor: Theme.Colors.accent,
                            isConnected: appleMusicService.isAuthorized,
                            isConnecting: appleMusicService.isAuthorizing
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(appleMusicService.isAuthorizing)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    

}

#Preview {
    SettingsView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
