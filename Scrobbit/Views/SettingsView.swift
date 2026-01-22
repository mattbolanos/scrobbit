import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LastFmService.self) var lastFmService
    @Environment(MusicKitService.self) var appleMusicService

    @State private var lastSyncEntry: SyncLogEntry?
    @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available

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
                    Group {
                        if lastSyncEntry != nil {
                            NavigationLink {
                                SyncLogView()
                            } label: {
                                syncHistoryLabel
                            }
                        } else {
                            syncHistoryLabel
                        }
                    }

                    // Background App Refresh Status
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Background App Refresh")
                                .font(.body)

                            Text(backgroundRefreshStatusText)
                                .font(.caption)
                                .foregroundStyle(backgroundRefreshStatus == .available ? .secondary : .primary)
                        }

                        Spacer()

                        if backgroundRefreshStatus == .available {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                openSettings()
                            } label: {
                                Text("Open Settings")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }

                    if backgroundRefreshStatus != .available {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)

                            Text("Background App Refresh must be enabled for Scrobbit to automatically sync your plays when you're not using the app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                } header: {
                    Text("Background Sync")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .contentMargins(.top, Theme.Spacing.md)
            .onAppear {
                lastSyncEntry = SyncLog.shared.lastEntry
                backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
            }
        }
    }

    private var backgroundRefreshStatusText: String {
        switch backgroundRefreshStatus {
        case .available:
            return "Enabled"
        case .denied:
            return "Disabled for Scrobbit"
        case .restricted:
            return "Restricted on this device"
        @unknown default:
            return "Unknown"
        }
    }

    @ViewBuilder
    private var syncHistoryLabel: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Sync History")
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

                        Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
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

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
        .environment(LastFmService())
        .environment(MusicKitService())
}
