import SwiftUI

struct BackgroundSyncLogRow: View {
    let entry: BackgroundTaskLogEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: Theme.Size.iconSmall))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(entry.scrobblesCount) track\(entry.scrobblesCount == 1 ? "" : "s") scrobbled")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let message = entry.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}
