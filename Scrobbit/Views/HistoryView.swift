import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.scrobbleService) private var scrobbleService
    @Environment(LastFmService.self) private var lastFmService
    
    @Query(filter: #Predicate<Track> { $0.scrobbleID != nil }, sort: \Track.scrobbledAt, order: .reverse)
    private var scrobbles: [Track]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    if scrobbles.isEmpty {
                        emptyState
                    } else {
                        scrobbleList
                    }
                }
                .padding()
            }
            .navigationTitle("History")
            .contentMargins(.top, -Theme.Spacing.md)
            .refreshable {
                await scrobbleService?.performSync()
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Scrobbles Yet", systemImage: "music.note.list")
        } description: {
            if lastFmService.isAuthenticated {
                Text("Your scrobble history will appear here once you start playing music.")
            } else {
                Text("Connect your Last.fm account to see your scrobble history.")
            }
        }
    }
    
    private var scrobbleList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(scrobbles.enumerated()), id: \.element.id) { index, scrobble in
                TrackRow(
                    songName: scrobble.title,
                    artistName: scrobble.artistName,
                    albumName: scrobble.albumTitle,
                    artworkURL: scrobble.artworkURL,
                    playedAt: scrobble.scrobbledAt
                )
                    .padding(.horizontal, Theme.Spacing.xxs)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.top, index == 0 ? -Theme.Spacing.sm : 0)
                    .padding(.bottom, index == scrobbles.count - 1 ? -Theme.Spacing.sm : 0)
                
                if index < scrobbles.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

#Preview {
    HistoryView()
        .environment(LastFmService())
}
