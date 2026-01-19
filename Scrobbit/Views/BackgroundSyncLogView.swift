import SwiftUI
import UIKit

/// Displays a detailed history of background sync executions for debugging.
struct BackgroundSyncLogView: View {
    @State private var entries: [BackgroundTaskLogEntry] = []
    @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available

    var body: some View {
        List {
            if entries.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    ContentUnavailableView(
                        "No Sync History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Background sync events will appear here once they occur.")
                    )

                    if backgroundRefreshStatus != .available {
                        BackgroundRefreshWarningView(status: backgroundRefreshStatus)
                    } else {
                        BackgroundRefreshTipView()
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(entries) { entry in
                    BackgroundSyncLogRow(entry: entry)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sync History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    BackgroundTaskLog.shared.clear()
                    entries = []
                }
                .disabled(entries.isEmpty)
            }
        }
        .onAppear {
            entries = BackgroundTaskLog.shared.fetchEntries()
            backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        }
    }
}

private struct BackgroundSyncLogRow: View {
    let entry: BackgroundTaskLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.system(size: Theme.Size.iconSmall))

                Text(entry.event.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.md) {
                if entry.scrobblesCount > 0 {
                    Label("\(entry.scrobblesCount) scrobbles", systemImage: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let message = entry.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var iconName: String {
        switch entry.event {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .expired:
            return "clock.badge.exclamationmark.fill"
        case .skippedNoNetwork:
            return "wifi.slash"
        case .skippedNotAuthenticated:
            return "person.crop.circle.badge.xmark"
        }
    }

    private var iconColor: Color {
        entry.event.isSuccess ? .green : .red
    }
}

// MARK: - Background Refresh Warning View

private struct BackgroundRefreshWarningView: View {
    let status: UIBackgroundRefreshStatus

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Background App Refresh is Off")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                .fill(Color.orange.opacity(Theme.Opacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                .stroke(Color.orange.opacity(Theme.Opacity.border), lineWidth: Theme.StrokeWidth.thin)
        )
    }

    private var statusMessage: String {
        switch status {
        case .denied:
            return "Background App Refresh is disabled for Scrobbit. Enable it in Settings to automatically sync your plays."
        case .restricted:
            return "Background App Refresh is restricted on this device. Check your device settings or parental controls."
        default:
            return "Background App Refresh needs to be enabled for automatic syncing."
        }
    }
}

// MARK: - Background Refresh Tip View

private struct BackgroundRefreshTipView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Syncs not appearing?")
                    .font(.subheadline)
                    .fontWeight(.medium)
            
            Text("Make sure Background App Refresh is enabled in Settings > General > Background App Refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                .fill(Color.secondary.opacity(Theme.Opacity.ultraLight))
        )
    }
}

#Preview {
    NavigationStack {
        BackgroundSyncLogView()
    }
}
