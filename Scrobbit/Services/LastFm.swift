import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@Observable
final class LastFmService: NSObject {

    private enum Constants {
        static let baseURL = "https://ws.audioscrobbler.com/2.0/"
        static let authURL = "https://www.last.fm/api/auth/"
        static let callbackScheme = "scrobbit"
        static let callbackURL = "scrobbit://callback"
    }

    // MARK: - Properties
    private(set) var isAuthenticated: Bool = false
    private(set) var username: String = ""
    private(set) var isAuthenticating: Bool = false
    private(set) var userInfo: LastFmUser?
    private var sessionKey: String?
    private var webAuthSession: ASWebAuthenticationSession?

    var statusDescription: String {
        if isAuthenticating {
            return "Connecting..."
        } else if isAuthenticated {
            return "@\(username)"
        } else {
            return "Tap to connect"
        }
    }

    // MARK: - Initialization
    override init() {
        super.init()
        loadStoredCredentials()
    }

    @MainActor
    func authenticate() async throws {
        guard !isAuthenticating else {
            // Already authenticating
            return
        }

        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        let apiKey = Secrets.lastFmApiKey
        var components = URLComponents(string: Constants.authURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "cb", value: Constants.callbackURL)
        ]

        guard let authURL = components.url else {
            throw LastFmError.invalidURL 
        }

        let token = try await performWebAuth(url: authURL)

