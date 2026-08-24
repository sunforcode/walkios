import Foundation
import Security
import CryptoKit

protocol AuthSession: AnyObject {
    var isLoggedIn: Bool { get }
    var cacheIdentity: String { get }
    func logout()
}

/// 认证管理器
/// 负责 Token 的读取、保存和持久化（Keychain）
final class AuthManager: AuthSession {
    static let shared = AuthManager()

    private let keychainService = "com.walk.app"
    private let tokenKey = "auth_token"

    private init() {}

    /// 当前认证 Token
    var currentToken: String? {
        get { readTokenFromKeychain() }
        set {
            if let token = newValue {
                saveTokenToKeychain(token)
            } else {
                deleteTokenFromKeychain()
            }
        }
    }

    /// 是否已登录
    var isLoggedIn: Bool {
        return currentToken != nil
    }

    /// 缓存命名空间不保存原始 Token，并随登录身份变化。
    var cacheIdentity: String {
        guard let token = currentToken else { return "anonymous" }
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain 操作

    private func saveTokenToKeychain(_ token: String) {
        let data = Data(token.utf8)

        // 先删除已存在的
        deleteTokenFromKeychain()

        // 添加新 Token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("AuthManager: Keychain save failed with status \(status)")
        }
    }

    private func readTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 清除登录状态
    func logout() {
        deleteTokenFromKeychain()
    }
}
