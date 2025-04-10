//
//  StoreCollectionViewController.swift
//  AppFlex
//
//  Created by mantou on 2025/2/17.
//  Copyright © 2025 AppFlex. All rights reserved.
//

/*
注意: 需要在AppDelegate中添加以下代码以支持URL Scheme回调:

- 在Info.plist中添加URL Scheme "mantou"
- 然后在AppDelegate中添加以下方法:

func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // 处理从Safari回调的URL
    if url.scheme == "mantou" && url.host == "udid" {
        if let udid = url.pathComponents.last {
            // 创建通知，传递UDID
            let userInfo = ["udid": udid]
            NotificationCenter.default.post(
                name: NSNotification.Name("UDIDCallbackReceived"),
                object: nil,
                userInfo: userInfo
            )
            return true
        }
    }
    return false
}
*/

import UIKit
import SafariServices

// 全局变量，用于存储设备UDID
var globalDeviceUUID: String?

class StoreCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, SFSafariViewControllerDelegate {
    
    public struct AppData: Decodable {
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
        let requiresUnlock: Bool?
        let isUnlocked: Bool?
        
        var requiresKey: Bool {
            return requires_key == 1
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, date, size, channel, build, version, identifier, pkg, icon, plist
            case web_icon, type, requires_key, created_at, updated_at
            case requiresUnlock, isUnlocked
        }
    }

    struct APIResponse<T: Decodable>: Decodable {
        let success: Bool
        let data: T
        let message: String?
        let error: APIError?
    }

    struct APIError: Decodable {
        let code: String
        let details: String
    }

    struct UDIDStatus: Decodable {
        let bound: Bool
        let bindings: [Binding]?
    }
    
    struct Binding: Decodable {
        let id: Int
        let udid: String
        let card_id: Int
        let created_at: String
        let card_key: String
        
        enum CodingKeys: String, CodingKey {
            case id, udid
            case card_id
            case created_at
            case card_key
        }
    }

    private var apps: [AppData] = []
    private var deviceUUID: String {
        return globalDeviceUUID ?? UIDevice.current.identifierForVendor?.uuidString ?? "未知设备"
    }
    private var safariVC: SFSafariViewController?
    private let udidProfileURL = "https://uni.cloudmantoub.online/udid.mobileconfig"
    private let baseURL = "https://renmai.cloudmantoub.online/api/client"
    
    private var udidLabel: UILabel!
    
    // 自定义初始化方法，提供默认的布局
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        super.init(collectionViewLayout: layout)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewModel()
        setupCollectionView()
        
        title = "应用商店"
        