        try await getSession(token: token)
    }

    func signOut() {
        KeychainService.clearAll()
        sessionKey = nil
        username = ""
        isAuthenticated = false
    }
    
    func fetchUserInfo() async throws {
        guard isAuthenticated, !username.isEmpty else {
            throw LastFmError.notAuthenticated
        }
        
        let response: UserInfoResponse = try await fetch(
            method: "user.getInfo",
            params: [("user", username)]
        )
        
        userInfo = response.user
    }
    
    // MARK: - Scrobbling
    
    /// Scrobbles a batch of tracks to Last.fm.
    /// - Parameter tracks: Array of tracks to scrobble
    /// - Returns: The number of tracks successfully accepted by Last.fm
    @discardableResult
    func scrobble(_ tracks: [Track]) async throws -> Int {
        guard isAuthenticated, let sessionKey = sessionKey else {
            throw LastFmError.notAuthenticated
        }
        
        guard !tracks.isEmpty else { return 0 }
        
        // Last.fm allows up to 50 scrobbles per batch
        let batch = Array(tracks.prefix(50))
        
        var params: [(String, String)] = [
            ("method", "track.scrobble"),
            ("api_key", Secrets.lastFmApiKey),
            ("sk", sessionKey)
        ]
        
        // Add indexed parameters for each track
        for (index, track) in batch.enumerated() {
            params.append(("artist[\(index)]", track.artistName))
            params.append(("track[\(index)]", track.title))
            params.append(("album[\(index)]", track.albumTitle))
            
            // Use scrobble time or current time
            let timestamp = track.scrobbledAt ?? Date()
            params.append(("timestamp[\(index)]", String(Int(timestamp.timeIntervalSince1970))))
            
            // Optional: duration in seconds
            if let duration = track.duration {
                params.append(("duration[\(index)]", String(Int(duration))))
            }
        }
        
        let response: ScrobbleResponse = try await post(params: params)
        
        return response.scrobbles.attr.accepted
    }
    
    /// Scrobbles a batch of pending scrobbles to Last.fm.
    /// - Parameter scrobbles: Array of pending scrobbles to submit
    /// - Returns: The number of scrobbles successfully accepted by Last.fm
    @discardableResult
    func scrobble(_ scrobbles: [PendingScrobble]) async throws -> Int {
        guard isAuthenticated, let sessionKey = sessionKey else {
            print("[LastFmService] scrobble failed: not authenticated")
            throw LastFmError.notAuthenticated
        }

        guard !scrobbles.isEmpty else {
            print("[LastFmService] scrobble: empty scrobbles array")
            return 0
        }

        print("[LastFmService] scrobble called with \(scrobbles.count) scrobbles")

        // Last.fm allows up to 50 scrobbles per batch
        let batch = Array(scrobbles.prefix(50))

        var params: [(String, String)] = [
            ("method", "track.scrobble"),
            ("api_key", Secrets.lastFmApiKey),
            ("sk", sessionKey)
        ]

        // Add indexed parameters for each scrobble
        for (index, scrobble) in batch.enumerated() {
            params.append(("artist[\(index)]", scrobble.artistName))
            params.append(("track[\(index)]", scrobble.title))
            params.append(("album[\(index)]", scrobble.albumTitle))
            params.append(("timestamp[\(index)]", String(Int(scrobble.scrobbleAt.timeIntervalSince1970))))
        }

        print("[LastFmService] Calling post() for track.scrobble...")
        let response: ScrobbleResponse = try await post(params: params)
        print("[LastFmService] Response: accepted=\(response.scrobbles.attr.accepted), ignored=\(response.scrobbles.attr.ignored)")

        return response.scrobbles.attr.accepted
    }
    
    /// Fetches the user's recent scrobbles from Last.fm.
    /// - Parameter limit: Maximum number of scrobbles to fetch (default: 50, max: 200)
    /// - Returns: Array of recently scrobbled tracks
    func fetchRecentScrobbles(limit: Int = 50) async throws -> [LastFmScrobble] {
        guard isAuthenticated, !username.isEmpty else {
            throw LastFmError.notAuthenticated
        }
        
        let response: RecentTracksResponse = try await fetch(
            method: "user.getRecentTracks",
            params: [
                ("user", username),
                ("limit", String(min(limit, 200)))
            ]
        )
        
        // Filter out currently playing track (no date) and map to scrobbles
        return response.recenttracks.track.compactMap { track -> LastFmScrobble? in
            // Skip "now playing" tracks that don't have a date
            guard let dateInfo = track.date else { return nil }
            
            return LastFmScrobble(
                trackName: track.name,
                artistName: track.artist.text,
                albumName: track.album.text,
                scrobbledAt: Date(timeIntervalSince1970: TimeInterval(dateInfo.uts) ?? 0),
                artworkURL: track.bestArtworkURL,
                lastFmURL: URL(string: track.url)
            )
        }
    }

    // MARK: - Private Methods
    private func loadStoredCredentials() {
        if let storedSessionKey = KeychainService.get(.sessionKey),
           let storedUsername = KeychainService.get(.username) {
            sessionKey = storedSessionKey
            username = storedUsername
            isAuthenticated = true
        }
    }

    @MainActor
    private func performWebAuth(url: URL) async throws -> String {        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Constants.callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: LastFmError.userCancelled)
                    } else {
                        continuation.resume(throwing: LastFmError.authFailed(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: LastFmError.noToken)
                    return
                }
                
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                    continuation.resume(throwing: LastFmError.noToken)
                    return
                }
                
                continuation.resume(returning: token)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            self.webAuthSession = session

            if !session.start() {
                continuation.resume(throwing: LastFmError.authFailed("Failed to start auth session"))
            }
        }
    }

    private func getSession(token: String) async throws {        
        let apiKey = Secrets.lastFmApiKey
        let apiSecret = Secrets.lastFmApiSecret
        
        let params: [(String, String)] = [
            ("api_key", apiKey),
            ("method", "auth.getSession"),
            ("token", token)
        ]
            
        let signature = generateSignature(params: params, secret: apiSecret)
  
        var components = URLComponents(string: Constants.baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        components.queryItems?.append(URLQueryItem(name: "api_sig", value: signature))
        components.queryItems?.append(URLQueryItem(name: "format", value: "json"))
        
        guard let url = components.url else {
            throw LastFmError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFmError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw LastFmError.requestFailed
        }
        
        // Parse response
        let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
        
        guard let session = sessionResponse.session else {
            if let error = sessionResponse.error {
                throw LastFmError.apiError(code: error, message: sessionResponse.message ?? "Unknown error")
            }
            throw LastFmError.invalidResponse
        }
        
        // Store credentials
        let savedKey = KeychainService.save(session.key, for: .sessionKey)
        let savedUsername = KeychainService.save(session.name, for: .username)
        
        guard savedKey && savedUsername else {
            throw LastFmError.keychainError
        }
        
        // Update state
        sessionKey = session.key
        username = session.name
        isAuthenticated = true
    }
    
    private func generateSignature(params: [(String, String)], secret: String) -> String {
        let sortedParams = params.sorted { $0.0 < $1.0 }
        let signatureBase = sortedParams.map { "\($0.0)\($0.1)" }.joined() + secret
        
        let digest = Insecure.MD5.hash(data: Data(signatureBase.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Percent-encode a string for application/x-www-form-urlencoded
    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        
        // Percent encode, then convert %20 to + for form encoding
        return string
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? string
    }
    
    // MARK: - Generic Fetch
    
    private func fetch<T: Decodable>(
        method: String,
        params: [(String, String)] = [],
        requiresSignature: Bool = false
    ) async throws -> T {
        let apiKey = Secrets.lastFmApiKey
        
        var allParams: [(String, String)] = [
            ("method", method),
            ("api_key", apiKey)
        ]
        allParams.append(contentsOf: params)
        
        var components = URLComponents(string: Constants.baseURL)!
        components.queryItems = allParams.map { URLQueryItem(name: $0.0, value: $0.1) }
        
        if requiresSignature {
            let signature = generateSignature(params: allParams, secret: Secrets.lastFmApiSecret)
            components.queryItems?.append(URLQueryItem(name: "api_sig", value: signature))
        }
        
        components.queryItems?.append(URLQueryItem(name: "format", value: "json"))

        guard let url = components.url else {
            throw LastFmError.invalidURL
        }

        // Use detached task to prevent cancellation from .refreshable
        let (data, response) = try await Task.detached {
            try await URLSession.shared.data(from: url)
        }.value

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFmError.requestFailed
        }

        // Check for API errors in response body first (Last.fm returns 200 even for errors sometimes)
        if let errorResponse = try? JSONDecoder().decode(LastFmAPIError.self, from: data) {
            throw LastFmError.apiError(code: errorResponse.error, message: errorResponse.message)
        }

        guard httpResponse.statusCode == 200 else {
            throw LastFmError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LastFmError.invalidResponse
        }
    }

    // MARK: - Generic POST
    
    private func post<T: Decodable>(params: [(String, String)]) async throws -> T {
        guard let url = URL(string: Constants.baseURL) else {
            throw LastFmError.invalidURL
        }
        
        // Generate signature (required for POST methods) - uses raw values
        let signature = generateSignature(params: params, secret: Secrets.lastFmApiSecret)
        
        // Build form body with proper percent encoding
        var allParams = params
        allParams.append(("api_sig", signature))
        allParams.append(("format", "json"))
        
        let bodyString = allParams
            .map { "\($0.0)=\(percentEncode($0.1))" }
            .joined(separator: "&")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)
        
        // Use detached task to prevent cancellation from .refreshable
        let (data, response) = try await Task.detached {
            try await URLSession.shared.data(for: request)
        }.value

        // Debug: print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("[LastFmService] POST raw response: \(responseString)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFmError.requestFailed
        }

        // Check for API errors in response body first (Last.fm returns 200 even for errors sometimes)
        if let errorResponse = try? JSONDecoder().decode(LastFmAPIError.self, from: data) {
            throw LastFmError.apiError(code: errorResponse.error, message: errorResponse.message)
        }

        guard httpResponse.statusCode == 200 else {
            throw LastFmError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[LastFmService] JSON decode error: \(error)")
            throw LastFmError.invalidResponse
        }
    }
}

