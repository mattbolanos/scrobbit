import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService

    @State private var lastSyncEntry: BackgroundTaskLogEntry?

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Accounts Section
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

                // MARK: - Background Sync Section
                Section {
                    NavigationLink {
                        BackgroundSyncLogView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Background Sync")
                                    .font(.body)

                                if let entry = lastSyncEntry {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: entry.event.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(entry.event.isSuccess ? .green : .red)
                                            .font(.caption)

                                        Text(entry.event.displayText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text("·")
                                            .foregroundStyle(.tertiary)

                                        Text(entry.timestamp, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("No syncs yet")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }
                } header: {
                    Text("Sync Status")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .contentMargins(.top, Theme.Spacing.md)
            .onAppear {
                lastSyncEntry = BackgroundTaskLog.shared.lastEntry
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
