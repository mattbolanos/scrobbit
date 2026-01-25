import SwiftUI

struct SyncLogRow: View {
    let entry: SyncLogEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Track count - accent colored number
            HStack(spacing: Theme.Spacing.xs) {
                Text("\(entry.scrobblesCount)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.Colors.accent)
                Text("track\(entry.scrobblesCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Relative timestamp
            Text(entry.timestamp.relativeTimeString)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}