private struct LastFmAPIError: Decodable {
    let error: Int
    let message: String
}

private struct SessionResponse: Decodable {
    let session: Session?
    let error: Int?
    let message: String?
    
    struct Session: Decodable {
        let name: String
        let key: String
        let subscriber: Int
    }
}

// MARK: - LastFmUser Models

struct UserInfoResponse: Decodable {
    let user: LastFmUser
}

struct LastFmUser: Decodable {
    let name: String
    let playcount: String
    let artistCount: String
    let trackCount: String
    let albumCount: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case name, playcount, url
        case artistCount = "artist_count"
        case trackCount = "track_count"
        case albumCount = "album_count"
    }
    
    var playcountInt: Int { Int(playcount) ?? 0 }
    var artistCountInt: Int { Int(artistCount) ?? 0 }
    var trackCountInt: Int { Int(trackCount) ?? 0 }
    var albumCountInt: Int { Int(albumCount) ?? 0 }
}

// MARK: - Scrobble Response Models

private struct ScrobbleResponse: Decodable {
    let scrobbles: ScrobblesWrapper
    
    struct ScrobblesWrapper: Decodable {
        let attr: ScrobbleAttr
        
        enum CodingKeys: String, CodingKey {
            case attr = "@attr"
        }
    }
    
    struct ScrobbleAttr: Decodable {
        let accepted: Int
        let ignored: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Last.fm API sometimes returns these as strings, sometimes as ints
            if let intValue = try? container.decode(Int.self, forKey: .accepted) {
                accepted = intValue
            } else {
                let stringValue = try container.decode(String.self, forKey: .accepted)
                accepted = Int(stringValue) ?? 0
            }

