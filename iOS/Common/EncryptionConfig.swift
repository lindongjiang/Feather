import Foundation
import Security

class EncryptionConfig {
    static let shared = EncryptionConfig()
    
    // Keychain配置
    private let service = "com.mantou.app"
    private let account = "encryption_key"
    
    private init() {
        // 确保密钥已存储
        if getEncryptionKey() == nil {
            // 这里需要设置您的密钥
            let key = "your-generated-32-byte-key-here"
            saveEncryptionKey(key)
        }
    }
    
    // 获取加密密钥
    func getEncryptionKey() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    // 保存加密密钥
    private func saveEncryptionKey(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
} 