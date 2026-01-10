import SwiftUI

struct RecentlyPlayedSection: View {
    let scrobbles: [LastFmScrobble]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent Scrobbles")
                .font(.title2.weight(.bold))
            
            if isLoading && scrobbles.isEmpty {
                recentlyPlayedLoadingView
            } else if scrobbles.isEmpty {
                recentlyPlayedEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(scrobbles.enumerated()), id: \.element.id) { index, scrobble in
                        RecentScrobbleRow(scrobble: scrobble)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                            .padding(.bottom, index == scrobbles.count - 1 ? -Theme.Spacing.sm : 0)
                        
                        if index < scrobbles.count - 1 {
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
    
    private var recentlyPlayedLoadingView: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                        .fill(Color(.systemGray5))
                        .frame(width: Theme.Size.artwork, height: Theme.Size.artwork)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(width: 140, height: 14)
                        
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                            .fill(Color(.systemGray6))
                            .frame(width: 100, height: 12)
                    }
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm / 2, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(width: 32, height: 12)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                .padding(.bottom, index == 4 ? -Theme.Spacing.sm : 0)
                
                if index < 4 {
                    Divider()
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shimmering()
    }
    
    private var recentlyPlayedEmptyView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            
            Text("No Last.fm scrobbles found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Your recently played tracks will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Recent Scrobble Row

struct RecentScrobbleRow: View {
    let scrobble: LastFmScrobble
    
    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: scrobble.scrobbledAt, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Album artwork
            AsyncImage(url: scrobble.artworkURL) { phase in
                switch phase {
                case .empty:
                    artworkPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    artworkPlaceholder
                @unknown default:
                    artworkPlaceholder
                }
            }
            .frame(width: Theme.Size.artwork, height: Theme.Size.artwork)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous))
            
            // Track info
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(scrobble.trackName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(scrobble.artistName) · \(scrobble.albumName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Relative time
            Text(relativeTime)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .fill(Theme.Colors.accent.opacity(Theme.Opacity.subtle))
            
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.border))
        }
    }
}

#Preview {
    RecentlyPlayedSection(
        scrobbles: [
            LastFmScrobble(
                trackName: "Sample Track",
                artistName: "Sample Artist",
                albumName: "Sample Album",
                scrobbledAt: Date(),
                artworkURL: nil,
                lastFmURL: nil
            )
        ],
        isLoading: false
    )
    .padding()
}

