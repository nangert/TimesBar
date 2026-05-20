import Foundation
import Security

struct TokenStore {
    static let defaultService = "bar.times.token"
    let service: String

    init(service: String = TokenStore.defaultService) {
        self.service = service
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    /// Returns `true` if Keychain accepted the write. Callers should NOT
    /// report "saved" to the user without checking — silent failures here
    /// previously left the app in a state where it claimed the token was
    /// stored but read() returned nil on next launch.
    @discardableResult
    func save(_ token: String) -> Bool {
        let data = Data(token.utf8)
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("TimesBar: Keychain save failed (OSStatus \(status))")
            return false
        }
        return true
    }

    func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
