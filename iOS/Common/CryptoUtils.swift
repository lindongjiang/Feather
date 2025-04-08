import Foundation
import CommonCrypto

class CryptoUtils {
    static let shared = CryptoUtils()
    
    private let key: [UInt8]
    private let algorithm = CCAlgorithm(kCCAlgorithmAES)
    private let options = CCOptions(kCCOptionPKCS7Padding)
    
    private init() {
        // 从Keychain获取密钥
        if let keyString = KeychainManager.shared.getEncryptionKey() {
            // 将十六进制字符串转换为字节数组
            key = keyString.hexToBytes()
        } else {
            // 如果Keychain中没有密钥，使用与后端相同的密钥
            let defaultKey = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"
            key = defaultKey.hexToBytes()
            // 保存到Keychain
            KeychainManager.shared.saveEncryptionKey(defaultKey)
        }
    }
    
    // 解密数据
    func decrypt(encryptedData: String, iv: String) -> String? {
        guard let encryptedBytes = Data(hexString: encryptedData)?.bytes,
              let ivBytes = Data(hexString: iv)?.bytes else {
            return nil
        }
        
        var decryptedBytes = [UInt8](repeating: 0, count: encryptedBytes.count)
        var decryptedLength = 0
        
        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            algorithm,
            options,
            key,
            key.count,
            ivBytes,
            encryptedBytes,
            encryptedBytes.count,
            &decryptedBytes,
            decryptedBytes.count,
            &decryptedLength
        )
        
        if status == kCCSuccess {
            let decryptedData = Data(bytes: decryptedBytes, count: decryptedLength)
            return String(data: decryptedData, encoding: .utf8)
        }
        
        return nil
    }
}

// Keychain管理类
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.mantou.app"
    private let account = "encryption_key"
    
    private init() {}
    
    func getEncryptionKey() -> String? {
        let query: [String: Any] = [
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
    
    func saveEncryptionKey(_ key: String) {
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

// 字符串扩展：十六进制字符串转字节数组
extension String {
    func hexToBytes() -> [UInt8] {
        var bytes = [UInt8]()
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2)
            let hexString = String(self[index..<nextIndex])
            if let byte = UInt8(hexString, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        return bytes
    }
}

// Data扩展
extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
    
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        for i in 0..<length {
            let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let end = hexString.index(start, offsetBy: 2)
            let bytes = hexString[start..<end]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
} 