            if let intValue = try? container.decode(Int.self, forKey: .ignored) {
                ignored = intValue
            } else {
                let stringValue = try container.decode(String.self, forKey: .ignored)
                ignored = Int(stringValue) ?? 0
            }
        }

        enum CodingKeys: String, CodingKey {
            case accepted, ignored
        }
    }
}

// MARK: - Recent Tracks Response Models

private struct RecentTracksResponse: Decodable {
    let recenttracks: RecentTracks
    
    struct RecentTracks: Decodable {
        let track: [RecentTrack]
    }
    
    struct RecentTrack: Decodable {
        let name: String
        let artist: ArtistInfo
        let album: AlbumInfo
        let url: String
        let date: DateInfo?
        let image: [ImageInfo]
        
        var bestArtworkURL: URL? {
            // Prefer extralarge, then large, then medium
            let preferred = image.first { $0.size == "extralarge" }
                ?? image.first { $0.size == "large" }
                ?? image.first { $0.size == "medium" }
            
            guard let urlString = preferred?.text, !urlString.isEmpty else { return nil }
            return URL(string: urlString)
        }
    }
    
    struct ArtistInfo: Decodable {
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
        }
    }
    
    struct AlbumInfo: Decodable {
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
        }
    }
    
    struct DateInfo: Decodable {
        let uts: String
    }
    
    struct ImageInfo: Decodable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}

// MARK: - Public Scrobble Model

/// A scrobble fetched from Last.fm's API
struct LastFmScrobble: Identifiable {
    let trackName: String
    let artistName: String
    let albumName: String
    let scrobbledAt: Date
    let artworkURL: URL?
    let lastFmURL: URL?
    
    var id: String {
        let timestamp = Int(scrobbledAt.timeIntervalSince1970)
        return "\(artistName)-\(trackName)-\(timestamp)"
    }
}

// MARK: - DisplayableTrack Conformance

extension LastFmScrobble: DisplayableTrack {
    var displayTitle: String { trackName }
    var displayArtist: String { artistName }
    var displayAlbum: String { albumName }
    var displayDate: Date? { scrobbledAt }
    var displayArtworkURL: URL? { artworkURL }
    var displayArtworkImage: UIImage? { nil }  // Last.fm provides URLs, not images
}


extension LastFmService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            fatalError("No window scene available for authentication")
        }
        
        // Return the key window or first window from the scene
        if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        if let firstWindow = windowScene.windows.first {
            return firstWindow
        }
        
        return UIWindow(windowScene: windowScene)
    }
}


enum LastFmError: LocalizedError {
    case invalidURL
    case userCancelled
    case noToken
    case authFailed(String)
    case requestFailed
    case httpError(statusCode: Int)
    case invalidResponse
    case apiError(code: Int, message: String)
    case keychainError
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .userCancelled:
            return "Authentication was cancelled"
        case .noToken:
            return "No authentication token received"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .requestFailed:
            return "Request failed"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .invalidResponse:
            return "Invalid response from Last.fm"
        case .apiError(_, let message):
            return message
        case .keychainError:
            return "Failed to save credentials"
        case .notAuthenticated:
            return "Not authenticated with Last.fm"
        }
    }
}
