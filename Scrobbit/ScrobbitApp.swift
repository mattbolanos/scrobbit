import SwiftUI
import SwiftData

@main
struct ScrobbitApp: App {
    @State private var lastFmService = LastFmService()
    @State private var appleMusicService = AppleMusicService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(lastFmService)
                .environment(appleMusicService)
        }
    }
}
