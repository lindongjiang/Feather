import Foundation

// 注意：此文件使用的globalDeviceUUID变量已在StoreCollectionViewController.swift中声明

class ServerController {
    static let shared = ServerController()
    
    // 服务器基础URL
    private var baseURL = "https://renmai.cloudmantoub.online/api"
    
    // 私有初始化方法
    private init() {
        // 检查加密密钥是否正确
        print("检查加密密钥配置")
        let keyValid = CryptoUtils.shared.checkEncryptionKey()
        if keyValid {
            print("✅ 加密密钥配置正确")
        } else {
            print("⚠️ 加密密钥配置可能有误，请检查前后端密钥是否一致")
            
            // 打印当前密钥的前8个字符（出于安全考虑不打印完整密钥）
            if let key = KeychainManager.shared.getEncryptionKey() {
                print("当前密钥前8位: \(key.prefix(8))...")
            } else {
                print("未找到加密密钥")
            }
        }
    }
    
    // MARK: - 公共方法
    
    // 获取应用列表
    func getAppList(completion: @escaping ([ServerApp]?, String?) -> Void) {
        sendRequest(endpoint: "/client/apps", method: "GET") { success, data, error in
            if success, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["data"] as? [String: Any],
                       let iv = result["iv"] as? String,
                       let encryptedData = result["data"] as? String {
                        
                        print("应用列表 - IV长度: \(iv.count), 加密数据长度: \(encryptedData.count)")
                        
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            print("解密成功 - 解密数据长度: \(decryptedString.count)")
                            
                            if let decryptedData = decryptedString.data(using: .utf8) {
                                do {
                                    let apps = try JSONDecoder().decode([ServerApp].self, from: decryptedData)
                                    completion(apps, nil)
                                } catch {
                                    print("JSON解析失败: \(error.localizedDescription)")
                                    print("解密后的前100个字符: \(String(decryptedString.prefix(100)))")
                                    completion(nil, "JSON解析失败: \(error.localizedDescription)")
                                }
                            } else {
                                completion(nil, "解密后的数据无法转换为UTF-8")
                            }
                        } else {
                            print("解密失败 - IV: \(iv), 加密数据前50个字符: \(String(encryptedData.prefix(50)))")
                            completion(nil, "解密失败")
                        }
                    } else {
                        print("响应格式不正确: \(try JSONSerialization.jsonObject(with: data))")
                        completion(nil, "响应格式不正确")
                    }
                } catch {
                    completion(nil, "解析响应失败: \(error.localizedDescription)")
                }
            } else {
                completion(nil, error)
            }
        }
    }
    
    // 获取应用详情
    func getAppDetail(appId: String, completion: @escaping (AppDetail?, String?) -> Void) {
        // 优先使用全局UDID，如果没有则使用设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let udid = globalDeviceUUID ?? deviceID
        
        let endpoint = "/client/apps/\(appId)?udid=\(udid)"
        print("请求应用详情 - Endpoint: \(endpoint)")
        print("使用的UDID: \(udid)")
        
        sendRequest(endpoint: endpoint, method: "GET") { [self] success, data, error in
            if success, let data = data {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data)
                    print("原始响应: \(jsonObject)")
                    
                    guard let json = jsonObject as? [String: Any],
                          let dataObject = json["data"] as? [String: Any] else {
                        print("响应结构不正确")
                        completion(nil, "响应结构不正确")
                        return
                    }
                    
                    // 检查是否有IV和加密数据
                    guard let iv = dataObject["iv"] as? String,
                          let encryptedData = dataObject["data"] as? String else {
                        print("响应中缺少IV或加密数据")
                        completion(nil, "响应中缺少IV或加密数据")
                        return
                    }
                    
                    // 从响应中直接获取解锁状态
                    let requiresUnlockFromResponse = dataObject["requiresUnlock"] as? Bool ?? false
                    let isUnlockedFromResponse = dataObject["isUnlocked"] as? Bool ?? false
                    
                    print("应用详情 - IV长度: \(iv.count), 加密数据长度: \(encryptedData.count)")
                    
                    // 尝试解密
                    guard let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) else {
                        print("解密失败 - IV: \(iv.prefix(16))..., 加密数据前50个字符: \(encryptedData.prefix(50))...")
                        completion(nil, "解密失败")
                        return
                    }
                    
                    print("解密成功 - 解密数据前100个字符: \(decryptedString.prefix(100))...")
                    print("完整解密数据: \(decryptedString)")
                    
                    // 尝试解析JSON
                    guard let decryptedData = decryptedString.data(using: .utf8) else {
                        print("解密后的数据无法转换为UTF-8")
                        completion(nil, "解密后的数据无法转换为UTF-8")
                        return
                    }
                    
                    // 先使用JSONSerialization尝试解析，验证JSON格式是否有效
                    do {
                        let jsonObj = try JSONSerialization.jsonObject(with: decryptedData, options: [])
                        print("JSON格式验证成功: \(jsonObj)")
                    } catch {
                        print("JSON格式无效: \(error.localizedDescription)")
                        completion(nil, "JSON格式无效: \(error.localizedDescription)")
                        return
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        var appDetail = try decoder.decode(AppDetail.self, from: decryptedData)
                        
                        // 使用服务器直接返回的解锁状态覆盖JSON中的值
                        if requiresUnlockFromResponse {
                            print("从响应中读取requiresUnlock: \(requiresUnlockFromResponse)")
                            appDetail = AppDetail(
                                id: appDetail.id,
                                name: appDetail.name,
                                version: appDetail.version,
                                icon: appDetail.icon,
                                plist: appDetail.plist,
                                pkg: appDetail.pkg,
                                date: appDetail.date,
                                size: appDetail.size,
                                channel: appDetail.channel,
                                build: appDetail.build,
                                identifier: appDetail.identifier,
                                web_icon: appDetail.web_icon,
                                type: appDetail.type,
                                requires_key: appDetail.requires_key,
                                created_at: appDetail.created_at,
                                updated_at: appDetail.updated_at,
                                requiresUnlock: requiresUnlockFromResponse,
                                isUnlocked: isUnlockedFromResponse
                            )
                        }
                        
                        if isUnlockedFromResponse {
                            print("从响应中读取isUnlocked: \(isUnlockedFromResponse)")
                        }
                        
                        print("成功解析应用详情: \(appDetail.name)")
                        print("成功获取应用详情 - 应用名称: \(appDetail.name), 是否需要解锁: \(appDetail.requiresUnlock), 是否已解锁: \(appDetail.isUnlocked)")
                        
                        completion(appDetail, nil)
                    } catch {
                        print("JSON解析失败: \(error.localizedDescription)")
                        print("错误详情: \(error)")
                        print("解密后的数据: \(decryptedString)")
                        
                        // 尝试手动构建AppDetail对象
                        do {
                            if let jsonDict = try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                                let manualAppDetail = self.createAppDetailFromDict(jsonDict, requiresUnlockFromResponse: requiresUnlockFromResponse, isUnlockedFromResponse: isUnlockedFromResponse)
                                if let detail = manualAppDetail {
                                    print("通过手动解析创建AppDetail成功")
                                    print("成功获取应用详情 - 应用名称: \(detail.name), 是否需要解锁: \(detail.requiresUnlock), 是否已解锁: \(detail.isUnlocked)")
                                    completion(detail, nil)
                                    return
                                }
                            }
                        } catch {
                            print("手动解析也失败: \(error.localizedDescription)")
                        }
                        
                        completion(nil, "JSON解析失败: \(error.localizedDescription)")
                    }
                } catch {
                    print("解析响应时出错: \(error.localizedDescription)")
                    completion(nil, "解析响应失败: \(error.localizedDescription)")
                }
            } else {
                print("请求失败: \(error ?? "未知错误")")
                completion(nil, error)
            }
        }
    }
    
    // 手动从字典创建AppDetail对象
    private func createAppDetailFromDict(_ dict: [String: Any], requiresUnlockFromResponse: Bool?, isUnlockedFromResponse: Bool?) -> AppDetail? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String else {
            print("手动解析失败：缺少id或name字段")
            return nil
        }
        
        // 获取其他字段，使用默认值
        let version = dict["version"] as? String ?? "1.0"
        let icon = dict["icon"] as? String ?? ""
        let plist = dict["plist"] as? String
        let pkg = dict["pkg"] as? String
        let date = dict["date"] as? String
        let size = dict["size"] as? Int
        let channel = dict["channel"] as? String
        let build = dict["build"] as? String
        let identifier = dict["identifier"] as? String
        let web_icon = dict["web_icon"] as? String
        let type = dict["type"] as? Int
        let requires_key = dict["requires_key"] as? Int ?? 0
        let created_at = dict["created_at"] as? String
        let updated_at = dict["updated_at"] as? String
        
        // 特别处理requiresUnlock和isUnlocked
        let requiresUnlock = requiresUnlockFromResponse ?? dict["requires_unlock"] as? Bool ?? (requires_key == 1)
        let isUnlocked = isUnlockedFromResponse ?? dict["is_unlocked"] as? Bool ?? false
        
        return AppDetail(
            id: id,
            name: name,
            version: version,
            icon: icon,
            plist: plist,
            pkg: pkg,
            date: date,
            size: size,
            channel: channel,
            build: build,
            identifier: identifier,
            web_icon: web_icon,
            type: type,
            requires_key: requires_key,
            created_at: created_at,
            updated_at: updated_at, 
            requiresUnlock: requiresUnlock,
            isUnlocked: isUnlocked
        )
    }
    
    // 注册设备
    func registerDevice(completion: @escaping (Bool, String?) -> Void) {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "device_model": UIDevice.current.modelName,
            "locale": Locale.current.identifier
        ]
        
        // 发送请求
        sendRequest(endpoint: "/register", method: "POST", body: requestBody) { success, data, error in
            if success, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let status = json["status"] as? String,
                       status == "success" {
                        completion(true, nil)
                    } else {
                        completion(false, "无效响应")
                    }
                } catch {
                    completion(false, "解析响应失败: \(error.localizedDescription)")
                }
            } else {
                completion(false, error)
            }
        }
    }
    
    // 检查应用模式
    func checkAppMode(completion: @escaping (AppMode?, String?) -> Void) {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "current_mode": ModeController.shared.getCurrentMode() == .realApp ? "realApp" : "calculator"
        ]
        
        // 发送请求
        sendRequest(endpoint: "/check_mode", method: "POST", body: requestBody) { success, data, error in
            if success, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let modeString = json["mode"] as? String {
                        let mode: AppMode = modeString == "realApp" ? .realApp : .calculator
                        completion(mode, nil)
                    } else {
                        completion(nil, "无效响应")
                    }
                } catch {
                    completion(nil, "解析响应失败: \(error.localizedDescription)")
                }
            } else {
                completion(nil, error)
            }
        }
    }
    
    // 发送应用状态
    func sendAppStatus(status: String, completion: @escaping (Bool, String?) -> Void) {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "status": status,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        // 发送请求
        sendRequest(endpoint: "/app_status", method: "POST", body: requestBody) { success, data, error in
            if success {
                completion(true, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    // 请求强制模式切换
    func requestModeChange(toMode: AppMode, completion: @escaping (Bool, String?) -> Void) {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "requested_mode": toMode == .realApp ? "realApp" : "calculator"
        ]
        
        // 发送请求
        sendRequest(endpoint: "/request_mode_change", method: "POST", body: requestBody) { success, data, error in
            if success {
                // 本地立即更改模式
                DispatchQueue.main.async {
                    ModeController.shared.setMode(toMode)
                }
                completion(true, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    // 验证卡密
    func verifyCard(cardKey: String, appId: String, completion: @escaping (Bool, String?) -> Void) {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let udid = globalDeviceUUID ?? deviceID
        
        print("开始验证卡密 - 卡密: \(cardKey), 应用ID: \(appId), UDID: \(udid)")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "cardKey": cardKey,
            "udid": udid,
            "appId": appId
        ]
        
        // 发送请求
        sendRequest(endpoint: "/client/verify", method: "POST", body: requestBody) { success, data, error in
            if success, let data = data {
                // 打印原始响应
                print("卡密验证原始响应: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("解析后的JSON: \(json)")
                        
                        let success = json["success"] as? Bool ?? false
                        let message = json["message"] as? String
                        
                        // 检查是否包含plist字段
                        if let plist = json["plist"] as? String {
                            print("收到plist: \(String(plist.prefix(50)))...")
                            
                            // 保存plist，以便后续使用
                            UserDefaults.standard.set(plist, forKey: "last_verified_plist_\(appId)")
                        }
                        
                        if success {
                            print("卡密验证成功: \(message ?? "无消息")")
                        } else {
                            print("卡密验证失败: \(message ?? "未知错误")")
                        }
                        
                        completion(success, message)
                    } else {
                        print("响应不是有效的JSON对象")
                        completion(false, "响应不是有效的JSON对象")
                    }
                } catch {
                    print("JSON解析失败: \(error.localizedDescription)")
                    print("响应数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                    completion(false, "解析响应失败: \(error.localizedDescription)")
                }
            } else {
                print("请求失败: \(error ?? "未知错误")")
                completion(false, error)
            }
        }
    }
    
    // 刷新应用详情（用于卡密验证成功后）
    func refreshAppDetail(appId: String, completion: @escaping (Bool, String?) -> Void) {
        getAppDetail(appId: appId) { appDetail, error in
            if let appDetail = appDetail {
                print("应用详情刷新成功: \(appDetail.name)")
                completion(true, nil)
            } else {
                print("应用详情刷新失败: \(error ?? "未知错误")")
                completion(false, error)
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    private func sendRequest(endpoint: String, method: String, body: [String: Any]? = nil, completion: @escaping (Bool, Data?, String?) -> Void) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(false, nil, "无效URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加请求体
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(false, nil, "创建请求体失败: \(error.localizedDescription)")
                return
            }
        }
        
        // 设置超时时间
        request.timeoutInterval = 10
        
        // 创建任务
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 检查是否有错误
            if let error = error {
                completion(false, nil, "网络错误: \(error.localizedDescription)")
                return
            }
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "无效的HTTP响应")
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(true, data, nil)
            } else {
                completion(false, nil, "HTTP错误: \(httpResponse.statusCode)")
            }
        }
        
        // 启动任务
        task.resume()
    }
}

// 设备型号辅助扩展
extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 简化版本，真实实现可能需要更详细的映射表
        switch identifier {
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,1": return "iPhone 12 mini"
        // 更多型号...
        default: return identifier
        }
    }
}

// 数据模型
struct ServerApp: Codable {
    let id: String
    let name: String
    let date: String?
    let size: Int?
    let channel: String?
    let build: String?
    let version: String
    let identifier: String?
    let pkg: String?
    let icon: String
    let plist: String?
    let web_icon: String?
    let type: Int?
    let requires_key: Int
    let created_at: String?
    let updated_at: String?
    
    var requiresKey: Bool {
        return requires_key == 1
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case size
        case channel
        case build
        case version
        case identifier
        case pkg
        case icon
        case plist
        case web_icon
        case type
        case requires_key
        case created_at
        case updated_at
    }
}

struct AppDetail: Codable {
    let id: String
    let name: String
    let version: String
    let icon: String
    let plist: String?
    let pkg: String?
    let date: String?
    let size: Int?
    let channel: String?
    let build: String?
    let identifier: String?
    let web_icon: String?
    let type: Int?
    let requires_key: Int
    let created_at: String?
    let updated_at: String?
    let requiresUnlock: Bool
    let isUnlocked: Bool
    
    // 手动构造函数
    init(id: String, name: String, version: String, icon: String, plist: String?, pkg: String?, 
         date: String?, size: Int?, channel: String?, build: String?, identifier: String?, 
         web_icon: String?, type: Int?, requires_key: Int, created_at: String?, updated_at: String?,
         requiresUnlock: Bool, isUnlocked: Bool) {
        self.id = id
        self.name = name
        self.version = version
        self.icon = icon
        self.plist = plist
        self.pkg = pkg
        self.date = date
        self.size = size
        self.channel = channel
        self.build = build
        self.identifier = identifier
        self.web_icon = web_icon
        self.type = type
        self.requires_key = requires_key
        self.created_at = created_at
        self.updated_at = updated_at
        self.requiresUnlock = requiresUnlock
        self.isUnlocked = isUnlocked
    }
    
    // 获取解密后的plist URL
    func getDecryptedPlist() -> String? {
        guard let encryptedPlist = plist else { return nil }
        
        // 检查plist是否已经是有效的URL
        if encryptedPlist.hasPrefix("http") {
            return encryptedPlist
        }
        
        // 检查plist是否是加密的JSON数据
        if let data = encryptedPlist.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let iv = json["iv"] as? String,
           let encryptedData = json["data"] as? String,
           let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
            return decryptedString
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, version, icon, plist, pkg
        case date, size, channel, build, identifier
        case web_icon, type, requires_key
        case created_at, updated_at
        case requiresUnlock = "requires_unlock"
        case isUnlocked = "is_unlocked"
    }
    
    // 添加初始化器以提高解析容错性
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 必需字段
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // 可能缺失但需要的字段，提供默认值
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        
        // 可选字段
        plist = try container.decodeIfPresent(String.self, forKey: .plist)
        pkg = try container.decodeIfPresent(String.self, forKey: .pkg)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        build = try container.decodeIfPresent(String.self, forKey: .build)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        web_icon = try container.decodeIfPresent(String.self, forKey: .web_icon)
        type = try container.decodeIfPresent(Int.self, forKey: .type)
        requires_key = try container.decodeIfPresent(Int.self, forKey: .requires_key) ?? 0
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        
        // 解锁状态，如果不存在则根据requires_key推断
        requiresUnlock = try container.decodeIfPresent(Bool.self, forKey: .requiresUnlock) ?? (requires_key == 1)
        isUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isUnlocked) ?? false
    }
} 
