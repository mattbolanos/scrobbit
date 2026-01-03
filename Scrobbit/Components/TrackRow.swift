import SwiftUI

struct TrackRow: View {
    let track: Track
    
    private var formattedDuration: String? {
        guard let duration = track.duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Album artwork
            AsyncImage(url: track.artworkURL) { phase in
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
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(track.artistName) · \(track.albumTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            if let duration = formattedDuration {
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
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
    VStack(spacing: 0) {
        TrackRow(track: Track(
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
        ))
        
        Divider()
        
        TrackRow(track: Track(
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
        ))
    }
    .padding()
}

