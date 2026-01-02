import SwiftUI
import SwiftData

@main
struct ScrobbitApp: App {
    @State private var lastFmService = LastFmService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(lastFmService)
        }
    }
}
