import Foundation

enum Secrets {
    
    /// Last.fm API Key
    static let lastFmApiKey: String = {
        
        guard let infoDictionary = Bundle.main.infoDictionary else {
            fatalError("❌ [Secrets] Info.plist not found")
        }
        
        
        guard let key = infoDictionary["LASTFM_API_KEY"] as? String else {
            fatalError("❌ [Secrets] LASTFM_API_KEY not found in Info.plist")
        }
        
        guard !key.isEmpty, !key.contains("$(") else {
            fatalError("❌ [Secrets] LASTFM_API_KEY not configured (found: '\(key)'). Check your .xcconfig file and ensure it's linked to the target.")
        }
        
        return key
    }()
    
    /// Last.fm API Secret (used for signing requests)
    static let lastFmApiSecret: String = {
        
        guard let infoDictionary = Bundle.main.infoDictionary else {
            fatalError("❌ [Secrets] Info.plist not found")
        }
        
        guard let secret = infoDictionary["LASTFM_API_SECRET"] as? String else {
            fatalError("❌ [Secrets] LASTFM_API_SECRET not found in Info.plist")
        }
        
        guard !secret.isEmpty, !secret.contains("$(") else {
            fatalError("❌ [Secrets] LASTFM_API_SECRET not configured (found: '\(secret)'). Check your .xcconfig file and ensure it's linked to the target.")
        }
        
        return secret
    }()
}