        // 添加获取UDID按钮
        let getUDIDButton = UIBarButtonItem(title: "获取UDID", style: .plain, target: self, action: #selector(getUDIDButtonTapped))
        
        // 添加手动安装按钮
        let manualInstallButton = UIBarButtonItem(title: "手动安装", style: .plain, target: self, action: #selector(handleManualInstall))
        
        // 添加帮助按钮
        let helpButton = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(showUDIDHelpGuide))
        
        navigationItem.rightBarButtonItems = [getUDIDButton, manualInstallButton, helpButton]
        
        // 添加UDID显示区域
        setupUDIDDisplay()
        
        // 检查是否已经有UDID
        checkForStoredUDID()
        
        fetchAppData()
        
        // 添加应用进入前台的通知监听，用于处理从Safari回来后的情况
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func applicationDidBecomeActive() {
        // 应用回到前台时，不再尝试从剪贴板检查UDID
        // 原剪贴板检测相关代码已删除
    }
    
    private func setupUDIDDisplay() {
        // 创建显示UDID的容器视图
        let udidContainerView = UIView()
        udidContainerView.backgroundColor = UIColor.systemGray6
        udidContainerView.layer.cornerRadius = 10
        udidContainerView.layer.borderWidth = 1
        udidContainerView.layer.borderColor = UIColor.systemGray5.cgColor
        
        // 创建标题标签
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.systemGray
        titleLabel.text = "设备UDID:"
        
        // 创建UDID标签
        udidLabel = UILabel()
        udidLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        udidLabel.textColor = UIColor.darkGray
        udidLabel.numberOfLines = 1
        udidLabel.adjustsFontSizeToFitWidth = true
        udidLabel.minimumScaleFactor = 0.7
        udidLabel.text = "获取中..."
        
        // 添加复制按钮
        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemBlue
        copyButton.addTarget(self, action: #selector(copyUDIDButtonTapped), for: .touchUpInside)
        
        // 添加视图到容器
        udidContainerView.addSubview(titleLabel)
        udidContainerView.addSubview(udidLabel)
        udidContainerView.addSubview(copyButton)
        
        // 设置约束
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        udidLabel.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        udidContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(udidContainerView)
        
        NSLayoutConstraint.activate([
            udidContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            udidContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            udidContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            udidContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.leadingAnchor.constraint(equalTo: udidContainerView.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: udidContainerView.topAnchor, constant: 8),
            
            udidLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            udidLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            udidLabel.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            
            copyButton.trailingAnchor.constraint(equalTo: udidContainerView.trailingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: udidContainerView.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 40),
            copyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 调整集合视图的内容边距，为UDID显示区域腾出空间
        collectionView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 0, right: 0)
    }
    
    @objc private func copyUDIDButtonTapped() {
        if let udid = globalDeviceUUID {
            UIPasteboard.general.string = udid
            
            // 显示复制成功提示
            let alert = UIAlertController(
                title: "已复制",
                message: "UDID已复制到剪贴板",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    // 检查是否已经存储了UDID
    private func checkForStoredUDID() {
        if let storedUDID = UserDefaults.standard.string(forKey: "deviceUDID") {
            globalDeviceUUID = storedUDID
            Debug.shared.log(message: "已加载存储的UDID: \(storedUDID)")
            
            // 更新UDID显示
            updateUDIDDisplay(storedUDID)
            
            // 在控制台也打印UDID，便于调试
            print("当前设备UDID: \(storedUDID)")
        } else {
            Debug.shared.log(message: "未找到存储的UDID，需要获取")
            print("未找到存储的UDID，需要获取")
            
            // 提示用户获取UDID的重要性
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                let alert = UIAlertController(
                    title: "需要获取UDID",
                    message: "为了正常使用应用安装功能，请点击获取UDID",
                    preferredStyle: .alert
                )
                
                let getUDIDAction = UIAlertAction(title: "立即获取", style: .default) { [weak self] _ in
                    self?.showUDIDProfileAlert()
                }
                
                let laterAction = UIAlertAction(title: "稍后再说", style: .cancel, handler: nil)
                
                alert.addAction(getUDIDAction)
                alert.addAction(laterAction)
                
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func updateUDIDDisplay(_ udid: String) {
        DispatchQueue.main.async { [weak self] in
            self?.udidLabel.text = udid
        }
    }
    
    private func showUDIDProfileAlert() {
        let alert = UIAlertController(
            title: "获取设备UDID",
            message: "系统将安装描述文件来获取UDID。安装完成后，请注意URL Scheme回调将自动导入UDID。",
            preferredStyle: .alert
        )
        
        let proceedAction = UIAlertAction(title: "继续", style: .default) { [weak self] _ in
            self?.openUDIDProfile()
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(proceedAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func openUDIDProfile() {
        guard let url = URL(string: udidProfileURL) else { return }
        
        // 添加一个通知，以便能够接收URL Scheme回调
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUDIDCallback(_:)),
            name: NSNotification.Name("UDIDCallbackReceived"),
            object: nil
        )
        
        safariVC = SFSafariViewController(url: url)
        safariVC?.delegate = self
        present(safariVC!, animated: true, completion: nil)
    }
    
    @objc private func handleUDIDCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let udid = userInfo["udid"] as? String else {
            return
        }
        
        // 存储UDID
        globalDeviceUUID = udid
        UserDefaults.standard.set(udid, forKey: "deviceUDID")
        Debug.shared.log(message: "成功通过URL Scheme获取并存储UDID: \(udid)")
        
        // 更新UDID显示
        updateUDIDDisplay(udid)
        
        // 通知用户
        let alert = UIAlertController(
            title: "成功",
            message: "已成功获取设备UDID",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // SFSafariViewControllerDelegate
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // 当Safari关闭时，检查是否有回调
        Debug.shared.log(message: "Safari已关闭，检查UDID状态")
        
        // 不再从剪贴板读取UDID
    }

    private func fetchAppData() {
        // 显示加载提示
        let loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用列表...", preferredStyle: .alert)
        present(loadingAlert, animated: true, completion: nil)
        
        // 使用ServerController获取应用列表
        ServerController.shared.getAppList { [weak self] serverApps, error in
            // 关闭加载提示
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true, completion: nil)
                
                if let error = error {
                    print("获取应用列表失败: \(error)")
                    // 显示错误提示
                    let errorAlert = UIAlertController(
                        title: "获取应用失败",
                        message: "无法获取应用列表，请稍后再试。\n错误: \(error)",
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(errorAlert, animated: true)
                    return
                }
                
                guard let serverApps = serverApps else {
                    print("没有获取到应用列表")
                    return
                }
                
                // 将ServerApp转换为AppData
                let convertedApps: [AppData] = serverApps.map { app in
                    return AppData(
                        id: app.id,
                        name: app.name,
                        date: nil,
                        size: nil,
                        channel: nil,
                        build: nil,
                        version: app.version,
                        identifier: nil,
                        pkg: app.pkg,
                        icon: app.icon,
                        plist: app.plist,
                        web_icon: nil,
                        type: nil,
                        requires_key: app.requiresKey ? 1 : 0,
                        created_at: nil,
                        updated_at: nil,
                        requiresUnlock: app.requiresKey,
                        isUnlocked: false
                    )
                }
                
                self?.apps = convertedApps
                self?.collectionView.reloadData()
            }
        }
    }

    private func checkUDIDStatus(for app: AppData) {
        guard let cleanUUID = globalDeviceUUID?
            .replacingOccurrences(of: "Optional(\"", with: "")
            .replacingOccurrences(of: "\")", with: ""),
            !cleanUUID.isEmpty else {
            print("设备 UUID 无效")
            return
        }

        guard let encodedUUID = cleanUUID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("UDID编码失败")
            return
        }

        let urlString = "\(baseURL)/check-udid?udid=\(encodedUUID)"
        guard let url = URL(string: urlString) else {
            print("URL构建失败")
            return
        }
        
        print("检查UDID状态: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("检查UDID状态失败：\(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<UDIDStatus>.self, from: data)
                DispatchQueue.main.async {
                    if response.success {
                        if response.data.bound {
                            print("UDID已绑定，获取应用详情")
                            
                            // 查看是否有与当前应用相关的绑定信息
                            var hasAppBinding = false
                            if let bindings = response.data.bindings {
                                // 这里可以添加逻辑检查绑定是否与当前应用相关
                                // 但API文档中没有提供这个关联信息，所以我们假设绑定是全局的
                                hasAppBinding = !bindings.isEmpty
                            }
                            
                            // 如果有绑定信息，则直接获取应用详情
                            if hasAppBinding {
                                self?.fetchAppDetails(for: app)
                            } else {
                                // 虽然UDID有绑定，但可能不是针对当前应用
                                self?.promptUnlockCode(for: app)
                            }
                        } else {
                            print("UDID未绑定，需要验证卡密")
                            self?.promptUnlockCode(for: app)
                        }
                    } else {
                        print("检查UDID状态失败：\(response.message ?? "未知错误")")
                        self?.promptUnlockCode(for: app)
                    }
                }
            } catch {
                print("解析UDID状态响应失败：\(error.localizedDescription)")
                // 解析错误时，默认提示输入卡密
                DispatchQueue.main.async {
                    self?.promptUnlockCode(for: app)
                }
            }
        }.resume()
    }

    private func verifyUnlockCode(_ code: String, for app: AppData) {
        // 显示加载提示
        let loadingAlert = UIAlertController(title: "验证中", message: "正在验证解锁码...", preferredStyle: .alert)
        present(loadingAlert, animated: true, completion: nil)
        
        // 使用ServerController验证卡密
        ServerController.shared.verifyCard(cardKey: code, appId: app.id) { [weak self] success, message in
            // 关闭加载提示
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true, completion: nil)
                
                if success {
                    print("卡密验证成功，准备刷新应用详情")
                    
                    // 显示成功消息
                    let alert = UIAlertController(
                        title: "验证成功",
                        message: message ?? "卡密验证成功",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                        // 在用户点击确定后，刷新应用详情
                        let refreshAlert = UIAlertController(title: "刷新中", message: "正在刷新应用信息...", preferredStyle: .alert)
                        self?.present(refreshAlert, animated: true)
                        
                        // 使用新增的refreshAppDetail方法
                        ServerController.shared.refreshAppDetail(appId: app.id) { success, error in
                            DispatchQueue.main.async {
                                refreshAlert.dismiss(animated: true)
                                
                                if success {
                                    print("应用详情刷新成功，重新获取应用详情")
                                    self?.fetchAppDetails(for: app)
                                } else {
                                    print("应用详情刷新失败: \(error ?? "未知错误")")
                                    // 尝试常规的获取应用详情
                                    self?.fetchAppDetails(for: app)
                                }
                            }
                        }
                    })
                    
                    self?.present(alert, animated: true, completion: nil)
                } else {
                    let errorMessage = message ?? "请检查卡密是否正确"
                    print("验证失败：\(errorMessage)")
                    let alert = UIAlertController(
                        title: "验证失败",
                        message: errorMessage,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    private func handleInstall(for app: AppData) {
        // 检查是否有UDID
        if globalDeviceUUID == nil || globalDeviceUUID?.isEmpty == true {
            // 如果没有UDID，提示获取
            let alert = UIAlertController(
                title: "需要UDID",
                message: "安装应用前需要先获取设备UDID",
                preferredStyle: .alert
            )
            
            let getUDIDAction = UIAlertAction(title: "获取UDID", style: .default) { [weak self] _ in
                self?.showUDIDProfileAlert()
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            alert.addAction(getUDIDAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
            return
        }

        // 对于免费应用，显示加载指示器
        let isFreemiumApp = (app.requires_key == 0)
        var loadingAlert: UIAlertController?
        
        if isFreemiumApp {
            loadingAlert = UIAlertController(title: "准备安装", message: "正在获取安装信息...", preferredStyle: .alert)
            present(loadingAlert!, animated: true, completion: nil)
        }

        // 检查app是否有plist数据
        if let plist = app.plist, !plist.isEmpty {
            // 如果直接有plist，可以直接处理安装
            if isFreemiumApp {
                // 短暂延迟后关闭加载提示，立即安装
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    loadingAlert?.dismiss(animated: true) {
                        self?.startInstallation(for: app)
                    }
                }
            } else {
                startInstallation(for: app)
            }
        } else {
            // 否则尝试获取详情
            if isFreemiumApp {
                // 已经显示了加载提示，直接获取详情
                fetchAppDetails(for: app, loadingAlertShown: true, existingAlert: loadingAlert)
            } else {
                fetchAppDetails(for: app)
            }
        }
    }

    // 添加一个新方法，支持已显示加载提示的情况
    private func fetchAppDetails(for app: AppData, loadingAlertShown: Bool = false, existingAlert: UIAlertController? = nil) {
        print("开始获取应用详情 - 应用ID: \(app.id), 名称: \(app.name), 是否需要卡密: \(app.requiresKey ? "是" : "否")")
        
        // 显示加载提示（如果尚未显示）
        var loadingAlert = existingAlert
        if !loadingAlertShown {
            loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用信息...", preferredStyle: .alert)
            present(loadingAlert!, animated: true, completion: nil)
        } else if loadingAlert != nil {
            // 更新现有加载提示的消息
            loadingAlert?.message = "正在获取应用信息..."
        }
        
        // 确保已经有设备UDID
        if globalDeviceUUID == nil || globalDeviceUUID?.isEmpty == true {
            // 从设备ID获取
            let deviceUUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            globalDeviceUUID = deviceUUID
            print("使用设备ID作为UDID: \(deviceUUID)")
            updateUDIDDisplay(deviceUUID)
        }
        
        print("使用UDID: \(globalDeviceUUID ?? "未知") 获取应用详情")
        
        // 使用ServerController获取应用详情
        ServerController.shared.getAppDetail(appId: app.id) { [weak self] appDetail, error in
            // 关闭加载提示
            DispatchQueue.main.async {
                loadingAlert?.dismiss(animated: true, completion: nil)
                
                if let error = error {
                    print("获取应用详情失败: \(error)")
                    // 如果应用需要验证码，提示输入
                    if app.requiresKey {
                        print("应用需要卡密，提示用户输入")
                        self?.promptUnlockCode(for: app)
                    } else {
                        // 显示错误提示
                        let errorAlert = UIAlertController(
                            title: "获取应用信息失败",
                            message: "无法获取应用详细信息，请稍后再试。\n错误: \(error)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                    return
                }
                
                guard let appDetail = appDetail else {
                    print("没有获取到应用详情")
                    if app.requiresKey {
                        self?.promptUnlockCode(for: app)
                    }
                    return
                }
                
                print("成功获取应用详情 - 应用名称: \(appDetail.name), 是否需要解锁: \(appDetail.requiresUnlock), 是否已解锁: \(appDetail.isUnlocked)")
                
                // 检查应用是否需要解锁且未解锁
                if appDetail.requiresUnlock && !appDetail.isUnlocked {
                    print("应用需要解锁且未解锁，提示用户输入卡密")
                    self?.promptUnlockCode(for: app)
                } else {
                    // 获取plist路径
                    if let plist = appDetail.plist {
                        // 应用已解锁或不需要解锁，且有plist可以安装
                        print("应用可以安装，原始plist路径: \(plist)")
                        
                        // 创建一个新的AppData对象，包含更多详情信息
                        let updatedApp = AppData(
                            id: appDetail.id,
                            name: appDetail.name,
                            date: nil,
                            size: nil,
                            channel: nil,
                            build: nil,
                            version: appDetail.version,
                            identifier: nil,
                            pkg: appDetail.pkg,
                            icon: appDetail.icon,
                            plist: plist,
                            web_icon: nil,
                            type: nil,
                            requires_key: appDetail.requiresUnlock ? 1 : 0,
                            created_at: nil,
                            updated_at: nil,
                            requiresUnlock: appDetail.requiresUnlock,
                            isUnlocked: appDetail.isUnlocked
                        )
                        
                        print("准备安装应用，更新后的plist: \(updatedApp.plist ?? "无")")
                        self?.startInstallation(for: updatedApp)
                    } else {
                        print("应用无法安装：缺少安装信息")
                        let alert = UIAlertController(
                            title: "无法安装",
                            message: "此应用暂时无法安装，请稍后再试",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AppCell", for: indexPath) as? AppCell else {
            return UICollectionViewCell()
        }
        let app = apps[indexPath.item]
        cell.configure(with: app)
        cell.onInstallTapped = { [weak self] in
            self?.handleInstall(for: app)
        }
        return cell
    }

    // 设置每个卡片的大小（宽度和高度）
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 30 // 减去左右的间距
        let height: CGFloat = 90 // 固定每个卡片的高度为 50
        return CGSize(width: width, height: height)
    }

    private func startInstallation(for app: AppData) {
        guard let plist = app.plist else {
            let alert = UIAlertController(
                title: "安装失败",
                message: "无法获取安装信息，请稍后再试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        print("原始plist路径: \(plist)")
        
        // 使用新的方法处理plist链接
        let finalPlistURL = processPlistLink(plist)
        print("处理后的plist URL: \(finalPlistURL)")
        
        // 确保URL编码正确
        let encodedPlistURL = finalPlistURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? finalPlistURL
        
        // 验证plist URL
        verifyPlistURL(encodedPlistURL)
        
        // 构建安装URL
        let installURLString = "itms-services://?action=download-manifest&url=\(encodedPlistURL)"
        print("最终安装URL: \(installURLString)")
        
        // 判断应用是否可以直接安装
        // 免费应用(requires_key=0)或已解锁的应用(isUnlocked=true)都可以直接安装
        if app.requires_key == 0 || (app.requiresUnlock == true && app.isUnlocked == true) {
            // 免费或已解锁的应用，直接安装
            print("免费或已解锁应用，直接触发安装")
            // 使用新的安全方法打开URL
            safelyOpenInstallURL(installURLString)
        } else {
            // 需要卡密且未解锁的应用，显示确认对话框
            let alert = UIAlertController(
                title: "确认安装",
                message: "是否安装 \(app.name)？\n\n版本: \(app.version)",
                preferredStyle: .alert
            )

            let installAction = UIAlertAction(title: "安装", style: .default) { [weak self] _ in
                // 使用新的安全方法打开URL
                self?.safelyOpenInstallURL(installURLString)
            }
            
            // 添加调试选项
            let debugAction = UIAlertAction(title: "调试信息", style: .default) { [weak self] _ in
                let debugAlert = UIAlertController(
                    title: "调试信息",
                    message: "原始plist: \(plist)\n\n处理后URL: \(encodedPlistURL)\n\n安装URL: \(installURLString)",
                    preferredStyle: .alert
                )
                debugAlert.addAction(UIAlertAction(title: "复制URL", style: .default) { _ in
                    UIPasteboard.general.string = encodedPlistURL
                })
                debugAlert.addAction(UIAlertAction(title: "尝试直接安装", style: .default) { _ in
                    if let url = URL(string: installURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                })
                debugAlert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                self?.present(debugAlert, animated: true)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            alert.addAction(installAction)
            alert.addAction(debugAction)
            alert.addAction(cancelAction)

            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // 添加一个方法来处理服务器返回的plist链接，格式可能是加密数据
    private func processPlistLink(_ plistLink: String) -> String {
        print("处理plist链接: \(plistLink)")
        
        // 1. 如果链接是直接的URL，无需处理
        if plistLink.lowercased().hasPrefix("http") {
            print("标准HTTP/HTTPS链接，无需处理")
            return plistLink
        }
        
        // 2. 如果链接是相对路径，添加基础URL
        if plistLink.hasPrefix("/") {
            // 检查是否是API plist格式的路径（检查格式：/api/plist/<IV>/<加密数据>）
            if plistLink.hasPrefix("/api/plist/") {
                let components = plistLink.components(separatedBy: "/")
                if components.count >= 5 {
                    // 应该有格式：["", "api", "plist", "<IV>", "<加密数据>"]
                    print("检测到API plist格式路径")
                    let fullURL = "https://renmai.cloudmantoub.online\(plistLink)"
                    print("转换为完整URL: \(fullURL)")
                    return fullURL
                }
            }
            
            // 普通相对路径
            let fullURL = "https://renmai.cloudmantoub.online\(plistLink)"
            print("相对路径，转换为完整URL: \(fullURL)")
            return fullURL
        }
        
        // 3. 如果链接可能是加密数据，尝试解密
        do {
            // 先尝试解析为JSON
            if let data = plistLink.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // 检查是否包含加密所需的IV和data字段
                if let iv = json["iv"] as? String,
                   let encryptedData = json["data"] as? String {
                    
                    print("找到加密格式JSON，尝试解密")
                    if let decryptedURL = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                        print("成功解密为: \(decryptedURL)")
                        return decryptedURL
                    } else {
                        print("解密失败")
                    }
                } else {
                    print("JSON格式但缺少IV或加密数据")
                }
            }
        } catch {
            print("解析JSON失败: \(error.localizedDescription)")
        }
        
        // 4. 如果链接看起来像是从特定API返回的加密链接格式
        if plistLink.contains("/api/plist/") && plistLink.contains("/") {
            // 这可能是已经格式化好的加密plist链接
            let fullURL = plistLink.hasPrefix("http") ? plistLink : "https://renmai.cloudmantoub.online\(plistLink)"
            print("使用API格式plist链接: \(fullURL)")
            return fullURL
        }
        
        // 5. 尝试从链接中提取IV和加密数据（如果格式是：<IV>/<加密数据>）
        let components = plistLink.components(separatedBy: "/")
        if components.count == 2 {
            let possibleIV = components[0]
            let possibleData = components[1]
            
            let (valid, message) = CryptoUtils.shared.validateFormat(encryptedData: possibleData, iv: possibleIV)
            if valid {
                print("从链接中提取到有效的IV和加密数据")
                let apiPath = "/api/plist/\(possibleIV)/\(possibleData)"
                let fullURL = "https://renmai.cloudmantoub.online\(apiPath)"
                print("构建API格式plist链接: \(fullURL)")
                return fullURL
            } else {
                print("提取的IV和加密数据无效: \(message)")
            }
        }
        
        // 6. 如果以上都不匹配，直接返回原始链接
        print("无法识别的链接格式，使用原始链接")
        return plistLink
    }
    
    // 添加一个方法来验证plist URL
    private func verifyPlistURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("plist URL无效: \(urlString)")
            return
        }
        
        print("开始验证plist URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 只获取头信息，不下载内容
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("验证plist URL失败: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("获取到非HTTP响应")
                return
            }
            
            print("plist URL响应状态码: \(httpResponse.statusCode)")
            
            // 检查内容类型
            if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                print("内容类型: \(contentType)")
                
                if contentType.contains("application/xml") || 
                   contentType.contains("text/xml") || 
                   contentType.contains("application/x-plist") {
                    print("验证成功: 返回了有效的plist类型")
                } else {
                    print("警告: 内容类型可能不是plist")
                    
                    // 如果不是预期的类型，获取完整内容
                    URLSession.shared.dataTask(with: url) { fullData, _, _ in
                        if let fullData = fullData, let content = String(data: fullData, encoding: .utf8) {
                            // 检查内容的前200个字符
                            let previewContent = String(content.prefix(200))
                            print("内容预览: \(previewContent)")
                            
                            // 检查是否是有效的plist
                            if content.contains("<?xml") || content.contains("<!DOCTYPE") {
                                print("内容验证: 包含XML标记，可能是有效的plist")
                            } else {
                                print("内容验证: 不包含XML标记，可能不是有效的plist")
                            }
                        }
                    }.resume()
                }
            } else {
                print("响应中没有Content-Type信息")
            }
        }.resume()
    }

    // 添加显示UDID帮助指南的方法
    @objc private func showUDIDHelpGuide() {
        let helpVC = UIViewController()
        helpVC.title = "如何获取UDID"
        helpVC.view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        helpVC.view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: helpVC.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: helpVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: helpVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: helpVC.view.bottomAnchor)
        ])
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        let padding: CGFloat = 20
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
        ])
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "如何获取设备UDID"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        
        // 介绍
        let introLabel = UILabel()
        introLabel.text = "UDID（唯一设备标识符）是每台iOS设备特有的识别码，安装某些应用需要提供此标识符。以下是获取UDID的步骤："
        introLabel.font = UIFont.systemFont(ofSize: 16)
        introLabel.numberOfLines = 0
        
        // 步骤1
        let step1Label = createStepLabel(number: 1, text: "在应用内点击\"获取UDID\"按钮")
        
        // 步骤2
        let step2Label = createStepLabel(number: 2, text: "Safari浏览器会打开一个网页，点击\"允许\"下载配置描述文件")
        
        // 步骤3
        let step3Label = createStepLabel(number: 3, text: "前往设置 -> 通用 -> VPN与设备管理，找到并点击下载的描述文件，然后点击\"安装\"")
        
        // 步骤4
        let step4Label = createStepLabel(number: 4, text: "完成安装后将显示UDID信息，网站会自动通过URL Scheme跳转回应用并传递UDID")
        
        // 注意事项
        let noteLabel = UILabel()
        noteLabel.text = "注意：此过程只需完成一次。一旦获取到UDID，应用会自动保存，无需重复操作。"
        noteLabel.font = UIFont.italicSystemFont(ofSize: 16)
        noteLabel.textColor = .systemGray
        noteLabel.numberOfLines = 0
        
        // 添加开始按钮
        let startButton = UIButton(type: .system)
        startButton.setTitle("开始获取UDID", for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        startButton.backgroundColor = UIColor.tintColor
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 10
        
        // 使用更现代的方式设置按钮内边距
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            config.baseBackgroundColor = UIColor.tintColor
            config.baseForegroundColor = .white
            startButton.configuration = config
        } else {
            startButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        
        startButton.addTarget(self, action: #selector(getUDIDButtonTapped), for: .touchUpInside)
        
        // 添加所有视图到堆栈
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(introLabel)
        stackView.addArrangedSubview(step1Label)
        stackView.addArrangedSubview(step2Label)
        stackView.addArrangedSubview(step3Label)
        stackView.addArrangedSubview(step4Label)
        stackView.addArrangedSubview(noteLabel)
        stackView.addArrangedSubview(startButton)
        
        // 调整堆栈视图内元素宽度
        for view in stackView.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        // 居中显示按钮
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true
        
        navigationController?.pushViewController(helpVC, animated: true)
    }

    // 创建步骤标签的辅助方法
    private func createStepLabel(number: Int, text: String) -> UILabel {
        let label = UILabel()
        let attributedString = NSMutableAttributedString(string: "步骤 \(number): ", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.tintColor
        ])
        
        attributedString.append(NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]))
        
        label.attributedText = attributedString
        label.numberOfLines = 0
        return label
    }

    // 添加这两个设置方法
    private func setupViewModel() {
        // 已有的ViewModel初始化代码，如果有的话
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .systemBackground
        collectionView.register(AppCell.self, forCellWithReuseIdentifier: "AppCell")
    }

    private func extractUDID(from urlString: String) -> String? {
        // 检查URL是否包含udid部分
        if urlString.contains("/udid/") {
            // 分割URL获取UDID部分
            let components = urlString.components(separatedBy: "/udid/")
            if components.count > 1 {
                // 提取UDID（可能需要进一步清理）
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func promptUnlockCode(for app: AppData) {
        let alert = UIAlertController(
            title: "解锁码",
            message: "请输入解锁码以继续安装",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "请输入解锁码"
        }
        let confirmAction = UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let unlockCode = alert.textFields?.first?.text, !unlockCode.isEmpty else {
                print("解锁码为空")
                return
            }
            self?.verifyUnlockCode(unlockCode, for: app)
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    // 打开Safari安装描述文件
    @objc private func getUDIDButtonTapped() {
        showUDIDProfileAlert()
    }

    // 处理JSON对象为AppData
    private func parseAppData(_ jsonString: String) -> AppData? {
        guard let data = jsonString.data(using: .utf8) else {
            print("无法将字符串转换为数据")
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let id = json?["id"] as? String,
                  let name = json?["name"] as? String,
                  let version = json?["version"] as? String,
                  let icon = json?["icon"] as? String,
                  let requiresKey = json?["requires_key"] as? Int else {
                print("JSON缺少必要字段")
                return nil
            }
            
            // 获取其他可选字段
            let date = json?["date"] as? String
            let size = json?["size"] as? Int
            let channel = json?["channel"] as? String
            let build = json?["build"] as? String
            let identifier = json?["identifier"] as? String
            let pkg = json?["pkg"] as? String
            let plist = json?["plist"] as? String
            let webIcon = json?["web_icon"] as? String
            let type = json?["type"] as? Int
            let createdAt = json?["created_at"] as? String
            let updatedAt = json?["updated_at"] as? String
            
            // 创建并返回AppData对象
            return AppData(
                id: id,
                name: name,
                date: date,
                size: size,
                channel: channel,
                build: build,
                version: version,
                identifier: identifier,
                pkg: pkg,
                icon: icon,
                plist: plist,
                web_icon: webIcon,
                type: type,
                requires_key: requiresKey,
                created_at: createdAt,
                updated_at: updatedAt,
                requiresUnlock: requiresKey == 1,
                isUnlocked: false
            )
        } catch {
            print("JSON解析失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 方法用于直接处理应用详情
    private func handleAppJson(_ jsonString: String) {
        print("处理应用JSON数据")
        
        if let app = parseAppData(jsonString) {
            print("成功解析应用数据: \(app.name)")
            
            // 应用可以安装，并获取到plist
            if let plist = app.plist {
                print("应用可以安装，原始plist路径: \(plist)")
                // 添加加载提示
                let loadingAlert = UIAlertController(title: "处理中", message: "正在准备安装...", preferredStyle: .alert)
                present(loadingAlert, animated: true) {
                    // 在背景线程处理，避免阻塞UI
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        // 短暂延迟，模拟处理时间
                        Thread.sleep(forTimeInterval: 0.5)
                        
                        DispatchQueue.main.async {
                            loadingAlert.dismiss(animated: true) {
                                // 如果是免费或已解锁应用，自动处理安装
                                let isReadyForDirectInstall = app.requires_key == 0 || (app.requiresUnlock == true && app.isUnlocked == true)
                                
                                if isReadyForDirectInstall {
                                    print("准备直接安装应用")
                                    self?.startInstallation(for: app)
                                } else {
                                    // 需要确认的应用，显示确认对话框
                                    let confirmAlert = UIAlertController(
                                        title: "确认安装",
                                        message: "是否安装 \(app.name) 版本 \(app.version)？",
                                        preferredStyle: .alert
                                    )
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "安装", style: .default) { _ in
                                        self?.startInstallation(for: app)
                                    })
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel))
                                    
                                    self?.present(confirmAlert, animated: true)
                                }
                            }
                        }
                    }
                }
            } else {
                print("应用无法安装：缺少安装信息")
                let alert = UIAlertController(
                    title: "无法安装",
                    message: "此应用暂时无法安装，请稍后再试",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        } else {
            print("应用数据解析失败")
            let alert = UIAlertController(
                title: "应用解析失败",
                message: "无法解析应用数据，请稍后再试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    // 添加一个选项，允许用户直接输入JSON数据
    @objc private func handleManualInstall() {
        let alert = UIAlertController(
            title: "手动安装",
            message: "请粘贴应用JSON数据",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "粘贴JSON数据"
        }
        
        let installAction = UIAlertAction(title: "安装", style: .default) { [weak self] _ in
            if let jsonText = alert.textFields?.first?.text, !jsonText.isEmpty {
                self?.handleAppJson(jsonText)
            } else {
                self?.showError(title: "错误", message: "请输入有效的JSON数据")
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(installAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // 显示错误信息
    private func showError(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // 添加新方法来分段处理和验证长URL
    private func safelyOpenInstallURL(_ urlString: String) {
        print("尝试打开安装URL: \(urlString)")
        
        // 检查URL长度
        if urlString.count > 2000 {
            print("警告: URL长度超过2000个字符，可能导致问题")
        }
        
        // 尝试创建和打开URL
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                print("准备打开URL")
                UIApplication.shared.open(url, options: [:], completionHandler: { success in
                    if success {
                        print("成功打开URL进行安装")
                    } else {
                        print("无法打开URL: \(urlString)")
                        // 尝试分析失败原因
                        self.analyzeURLOpenFailure(urlString)
                    }
                })
            }
        } else {
            print("无法创建URL对象，可能是格式问题")
            let modifiedURL = handlePotentiallyInvalidURL(urlString)
            if let url = URL(string: modifiedURL), modifiedURL != urlString {
                print("尝试使用修正后的URL: \(modifiedURL)")
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: { success in
                        print("修正URL打开结果: \(success)")
                    })
                }
            } else {
                showURLErrorAlert(urlString)
            }
        }
    }

    // 尝试分析URL打开失败的原因
    private func analyzeURLOpenFailure(_ urlString: String) {
        // 检查是否是常见的问题
        if urlString.contains(" ") {
            print("URL含有空格，这可能导致问题")
            let trimmedURL = urlString.replacingOccurrences(of: " ", with: "%20")
            if let url = URL(string: trimmedURL) {
                print("尝试修正空格后的URL")
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        
        // 检查长度问题
        if urlString.count > 2000 {
            // 尝试缩短URL
            print("URL长度过长，尝试缩短")
            // 这里可以调用URL缩短服务，或者通过其他手段简化plist URL
        }
        
        // 显示错误提示
        showURLErrorAlert(urlString)
    }

    // 处理可能无效的URL
    private func handlePotentiallyInvalidURL(_ urlString: String) -> String {
        // 替换特殊字符
        var modifiedURL = urlString
        let problematicCharacters = [" ", "<", ">", "#", "%", "{", "}", "|", "\\", "^", "~", "[", "]", "`"]
        
        for char in problematicCharacters {
            modifiedURL = modifiedURL.replacingOccurrences(of: char, with: urlEncodeCharacter(char))
        }
        
        return modifiedURL
    }

    // URL编码单个字符
    private func urlEncodeCharacter(_ character: String) -> String {
        return character.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? character
    }

    // 显示URL错误提示
    private func showURLErrorAlert(_ urlString: String) {
        let alertMessage = """
        无法打开安装URL，可能原因：
        1. URL格式不正确
        2. URL长度过长(当前\(urlString.count)字符)
        3. iOS限制了itms-services协议
        
        请联系开发者解决此问题。
        """
        
        let alert = UIAlertController(
            title: "安装失败",
            message: alertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "复制URL", style: .default) { _ in
            UIPasteboard.general.string = urlString
        })
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }
}

// 自定义 Cell
class AppCell: UICollectionViewCell {
    private let appIcon = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let installButton = UIButton(type: .system)
    private let freeLabel = UILabel() // 添加限免标签
    private var isFreemiumApp = false // 添加标记是否为免费应用

    var onInstallTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 15
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowRadius = 5

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, versionLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 5
        textStackView.alignment = .leading

        let stackView = UIStackView(arrangedSubviews: [appIcon, textStackView, installButton])
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.alignment = .center
        stackView.distribution = .fill

        contentView.addSubview(stackView)
        
        // 设置限免标签
        freeLabel.text = "限免"
        freeLabel.textColor = .white
        freeLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        freeLabel.backgroundColor = UIColor.systemRed
        freeLabel.textAlignment = .center
        freeLabel.layer.cornerRadius = 10
        freeLabel.layer.masksToBounds = true
        freeLabel.layer.borderWidth = 1
        freeLabel.layer.borderColor = UIColor.white.cgColor
        freeLabel.isHidden = true // 初始隐藏
        
        contentView.addSubview(freeLabel)
        
        // 设置约束
        freeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            freeLabel.topAnchor.constraint(equalTo: appIcon.topAnchor),
            freeLabel.leadingAnchor.constraint(equalTo: appIcon.leadingAnchor, constant: -5),
            freeLabel.widthAnchor.constraint(equalToConstant: 40),
            freeLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
        ])

        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 70).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 70).isActive = true

        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .darkGray
        versionLabel.font = UIFont.systemFont(ofSize: 14, weight: .light)
        versionLabel.textColor = .lightGray

        installButton.backgroundColor = .systemBlue
        installButton.layer.cornerRadius = 10
        installButton.setTitle("安装", for: .normal)
        installButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        installButton.tintColor = .white
        installButton.frame.size = CGSize(width: 100, height: 40)  // 固定按钮大小
        installButton.addTarget(self, action: #selector(installTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with app: StoreCollectionViewController.AppData) {
        nameLabel.text = app.name
        
        // 判断应用状态
        if app.requires_key == 0 {
            // 完全免费应用
            isFreemiumApp = true
            freeLabel.isHidden = false
            freeLabel.text = "限免"
            freeLabel.backgroundColor = UIColor.systemRed
            
            // 针对限免应用，在版本号旁边显示状态
            versionLabel.text = "版本 \(app.version) · 限免安装"
            versionLabel.textColor = .systemGreen
            
            // 给限免应用的安装按钮设置不同的样式
            installButton.backgroundColor = .systemGreen
            installButton.setTitle("免费安装", for: .normal)
        } else if app.requiresUnlock == true && app.isUnlocked == true {
            // 已解锁的付费应用
            isFreemiumApp = true  // 使用相同的动画效果
            freeLabel.isHidden = false
            freeLabel.text = "已解锁"
            freeLabel.backgroundColor = UIColor.systemBlue
            
            // 显示已解锁状态
            versionLabel.text = "版本 \(app.version) · 已解锁"
            versionLabel.textColor = .systemBlue
            
            // 设置按钮样式
            installButton.backgroundColor = .systemBlue
            installButton.setTitle("直接安装", for: .normal)
        } else {
            // 未解锁的付费应用
            isFreemiumApp = false
            freeLabel.isHidden = true
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .lightGray
            
            // 恢复普通应用的安装按钮样式
            installButton.backgroundColor = .systemBlue
            installButton.setTitle("安装", for: .normal)
        }
        
        if let url = URL(string: app.icon) {
            loadImage(from: url, into: appIcon)
        }
    }

    @objc private func installTapped() {
        // 添加按钮点击视觉反馈，特别是对免费应用
        if isFreemiumApp {
            // 免费或已解锁应用，显示加载效果
            UIView.animate(withDuration: 0.15, animations: {
                self.installButton.alpha = 0.6
                self.installButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.installButton.setTitle("处理中...", for: .normal)
            }, completion: { _ in
                // 调用安装回调
                self.onInstallTapped?()
                
                // 延迟恢复按钮状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    UIView.animate(withDuration: 0.2) {
                        self.installButton.alpha = 1.0
                        self.installButton.transform = .identity
                        // 恢复原始文本
                        if self.installButton.backgroundColor == .systemGreen {
                            self.installButton.setTitle("免费安装", for: .normal)
                        } else {
                            self.installButton.setTitle("直接安装", for: .normal)
                        }
                    }
                }
            })
        } else {
            // 普通应用，简单的视觉反馈
            UIView.animate(withDuration: 0.1, animations: {
                self.installButton.alpha = 0.7
                self.installButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }, completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.installButton.alpha = 1.0
                    self.installButton.transform = .identity
                }
                self.onInstallTapped?()
            })
        }
    }

    private func loadImage(from url: URL, into imageView: UIImageView) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                    imageView.layer.cornerRadius = imageView.frame.size.width / 2
                    imageView.clipsToBounds = true
                }
            }
        }
    }
}
