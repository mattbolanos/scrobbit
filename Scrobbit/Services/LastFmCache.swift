import Foundation

/// Manages persistent caching of Last.fm data in UserDefaults for instant app startup.
enum LastFmCache {
    private enum Keys {
        static let userInfo = "lastfm_cached_user_info"
        static let recentScrobbles = "lastfm_cached_recent_scrobbles"
    }

    // MARK: - User Info

    static func saveUserInfo(_ user: LastFmUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Keys.userInfo)
        }
    }

    static func loadUserInfo() -> LastFmUser? {
        guard let data = UserDefaults.standard.data(forKey: Keys.userInfo) else {
            return nil
        }
        return try? JSONDecoder().decode(LastFmUser.self, from: data)
    }

    // MARK: - Recent Scrobbles

    static func saveRecentScrobbles(_ scrobbles: [LastFmScrobble]) {
        if let data = try? JSONEncoder().encode(scrobbles) {
            UserDefaults.standard.set(data, forKey: Keys.recentScrobbles)
        }
    }

    static func loadRecentScrobbles() -> [LastFmScrobble]? {
        guard let data = UserDefaults.standard.data(forKey: Keys.recentScrobbles) else {
            return nil
        }
        return try? JSONDecoder().decode([LastFmScrobble].self, from: data)
    }

    // MARK: - Clear All

    /// Clears all cached Last.fm data. Call on sign out.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: Keys.userInfo)
        UserDefaults.standard.removeObject(forKey: Keys.recentScrobbles)
    }
}
