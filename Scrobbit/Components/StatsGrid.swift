import SwiftUI

struct StatsGrid: View {
    let userInfo: LastFmUser
    
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var stats: [(title: String, icon: String, color: Color, value: Int)] {
        [
            (title: "Scrobbles", icon: "waveform", color: Theme.Colors.scrobbles, value: userInfo.playcountInt),
            (title: "Artists", icon: "music.microphone", color: Theme.Colors.artists, value: userInfo.artistCountInt),
            (title: "Albums", icon: "music.note.square.stack.fill", color: Theme.Colors.albums, value: userInfo.albumCountInt),
            (title: "Tracks", icon: "music.note.list", color: Theme.Colors.tracks, value: userInfo.trackCountInt)
        ]
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(stats.indices, id: \.self) { index in
                StatCard(
                    title: stats[index].title,
                    value: stats[index].value,
                    icon: stats[index].icon,
                    color: stats[index].color,
                    isSkeleton: false
                )
            }
        }
    }
}

struct StatsGridSkeleton: View {
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]
    
    private let stats: [(title: String, icon: String, color: Color)] = [
        (title: "Scrobbles", icon: "waveform", color: Theme.Colors.scrobbles),
        (title: "Artists", icon: "music.microphone", color: Theme.Colors.artists),
        (title: "Albums", icon: "music.note.square.stack.fill", color: Theme.Colors.albums),
        (title: "Tracks", icon: "music.note.list", color: Theme.Colors.tracks)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(0..<4, id: \.self) { index in
                StatCard(
                    title: stats[index].title,
                    value: 0,
                    icon: stats[index].icon,
                    color: stats[index].color,
                    isSkeleton: true
                )
            }
        }
    }

}

#Preview {
    VStack(spacing: Theme.Spacing.xl) {
        Text("Stats Grid with Data")
            .font(.headline)
        
        StatsGrid(userInfo: LastFmUser(
            name: "testuser",
            playcount: "12345",
            artistCount: "456",
            trackCount: "2345",
            albumCount: "789",
            url: "test",
        ))
        
        Divider()
        
        Text("Stats Grid Loading Skeleton")
            .font(.headline)
        
        StatsGridSkeleton()
    }
    .padding()
}

