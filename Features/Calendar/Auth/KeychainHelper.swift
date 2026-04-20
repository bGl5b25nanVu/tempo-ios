import Foundation
import Security

/// Helper for securely storing OAuth tokens in the iOS Keychain.
enum KeychainHelper {
    private static let service = "com.tempo.app"

    enum Key: String {
        case accessToken = "google_access_token"
        case refreshToken = "google_refresh_token"
        case tokenExpiry = "google_token_expiry"
        case userEmail = "google_user_email"
    }

    // MARK: - Save

    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key) // Remove any existing item first

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Load

    static func load(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: - Delete

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Clear all

    static func clearAll() {
        Key.allCases.forEach { delete($0) }
    }

    private static var allCases: [Key] {
        [.accessToken, .refreshToken, .tokenExpiry, .userEmail]
    }
}
