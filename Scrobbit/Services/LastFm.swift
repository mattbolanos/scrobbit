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
    private(set) var userInfo: User?
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
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFmError.requestFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LastFmError.requestFailed
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Check if it's a Last.fm API error
            if let errorResponse = try? JSONDecoder().decode(LastFmAPIError.self, from: data) {
                throw LastFmError.apiError(code: errorResponse.error, message: errorResponse.message)
            }
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

// MARK: - User Info Models

struct UserInfoResponse: Decodable {
    let user: User
}

struct User: Decodable {
    let name: String
    let playcount: String
    let artistCount: String
    let trackCount: String
    let albumCount: String
    let image: [LastFmImage]
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case name, playcount, image, url
        case artistCount = "artist_count"
        case trackCount = "track_count"
        case albumCount = "album_count"
    }
    
    var playcountInt: Int { Int(playcount) ?? 0 }
    var artistCountInt: Int { Int(artistCount) ?? 0 }
    var trackCountInt: Int { Int(trackCount) ?? 0 }
    var albumCountInt: Int { Int(albumCount) ?? 0 }
    
    var largeImageURL: URL? {
        guard let urlString = image.first(where: { $0.size == "extralarge" })?.url ?? image.last?.url else {
            return nil
        }
        return URL(string: urlString)
    }
}

struct LastFmImage: Decodable {
    let size: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case size
        case url = "#text"
    }
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
