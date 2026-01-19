import SwiftUI

/// Displays a detailed history of background sync executions for debugging.
struct BackgroundSyncLogView: View {
    @State private var entries: [BackgroundTaskLogEntry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Sync History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Background sync events will appear here once they occur.")
                )
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

#Preview {
    NavigationStack {
        BackgroundSyncLogView()
    }
}
