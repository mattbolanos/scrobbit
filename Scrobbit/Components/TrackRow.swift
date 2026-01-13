import SwiftUI
import Foundation

struct TrackRow: View {
    let songName: String
    let artistName: String
    let albumName: String
    let artworkURL: URL?
    let artworkImage: UIImage?
    let playedAt: Date?
    
    init(
        songName: String,
        artistName: String,
        albumName: String,
        artworkURL: URL? = nil,
        artworkImage: UIImage? = nil,
        playedAt: Date?
    ) {
        self.songName = songName
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.artworkImage = artworkImage
        self.playedAt = playedAt
    }
    
    private var formattedPlayTime: String? {
        guard let playTime = playedAt else { return nil }
        let now = Date()
        let timeInterval = now.timeIntervalSince(playTime)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) \(minutes == 1 ? "min" : "mins") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd HH:mm"
            return formatter.string(from: playTime)
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Album artwork - prefer local image, fallback to URL
            artworkView
                .frame(width: Theme.Size.artwork, height: Theme.Size.artwork)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous))
            
            // Track info
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(songName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(artistName) · \(albumName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play time
            if let playTime = formattedPlayTime {
                Text(playTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
    
    @ViewBuilder
    private var artworkView: some View {
        if let image = artworkImage {
            // Local UIImage from MediaPlayer
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = artworkURL {
            // Remote URL from Last.fm
            AsyncImage(url: url) { phase in
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
        } else {
            artworkPlaceholder
        }
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
        TrackRow(
            songName: "Blinding Lights",
            artistName: "The Weeknd",
            albumName: "After Hours",
            artworkURL: nil,
            playedAt: Date().addingTimeInterval(-300)
        )
        
        Divider()
        
        TrackRow(
            songName: "Save Your Tears",
            artistName: "The Weeknd",
            albumName: "After Hours",
            artworkURL: nil,
            playedAt: Date().addingTimeInterval(-7200)
        )
    }
    .padding()
}
