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
        let version: String
        let icon: String
        let web_icon: String?
        let requires_key: Int
        let size: Int?
        let type: Int?
        let identifier: String?
        let created_at: String?
        let updated_at: String?
        let pkg: String?
        let plist: String?
        let requiresUnlock: Bool?
        let isUnlocked: Bool?
        
        var requiresKey: Bool {
            return requires_key == 1
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, version, icon, size, type, identifier, pkg, plist
            case web_icon, requires_key, created_at, updated_at
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
        
        // 添加帮助按钮
        let helpButton = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(showUDIDHelpGuide))
        
        navigationItem.rightBarButtonItems = [getUDIDButton, helpButton]
        
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
        guard let url = URL(string: "\(baseURL)/apps") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("数据请求失败：\(error?.localizedDescription ?? "未知错误")")
                return
            }
            do {
                let response = try JSONDecoder().decode(APIResponse<[AppData]>.self, from: data)
                if response.success {
                    DispatchQueue.main.async {
                        self?.apps = response.data
                        self?.collectionView.reloadData()
                    }
                } else {
                    print("API请求失败：\(response.message ?? "未知错误")")
                }
            } catch {
                print("JSON 解析失败：\(error.localizedDescription)")
            }
        }.resume()
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
        guard let cleanUUID = globalDeviceUUID?
            .replacingOccurrences(of: "Optional(\"", with: "")
            .replacingOccurrences(of: "\")", with: ""),
            !cleanUUID.isEmpty else {
            print("设备 UUID 无效")
            return
        }

        guard let url = URL(string: "\(baseURL)/verify") else {
            print("URL构建失败")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "cardKey": code,
            "udid": cleanUUID,
            "appId": app.id
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("请求体序列化失败：\(error.localizedDescription)")
            return
        }

        print("验证卡密：appId=\(app.id), udid=\(cleanUUID)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("验证卡密失败：\(error?.localizedDescription ?? "未知错误")")
                return
            }

            do {
                // 解析返回的数据
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    
                    DispatchQueue.main.async {
                        if success {
                            print("卡密验证成功，获取应用详情")
                            // 验证成功后再次获取应用详情
                            self?.fetchAppDetails(for: app)
                            
                            // 显示成功消息
                            let message = json["message"] as? String ?? "卡密验证成功"
                            let alert = UIAlertController(
                                title: "验证成功",
                                message: message,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                            self?.present(alert, animated: true, completion: nil)
                        } else {
                            let message = json["message"] as? String ?? "请检查卡密是否正确"
                            print("验证失败：\(message)")
                            let alert = UIAlertController(
                                title: "验证失败",
                                message: message,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                            self?.present(alert, animated: true, completion: nil)
                        }
                    }
                } else {
                    print("无法解析验证响应")
                }
            } catch {
                print("解析验证响应失败：\(error.localizedDescription)")
            }
        }.resume()
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

        // 直接获取应用详情，API会根据应用是否需要卡密和UDID状态返回相应信息
        fetchAppDetails(for: app)
    }

    private func fetchAppDetails(for app: AppData) {
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

        // 使用路径参数传递应用ID，使用查询参数传递UDID
        let urlString = "\(baseURL)/apps/\(app.id)?udid=\(encodedUUID)"
        guard let url = URL(string: urlString) else { 
            print("URL构建失败")
            return 
        }
        
        print("获取应用详情: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("获取应用详情失败：\(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<AppData>.self, from: data)
                DispatchQueue.main.async {
                    if response.success {
                        let appWithDetails = response.data
                        
                        // 检查应用是否需要解锁且未解锁
                        if let requiresUnlock = appWithDetails.requiresUnlock, 
                           requiresUnlock && !(appWithDetails.isUnlocked ?? false) {
                            print("应用需要解锁且未解锁")
                            self?.promptUnlockCode(for: app)
                        } else if appWithDetails.plist != nil {
                            // 应用已解锁或不需要解锁，且有plist可以安装
                            print("应用可以安装")
                            self?.startInstallation(for: appWithDetails)
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
                    } else {
                        print("获取应用详情失败：\(response.message ?? "未知错误")")
                        if app.requiresKey {
                            // 如果API返回失败且应用需要卡密，提示输入卡密
                            self?.promptUnlockCode(for: app)
                        }
                    }
                }
            } catch {
                print("解析应用详情响应失败：\(error.localizedDescription)")
            }
        }.resume()
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
        
        let alert = UIAlertController(
            title: "确认安装",
            message: "是否安装 \(app.name)？",
            preferredStyle: .alert
        )

        let installAction = UIAlertAction(title: "安装", style: .default) { _ in
            if let url = URL(string: "itms-services://?action=download-manifest&url=\(plist)") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)

        alert.addAction(installAction)
        alert.addAction(cancelAction)

        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
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
}

// 自定义 Cell
class AppCell: UICollectionViewCell {
    private let appIcon = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let installButton = UIButton(type: .system)
    private let freeLabel = UILabel() // 添加限免标签

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
        
        // 根据requires_key的值决定是否显示限免标签
        if app.requires_key == 0 {
            freeLabel.isHidden = false
            // 针对限免应用，可以同时在版本号旁边显示
            versionLabel.text = "版本 \(app.version) · 限免安装"
            versionLabel.textColor = .systemGreen
            
            // 给限免应用的安装按钮设置不同的样式
            installButton.backgroundColor = .systemGreen
            installButton.setTitle("免费安装", for: .normal)
        } else {
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
        onInstallTapped?()
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
