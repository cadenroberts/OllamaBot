import Foundation
import Security

final class APIKeyStore {
    static let shared = APIKeyStore()
    
    private let service = "com.ollamabot.apikeys"
    
    private func baseQuery(for providerId: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerId
        ]
    }
    
    func key(for providerId: String) -> String? {
        var query = baseQuery(for: providerId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
    
    @discardableResult
    func setKey(_ key: String?, for providerId: String) -> Bool {
        let query = baseQuery(for: providerId)
        SecItemDelete(query as CFDictionary)
        
        guard let key = key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        
        guard let data = key.data(using: .utf8) else { return false }
        
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func hasKey(for providerId: String) -> Bool {
        key(for: providerId) != nil
    }
}
