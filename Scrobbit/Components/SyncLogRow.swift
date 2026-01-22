import SwiftUI

struct SyncLogRow: View {
    let entry: SyncLogEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: Theme.Size.iconSmall))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("\(entry.scrobblesCount) track\(entry.scrobblesCount == 1 ? "" : "s") scrobbled")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Source indicator
                    HStack(spacing: 2) {
                        Image(systemName: entry.source.iconName)
                            .font(.caption2)
                        Text(entry.source.displayText)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
                }

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
