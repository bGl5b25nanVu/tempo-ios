import Foundation
import GoogleSignIn
import AuthenticationServices

// MARK: - Configuration

/// OAuth 2.0 configuration for Google Calendar.
/// Replace the client ID and URL scheme with values from your Google Cloud Console project.
enum GoogleCalendarConfig {
    /// The OAuth client ID from Google Cloud Console (iOS type).
    /// Format: `<reverse-domain>.apps.googleusercontent.com`
    static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    /// The URL scheme used for callback during OAuth flow.
    /// Must match what's registered in the app's Info.plist URL Schemes.
    static let urlScheme = "com.tempo.app"

    /// Scopes requested from the user.
    /// https://www.googleapis.com/auth/calendar is the full-read-write scope.
    static let scopes = [
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/calendar.events"
    ]

    /// Convenience: build the callback URL scheme string.
    static var callbackScheme: String { "\(urlScheme)://" }
}

// MARK: - Auth State

/// Represents the current authentication state.
enum GoogleAuthState: Equatable {
    case signedOut
    case signedIn(email: String, accessToken: String)
    case signingIn
    case error(String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

// MARK: - Auth Manager

/// Manages the Google OAuth 2.0 lifecycle: sign-in, token refresh, and sign-out.
@MainActor
final class GoogleCalendarAuth: NSObject, ObservableObject {
    @Published private(set) var state: GoogleAuthState = .signedOut
    @Published private(set) var currentUserEmail: String?

    /// Shared instance for convenience.
    static let shared = GoogleCalendarAuth()

    private var presentationAnchor: ASPresentationAnchor?
    private var currentNonce: String?

    override init() {
        super.init()
        // Attempt silent sign-in on launch if tokens are persisted.
        Task { await attemptSilentSignIn() }
    }

    // MARK: - Public API

    /// Kicks off the Google OAuth 2.0 authorization flow.
    /// - Parameter anchor: The window anchor for the sign-in UI.
    func signIn(anchor: ASPresentationAnchor) async {
        state = .signingIn
        presentationAnchor = anchor

        // Generate a random nonce for PKCE.
        currentNonce = UUID().uuidString

        let config = GIDConfiguration(clientID: GoogleCalendarConfig.clientID)
        config.spoofEndpoint = nil

        do {
            let result = try await GIDSignIn.shared.signIn(
                with: config,
                presenting: anchor,
                hint: nil,
                additionalScopes: GoogleCalendarConfig.scopes
            )

            let accessToken = result.user.accessToken.tokenString
            let email = result.user.profile?.email ?? "unknown"

            // Persist tokens.
            KeychainHelper.save(accessToken, for: .accessToken)
            if let refreshToken = result.user.refreshToken.tokenString {
                KeychainHelper.save(refreshToken, for: .refreshToken)
            }
            // Expiry is typically 1 hour; store approximate timestamp.
            let expiry = Date().addingTimeInterval(3600).timeIntervalSince1970
            KeychainHelper.save(String(Int(expiry)), for: .tokenExpiry)
            KeychainHelper.save(email, for: .userEmail)

            currentUserEmail = email
            state = .signedIn(email: email, accessToken: accessToken)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Attempts silent sign-in using any previously stored refresh token.
    func attemptSilentSignIn() async {
        // Check if we have a stored refresh token.
        guard let refreshToken = KeychainHelper.load(.refreshToken) else {
            state = .signedOut
            return
        }

        state = .signingIn

        // Restore the previous user if available.
        if let email = KeychainHelper.load(.userEmail),
           let storedAccessToken = KeychainHelper.load(.accessToken) {
            // Verify token isn't expired (with a 5-minute buffer).
            if let expiry = Double(KeychainHelper.load(.tokenExpiry) ?? ""),
               Date().timeIntervalSince1970 < expiry - 300 {
                currentUserEmail = email
                state = .signedIn(email: email, accessToken: storedAccessToken)
                return
            }
        }

        // Attempt token refresh via GIDSignIn.
        do {
            let config = GIDConfiguration(clientID: GoogleCalendarConfig.clientID)
            let result = try await GIDSignIn.shared.signIn(
                withPresenting: presentationAnchor ?? ASPresentationAnchor(),
                configuration: config,
                additionalScopes: GoogleCalendarConfig.scopes
            )

            let accessToken = result.user.accessToken.tokenString
            let email = result.user.profile?.email ?? KeychainHelper.load(.userEmail) ?? "unknown"

            KeychainHelper.save(accessToken, for: .accessToken)
            let expiry = Date().addingTimeInterval(3600).timeIntervalSince1970
            KeychainHelper.save(String(Int(expiry)), for: .tokenExpiry)
            KeychainHelper.save(email, for: .userEmail)

            currentUserEmail = email
            state = .signedIn(email: email, accessToken: accessToken)
        } catch {
            // Refresh failed — clear credentials and return to signed-out.
            signOut()
        }
    }

    /// Returns a valid access token, refreshing if necessary.
    /// Returns `nil` if the user is not signed in or refresh fails.
    func getValidAccessToken() async -> String? {
        guard case .signedIn(_, let token) = state else {
            await attemptSilentSignIn()
            if case .signedIn(_, let token) = state { return token }
            return nil
        }
        return token
    }

    /// Signs the user out and clears all stored credentials.
    func signOut() {
        GIDSignIn.shared.signOut()
        KeychainHelper.clearAll()
        currentUserEmail = nil
        state = .signedOut
    }

    // MARK: - URL Handling

    /// Handle the OAuth callback URL. Call this from `onOpenURL` in your App.
    func handleURL(_ url: URL) -> Bool {
        GIDSignIn.shared.handle(url)
    }
}
