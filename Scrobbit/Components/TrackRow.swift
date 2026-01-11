import SwiftUI
import Foundation

struct TrackRow: View {
    let songName: String
    let artistName: String
    let albumName: String
    let artworkURL: URL?
    let playedAt: Date?
    
    private var formattedPlayTime: String? {
        guard let playTime = playedAt else { return nil }
        let now = Date()
        let timeInterval = now.timeIntervalSince(playTime)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) mins ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hours ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd HH:mm"
            return formatter.string(from: playTime)
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Album artwork
            AsyncImage(url: artworkURL) { phase in
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
