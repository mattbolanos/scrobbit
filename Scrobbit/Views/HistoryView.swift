import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.scrobbleService) private var scrobbleService
    @Environment(LastFmService.self) private var lastFmService
    
    @Query(sort: \ScrobbledTrack.scrobbledAt, order: .reverse)
    private var scrobbles: [ScrobbledTrack]
    
    var body: some View {
        NavigationStack {
            Group {
                if scrobbles.isEmpty {
                    emptyState
                } else {
                    scrobbleList
                }
            }
            .navigationTitle("History")
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
        List {
            ForEach(groupedScrobbles, id: \.date) { group in
                Section {
                    ForEach(group.scrobbles) { scrobble in
                        ScrobbledTrackRow(scrobble: scrobble)
                    }
                } header: {
                    Text(group.date, style: .date)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Grouping
    
    private var groupedScrobbles: [ScrobbleGroup] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: scrobbles) { scrobble in
            calendar.startOfDay(for: scrobble.scrobbledAt)
        }
        
        return grouped
            .map { ScrobbleGroup(date: $0.key, scrobbles: $0.value) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Scrobble Group

private struct ScrobbleGroup {
    let date: Date
    let scrobbles: [ScrobbledTrack]
}

// MARK: - Scrobbled Track Row

struct ScrobbledTrackRow: View {
    let scrobble: ScrobbledTrack
    
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

// MARK: - Environment Key

struct ScrobbleServiceKey: EnvironmentKey {
    static let defaultValue: ScrobbleService? = nil
}

extension EnvironmentValues {
    var scrobbleService: ScrobbleService? {
        get { self[ScrobbleServiceKey.self] }
        set { self[ScrobbleServiceKey.self] = newValue }
    }
}

#Preview {
    HistoryView()
        .environment(LastFmService())
}

