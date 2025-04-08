import Foundation
import UIKit

enum AppMode {
    case calculator
    case realApp
}

class ModeController {
    static let shared = ModeController()
    
    // 当前应用模式
    private var currentMode: AppMode = .calculator
    
    // 保存模式信息的UserDefaults键
    private let modeKey = "app_display_mode"
    private let serverCheckTimeKey = "last_server_check_time"
    
    // 服务器检查的URL
    private let serverCheckURL = "https://uni.cloudmantoub.online/api.php/check_mode"
    
    private init() {
        // 从本地存储加载上次的模式
        if let savedMode = UserDefaults.standard.string(forKey: modeKey),
           savedMode == "realApp" {
            currentMode = .realApp
        } else {
            currentMode = .calculator
        }
    }
    
    // 获取当前模式
    func getCurrentMode() -> AppMode {
        return currentMode
    }
    
    // 设置当前模式
    func setMode(_ mode: AppMode) {
        currentMode = mode
        
        // 保存到本地存储
        UserDefaults.standard.set(mode == .realApp ? "realApp" : "calculator", forKey: modeKey)
        
        // 发送通知，告知应用需要切换模式
        NotificationCenter.default.post(name: NSNotification.Name("AppModeSwitched"), object: nil)
    }
    
    // 应用启动时立即检查服务器模式
    func checkInitialServerMode(completion: @escaping () -> Void) {
        checkServerForMode { [weak self] success in
            // 即使检查失败，我们也继续启动应用，使用本地存储的模式
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // 检查服务器以确定应用模式
    func checkServerForMode(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: serverCheckURL) else {
            completion(false)
            return
        }
        
        // 记录最后检查时间
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: serverCheckTimeKey)
        
        // 创建一个独特的设备标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体，包含设备信息
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "current_mode": currentMode == .realApp ? "realApp" : "calculator"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            completion(false)
            return
        }
        
        // 执行网络请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modeString = json["mode"] as? String {
                    let newMode: AppMode = modeString == "realApp" ? .realApp : .calculator
                    
                    // 如果模式改变了，更新并通知
                    if newMode != self.currentMode {
                        DispatchQueue.main.async {
                            self.setMode(newMode)
                        }
                    }
                    
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                print("Error parsing response: \(error)")
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // 检查是否应该执行服务器检查（防止过于频繁的请求）
    func shouldCheckServer() -> Bool {
        let lastCheckTime = UserDefaults.standard.double(forKey: serverCheckTimeKey)
        let currentTime = Date().timeIntervalSince1970
        
        // 如果上次检查时间超过1小时，则应该再次检查
        return (currentTime - lastCheckTime) > 3600
    }
    
    // 特定计算器输入序列触发模式切换
    func checkSpecialSequence(_ sequence: String) -> Bool {
        // 定义一个特殊序列，例如 "1234567890="
        let specialSequence = "1234567890="
        
        if sequence == specialSequence {
            // 本地切换模式（在没有网络连接的情况下使用）
            setMode(currentMode == .calculator ? .realApp : .calculator)
            return true
        }
        
        return false
    }
} 
