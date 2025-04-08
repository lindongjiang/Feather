import Foundation

class ServerController {
    static let shared = ServerController()
    
    // 服务器基础URL
    private var baseURL = "https://uni.cloudmantoub.online/api.php"
    
    // 私有初始化方法
    private init() {}
    
    // MARK: - 公共方法
    
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
