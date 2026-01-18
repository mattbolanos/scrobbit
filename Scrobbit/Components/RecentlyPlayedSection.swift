import SwiftUI

struct RecentlyPlayedSection: View {
    let tracks: [any DisplayableTrack]
    let title: String
    let emptyMessage: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.title2.weight(.bold))
            
            if isLoading && tracks.isEmpty {
                recentlyPlayedLoadingView
            } else if tracks.isEmpty {
                recentlyPlayedEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                        TrackRow(
                            songName: track.displayTitle,
                            artistName: track.displayArtist,
                            albumName: track.displayAlbum,
                            artworkURL: track.displayArtworkURL,
                            artworkImage: track.displayArtworkImage,
                            playedAt: track.displayDate
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                        .padding(.bottom, index == tracks.count - 1 ? -Theme.Spacing.sm : 0)
                        .transition(.opacity.combined(with: .move(edge: .top)))

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
                .animation(Theme.Animation.standard, value: tracks.count)
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
            
            Text(emptyMessage)
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


#Preview {
    RecentlyPlayedSection(
        tracks: [
            LastFmScrobble(
                trackName: "Sample Track",
                artistName: "Sample Artist",
                albumName: "Sample Album",
                scrobbledAt: Date(),
                artworkURL: nil,
                lastFmURL: nil
            )
        ],
        title: "Latest from Last.fm",
        emptyMessage: "No scrobbles found",
        isLoading: false
    )
    .padding()
}
