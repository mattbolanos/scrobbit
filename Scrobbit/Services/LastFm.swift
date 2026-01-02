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
