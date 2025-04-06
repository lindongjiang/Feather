//
//  AppModeManager.swift
//  mantou
//
//  Created by samara on 6/26/24.
//

import Foundation
import UIKit

// 应用模式枚举
enum AppMode: String, Codable {
    case normal = "normal"      // 正常模式 - 完整功能的应用签名工具
    case disguised = "disguised"   // 伪装模式 - 用于App Store审核的安全模式
}

// 应用模式配置
struct AppModeConfig: Codable {
    var currentMode: AppMode
    var serverCheckEnabled: Bool
    var serverCheckURL: String
    var lastCheckedTimestamp: Date?
    var cacheExpirationInterval: TimeInterval
    
    // 默认配置
    static let `default` = AppModeConfig(
        currentMode: .disguised,  // 默认以伪装模式启动
        serverCheckEnabled: true,
        serverCheckURL: "https://uni.cloudmantoub.online/appmode.json",
        lastCheckedTimestamp: nil,
        cacheExpirationInterval: 3600 // 默认缓存1小时
    )
}

// App模式管理器 - 单例模式
class AppModeManager {
    // 单例
    static let shared = AppModeManager()
    
    // 当前应用模式
    private(set) var currentMode: AppMode {
        didSet {
            if oldValue != currentMode {
                saveConfig()
                // 通知模式变化
                NotificationCenter.default.post(
                    name: NSNotification.Name("AppModeDidChangeNotification"),
                    object: nil,
                    userInfo: ["mode": currentMode]
                )
            }
        }
    }
    
    // 配置
    private var config: AppModeConfig
    
    // 本地存储键
    private let configKey = "AppModeConfig"
    
    // 隐藏初始化方法，确保只能通过shared访问
    private init() {
        // 从本地存储加载配置
        if let data = UserDefaults.standard.data(forKey: configKey),
           let savedConfig = try? JSONDecoder().decode(AppModeConfig.self, from: data) {
            config = savedConfig
            currentMode = savedConfig.currentMode
        } else {
            // 使用默认配置
            config = AppModeConfig.default
            currentMode = config.currentMode
            saveConfig()
        }
    }
    
    // 保存配置到本地存储
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
    
    // 检查服务器配置
    func checkServerConfiguration(completion: @escaping (Bool) -> Void) {
        // 如果服务器检查被禁用，则直接返回
        guard config.serverCheckEnabled else {
            completion(false)
            return
        }
        
        // 检查缓存是否过期
        if let lastChecked = config.lastCheckedTimestamp,
           Date().timeIntervalSince(lastChecked) < config.cacheExpirationInterval {
            // 缓存未过期，使用缓存的配置
            completion(false)
            return
        }
        
        // 创建服务器请求
        guard let url = URL(string: config.serverCheckURL) else {
            completion(false)
            return
        }
        
        // 添加设备UDID参数
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        if let udid = UserDefaults.standard.string(forKey: "deviceUDID") {
            queryItems.append(URLQueryItem(name: "udid", value: udid))
        }
        components?.queryItems = queryItems
        
        guard let requestURL = components?.url else {
            completion(false)
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // 解析服务器响应
            do {
                let serverConfig = try JSONDecoder().decode([String: String].self, from: data)
                
                // 更新应用模式
                DispatchQueue.main.async {
                    let modeChanged = self.updateModeFromServer(serverConfig)
                    
                    // 更新最后检查时间
                    self.config.lastCheckedTimestamp = Date()
                    self.saveConfig()
                    
                    completion(modeChanged)
                }
            } catch {
                Debug.shared.log(message: "解析服务器配置失败：\(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 根据服务器配置更新模式
    private func updateModeFromServer(_ serverConfig: [String: String]) -> Bool {
        // 如果服务器返回了有效的模式，则使用它
        if let modeString = serverConfig["appMode"],
           let newMode = AppMode(rawValue: modeString),
           newMode != currentMode {
            currentMode = newMode
            return true
        }
        return false
    }
    
    // 手动切换模式（用于调试）
    func toggleMode() {
        currentMode = (currentMode == .normal) ? .disguised : .normal
    }
    
    // 获取当前模式名称（本地化）
    func getCurrentModeName() -> String {
        switch currentMode {
        case .normal:
            return "正常模式"
        case .disguised:
            return "安全模式"
        }
    }
    
    // 检查当前是否为正常模式
    var isNormalMode: Bool {
        return currentMode == .normal
    }
    
    // 检查当前是否为伪装模式
    var isDisguisedMode: Bool {
        return currentMode == .disguised
    }
} 