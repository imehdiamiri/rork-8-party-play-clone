import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import UIKit

@MainActor
final class OAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        currentAnchor()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        currentAnchor()
    }

    private func currentAnchor() -> ASPresentationAnchor {
        let scenes: [UIWindowScene] = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow: UIWindow? = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        return keyWindow ?? ASPresentationAnchor()
    }
}

@MainActor
final class SupabaseAuthService: NSObject {
    private let service: SupabaseService
    private let presentationProvider: OAuthPresentationProvider
    private var authSession: ASWebAuthenticationSession?
    private var authStateTask: Task<Void, Never>?
    private var appleSignInContinuation: CheckedContinuation<AuthAccount, Error>?
    private var appleNonce: String?

    init(service: SupabaseService = .shared) {
        self.service = service
        self.presentationProvider = OAuthPresentationProvider()
        super.init()
    }

    deinit {
        authStateTask?.cancel()
    }

    func startAuthListener(onChange: @escaping @MainActor (Session?) -> Void) {
        authStateTask?.cancel()
        authStateTask = Task {
            for await (_, session) in service.client.auth.authStateChanges {
                onChange(session)
            }
        }
    }

    func restoreSession() async -> Session? {
        try? await service.client.auth.session
    }

    func signUp(username: String, password: String) async throws -> AuthAccount {
        let normalizedUsername: String = try normalize(username: username)
        let email: String = email(for: normalizedUsername)
        let response = try await service.client.auth.signUp(email: email, password: password)
        let user = try resolvedUser(from: response.user)
        return AuthAccount(id: user.id, username: normalizedUsername, email: user.email, provider: .username)
    }

    func signIn(username: String, password: String) async throws -> AuthAccount {
        let normalizedUsername: String = try normalize(username: username)
        let email: String = email(for: normalizedUsername)
        let response = try await service.client.auth.signIn(email: email, password: password)
        let user = response.user
        return AuthAccount(id: user.id, username: normalizedUsername, email: user.email, provider: .username)
    }

    func signInWithGoogle() async throws -> AuthAccount {
        let callbackURL: URL = try await startOAuthSession()
        let session = try await handleOAuthCallback(url: callbackURL)
        let fallbackUsername: String = session.user.email?.components(separatedBy: "@").first ?? "PartyPlayer"
        return AuthAccount(id: session.user.id, username: fallbackUsername, email: session.user.email, provider: .google)
    }

    func signInWithApple() async throws -> AuthAccount {
        try await withCheckedThrowingContinuation { continuation in
            appleSignInContinuation = continuation

            let nonce: String = randomNonce()
            appleNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = presentationProvider
            controller.performRequests()
        }
    }

    func handleOAuthCallback(url: URL) async throws -> Session {
        try await service.client.auth.session(from: url)
    }

    func signOut() async throws {
        authSession?.cancel()
        authSession = nil
        try await service.client.auth.signOut()
    }

    private func startOAuthSession() async throws -> URL {
        let url: URL = try service.client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: SupabaseConfiguration.callbackURL
        )

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: SupabaseConfiguration.callbackScheme
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SupabaseError.invalidResponse)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = presentationProvider
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            let started: Bool = session.start()
            if !started {
                authSession = nil
                continuation.resume(throwing: SupabaseError.invalidResponse)
            }
        }
    }

    private func normalize(username: String) throws -> String {
        let trimmed: String = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SupabaseError.invalidUsername
        }
        return trimmed.lowercased()
    }

    private func email(for username: String) -> String {
        "\(username)@partygames.app"
    }

    private func resolvedUser(from user: User?) throws -> User {
        guard let user else {
            throw SupabaseError.invalidResponse
        }
        return user
    }

    private func completeAppleSignIn(with result: Result<AuthAccount, Error>) {
        appleNonce = nil
        guard let continuation = appleSignInContinuation else { return }
        appleSignInContinuation = nil
        continuation.resume(with: result)
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let bytes: [UInt8] = (0..<length).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension SupabaseAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                completeAppleSignIn(with: .failure(SupabaseError.invalidResponse))
                return
            }

            do {
                let session = try await service.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                let fallbackUsername: String = credential.fullName?.givenName ?? session.user.email?.components(separatedBy: "@").first ?? "ApplePlayer"
                completeAppleSignIn(with: .success(AuthAccount(id: session.user.id, username: fallbackUsername, email: session.user.email, provider: .apple)))
            } catch {
                completeAppleSignIn(with: .failure(error))
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            completeAppleSignIn(with: .failure(error))
        }
    }
}
