import SwiftUI

/// Displays a detailed history of sync executions.
struct SyncLogView: View {
    @State private var entries: [SyncLogEntry] = []

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyStateView
                    .padding(.top, Theme.Spacing.xxl)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            SyncLogRow(entry: entry)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                                .padding(.bottom, index == entries.count - 1 ? -Theme.Spacing.sm : 0)

                            if index < entries.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sync History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    SyncLog.shared.clear()
                    entries = []
                }
                .disabled(entries.isEmpty)
            }
        }
        .onAppear {
            // Only show entries that actually scrobbled something
            entries = SyncLog.shared.fetchEntries().filter { $0.scrobblesCount > 0 }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No Sync History")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Syncs with scrobbles will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        SyncLogView()
    }
}
