import SwiftUI

struct StatsGrid: View {
    let userInfo: LastFmUser
    
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var stats: [(title: String, icon: String, value: Int)] {
        [
            (title: "Scrobbles", icon: "waveform", value: userInfo.playcountInt),
            (title: "Artists", icon: "music.microphone", value: userInfo.artistCountInt),
            (title: "Albums", icon: "music.note.square.stack.fill", value: userInfo.albumCountInt),
            (title: "Tracks", icon: "music.note.list", value: userInfo.trackCountInt)
        ]
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(stats.indices, id: \.self) { index in
                StatCard(
                    title: stats[index].title,
                    value: stats[index].value,
                    icon: stats[index].icon,
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
    
    private let stats: [(title: String, icon: String)] = [
        (title: "Scrobbles", icon: "waveform"),
        (title: "Artists", icon: "music.microphone"),
        (title: "Albums", icon: "music.note.square.stack.fill"),
        (title: "Tracks", icon: "music.note.list")
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(0..<4, id: \.self) { index in
                StatCard(
                    title: stats[index].title,
                    value: 0,
                    icon: stats[index].icon,
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

