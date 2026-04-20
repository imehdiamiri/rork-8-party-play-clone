import Foundation
import Supabase

nonisolated enum SupabaseConfiguration {
    static let urlString: String = AppConstants.Supabase.urlString
    static let anonKey: String = AppConstants.Supabase.anonKey
    static let callbackScheme: String = AppConstants.Supabase.callbackScheme
    static let callbackURL: URL = URL(string: "\(AppConstants.Supabase.callbackScheme)://auth/callback")!
}

nonisolated enum SupabaseError: LocalizedError, Sendable {
    case invalidConfiguration
    case invalidUsername
    case notAuthenticated
    case missingRoom
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Supabase is not configured correctly."
        case .invalidUsername:
            return "Enter a valid username to continue."
        case .notAuthenticated:
            return "You need to log in again."
        case .missingRoom:
            return "That room could not be found."
        case .invalidResponse:
            return "The server returned an unexpected response."
        }
    }
}

nonisolated final class SupabaseService: Sendable {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let fallbackURL: URL = URL(string: SupabaseConfiguration.urlString)!
        let resolvedURL: URL = URL(string: SupabaseConfiguration.urlString) ?? fallbackURL
        client = SupabaseClient(
            supabaseURL: resolvedURL,
            supabaseKey: SupabaseConfiguration.anonKey
        )
    }
}
