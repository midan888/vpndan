import Foundation
import Security

enum KeychainService {
    private static let accessTokenKey = "com.vpngod.accessToken"
    private static let refreshTokenKey = "com.vpngod.refreshToken"
    private static let userEmailKey = "com.vpngod.userEmail"

    // MARK: - Token Management

    static func saveTokens(access: String, refresh: String) {
        save(key: accessTokenKey, value: access)
        save(key: refreshTokenKey, value: refresh)
    }

    static func getAccessToken() -> String? {
        load(key: accessTokenKey)
    }

    static func getRefreshToken() -> String? {
        load(key: refreshTokenKey)
    }

    static func clearTokens() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
        delete(key: userEmailKey)
    }

    // MARK: - Email Management

    static func saveEmail(_ email: String) {
        save(key: userEmailKey, value: email)
    }

    static func getEmail() -> String? {
        load(key: userEmailKey)
    }

    // MARK: - Keychain Operations

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
