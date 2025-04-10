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
            print("使用Keychain中存储的密钥：\(keyString.prefix(8))...")
            print("密钥长度：\(key.count)字节")
        } else {
            // 如果Keychain中没有密钥，使用与后端相同的密钥
            let defaultKey = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"
            key = defaultKey.hexToBytes()
            print("使用默认密钥：\(defaultKey.prefix(8))...")
            print("密钥长度：\(key.count)字节")
            
            // 保存到Keychain
            KeychainManager.shared.saveEncryptionKey(defaultKey)
        }
    }
    
    // 解密数据
    func decrypt(encryptedData: String, iv: String) -> String? {
        print("开始解密 - IV: \(iv.prefix(8))..., 加密数据: \(encryptedData.prefix(16))...")
        
        // 验证输入
        guard !encryptedData.isEmpty, !iv.isEmpty else {
            print("解密失败：加密数据或IV为空")
            return nil
        }
        
        // 确保IV是有效的十六进制字符串
        guard iv.count == 32 else {
            print("IV长度不正确，期望32个字符（16字节），实际：\(iv.count)个字符")
            return nil
        }
        
        // 确保密钥长度正确
        guard key.count == 32 else {
            print("密钥长度不正确，期望32字节，实际：\(key.count)字节")
            return nil
        }
        
        guard let encryptedBytes = Data(hexString: encryptedData)?.bytes else {
            print("解密失败：无法将加密数据转换为字节数组")
            return nil
        }
        
        guard let ivBytes = Data(hexString: iv)?.bytes else {
            print("解密失败：无法将IV转换为字节数组")
            return nil
        }
        
        print("加密数据长度：\(encryptedBytes.count)字节，IV长度：\(ivBytes.count)字节")
        
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
            guard let result = String(data: decryptedData, encoding: .utf8) else {
                print("解密成功但无法将结果转换为UTF-8字符串")
                return nil
            }
            print("解密成功，结果长度：\(result.count)个字符")
            return result
        } else {
            print("CCCrypt失败，状态码：\(status)")
            switch Int32(status) {
            case Int32(kCCParamError):
                print("参数错误")
            case Int32(kCCBufferTooSmall):
                print("缓冲区太小")
            case Int32(kCCMemoryFailure):
                print("内存分配失败")
            case Int32(kCCAlignmentError):
                print("输入大小与块大小不一致")
            case Int32(kCCDecodeError):
                print("输入数据格式错误")
            case Int32(kCCUnimplemented):
                print("算法不可用")
            default:
                print("未知错误")
            }
            return nil
        }
    }
    
    // 验证IV和加密数据格式是否正确
    func validateFormat(encryptedData: String, iv: String) -> (Bool, String) {
        // 验证IV
        if iv.isEmpty {
            return (false, "IV为空")
        }
        
        if iv.count != 32 {
            return (false, "IV长度错误：应为32个字符，实际为\(iv.count)个字符")
        }
        
        // 尝试转换IV为字节数组
        if Data(hexString: iv) == nil {
            return (false, "IV不是有效的十六进制字符串")
        }
        
        // 验证加密数据
        if encryptedData.isEmpty {
            return (false, "加密数据为空")
        }
        
        // 加密数据长度应为偶数
        if encryptedData.count % 2 != 0 {
            return (false, "加密数据长度不是偶数：\(encryptedData.count)")
        }
        
        // 尝试转换加密数据为字节数组
        if Data(hexString: encryptedData) == nil {
            return (false, "加密数据不是有效的十六进制字符串")
        }
        
        return (true, "格式验证通过")
    }
    
    // 测试加密密钥是否正确
    func checkEncryptionKey() -> Bool {
        // 创建一个测试字符串
        let testString = "测试加密密钥"
        print("测试加密密钥 - 原始字符串: \(testString)")
        
        // 创建一个模拟的IV (16字节，转为32个十六进制字符)
        let testIV = "0123456789abcdef0123456789abcdef"
        print("测试IV: \(testIV)")
        
        // 在服务器使用同样的密钥和IV加密的结果 (这个需要从服务器获取)
        // 以下是硬编码的测试数据，实际应用中可以通过API获取
        let serverEncrypted = "7c8f3b7885c2ef0b0f5a6cab79c17dcaabb3bd3f3da4ab968c1548fb21e4dad0"
        
        print("服务器加密结果: \(serverEncrypted)")
        
        // 使用本地密钥和IV尝试解密
        if let decrypted = decrypt(encryptedData: serverEncrypted, iv: testIV) {
            print("解密结果: \(decrypted)")
            return decrypted == testString
        } else {
            print("解密失败")
            return false
        }
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