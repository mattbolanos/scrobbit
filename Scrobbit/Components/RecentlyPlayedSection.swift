import SwiftUI

struct RecentlyPlayedSection: View {
    let tracks: [Track]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recently Played")
                .font(.title2.weight(.bold))
            
            if isLoading {
                recentlyPlayedLoadingView
            } else if tracks.isEmpty {
                recentlyPlayedEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                            .padding(.bottom, index == tracks.count - 1 ? -Theme.Spacing.sm : 0)
                        
                        if index < tracks.count - 1 {
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
            
            Text("No recently played tracks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    RecentlyPlayedSection(
        tracks: [
            Track(
                id: "1",
                title: "Blinding Lights",
                artistName: "The Weeknd",
                albumTitle: "After Hours",
                duration: 203,
                lastPlayedDate: Date(),
                artworkURL: nil,
                url: nil,
                contentRating: nil,
                genreNames: nil
            ),
            Track(
                id: "2",
                title: "Save Your Tears",
                artistName: "The Weeknd",
                albumTitle: "After Hours",
                duration: 185,
                lastPlayedDate: Date(),
                artworkURL: nil,
                url: nil,
                contentRating: nil,
                genreNames: nil
            )
        ],
        isLoading: false
    )
    .padding()
}

