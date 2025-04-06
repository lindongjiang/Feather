//
//  AppDelegate.swift
//  mantou
//
//  Created by samara on 5/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import BackgroundTasks
import CoreData
import Foundation
import Nuke
import SwiftUI
import UIKit
import UIOnboarding
import Darwin // 添加Darwin导入，用于open函数和O_EVTONLY常量

var downloadTaskManager = DownloadTaskManager.shared
class AppDelegate: UIResponder, UIApplicationDelegate, UIOnboardingViewControllerDelegate {
    static let isSideloaded = Bundle.main.bundleIdentifier != "com.mantou.app"
    var window: UIWindow?
    var loaderAlert = presentLoader()
    
    // 在应用启动过程中使用一个加载指示器，同时检查应用模式
    private var loadingViewController: UIViewController?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let userDefaults = UserDefaults.standard

        userDefaults.set(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, forKey: "currentVersion")

        if userDefaults.data(forKey: UserDefaults.signingDataKey) == nil {
            userDefaults.signingOptions = UserDefaults.defaultSigningData
        }
        
        // 检查是否存储了UDID
        if let udid = userDefaults.string(forKey: "deviceUDID") {
            globalDeviceUUID = udid
            Debug.shared.log(message: "已加载存储的UDID: \(udid)")
        }

		createSourcesDirectory()
        addDefaultRepos()
		giveUserDefaultSSLCerts()
        imagePipline()
        setupLogFile()
        cleanTmp()

        window = UIWindow(frame: UIScreen.main.bounds)
        
        // 先显示加载画面
        loadingViewController = createLoadingView()
        window?.rootViewController = loadingViewController
        window?.makeKeyAndVisible()
        
        // 检查应用模式并加载相应界面
        checkAppModeAndSetupUI()

        let generatedString = AppDelegate.generateRandomString()
        if Preferences.pPQCheckString.isEmpty {
            Preferences.pPQCheckString = generatedString
        }

        Debug.shared.log(message: "Version: \(UIDevice.current.systemVersion)")
        Debug.shared.log(message: "Name: \(UIDevice.current.name)")
        Debug.shared.log(message: "Model: \(UIDevice.current.model)")
        Debug.shared.log(message: "Mantou Version: \(logAppVersionInfo())\n")

		if Preferences.appUpdates {
			// Register background task
			BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.mantou.app.sourcerefresh", using: nil) { task in
				self.handleAppRefresh(task: task as! BGAppRefreshTask)
			}
			scheduleAppRefresh()
			
			let backgroundQueue = OperationQueue()
			backgroundQueue.qualityOfService = .background
			let operation = SourceRefreshOperation()
			backgroundQueue.addOperation(operation)
		}
        
        // 注册应用模式变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppModeChange),
            name: NSNotification.Name("AppModeDidChangeNotification"),
            object: nil
        )

        return true
    }
    
    // 创建加载视图
    private func createLoadingView() -> UIViewController {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "应用加载中..."
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18)
        
        loadingVC.view.addSubview(activityIndicator)
        loadingVC.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingVC.view.centerYAnchor, constant: -20),
            
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            label.leadingAnchor.constraint(equalTo: loadingVC.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: loadingVC.view.trailingAnchor, constant: -20)
        ])
        
        return loadingVC
    }
    
    // 检查应用模式并设置相应界面
    private func checkAppModeAndSetupUI() {
        // 检查服务器配置
        AppModeManager.shared.checkServerConfiguration { [weak self] modeChanged in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.setupUIBasedOnAppMode()
                
                // 设置应用界面颜色
                self.window!.tintColor = Preferences.appTintColor.uiColor
                self.window!.overrideUserInterfaceStyle = UIUserInterfaceStyle(rawValue: Preferences.preferredInterfaceStyle) ?? .unspecified
            }
        }
    }
    
    // 设置基于应用模式的UI
    private func setupUIBasedOnAppMode() {
        // 判断当前应用模式
        if AppModeManager.shared.isNormalMode {
            // 正常模式 - 显示原有功能
            if Preferences.isOnboardingActive {
                let onboardingController: UIOnboardingViewController = .init(withConfiguration: .setUp())
                onboardingController.delegate = self
                
                animateRootViewControllerChange(to: onboardingController)
            } else {
                let tabBarController = UIHostingController(rootView: TabbarView())
                
                animateRootViewControllerChange(to: tabBarController)
            }
        } else {
            // 伪装模式 - 显示壁纸应用
            let disguisedController = UIHostingController(rootView: DisguisedTabbarView())
            
            animateRootViewControllerChange(to: disguisedController)
        }
    }
    
    // 动画切换根视图控制器
    private func animateRootViewControllerChange(to viewController: UIViewController) {
        // 使用淡入淡出动画切换
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.3
        
        window?.layer.add(transition, forKey: kCATransition)
        window?.rootViewController = viewController
    }
    
    // 处理应用模式变化通知
    @objc private func handleAppModeChange(_ notification: Notification) {
        // 当模式变化时，重新设置UI
        setupUIBasedOnAppMode()
    }

    func applicationWillEnterForeground(_: UIApplication) {
        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = .background
        let operation = SourceRefreshOperation()
        backgroundQueue.addOperation(operation)
        
        // 应用回到前台时检查应用模式
        AppModeManager.shared.checkServerConfiguration { [weak self] modeChanged in
            // 如果模式发生变化，会自动通过通知触发UI更新
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.mantou.app.sourcerefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            Debug.shared.log(message: "Background refresh scheduled successfully", type: .info)
        } catch {
            Debug.shared.log(message: "Could not schedule app refresh: \(error.localizedDescription)", type: .info)
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = .background
        let operation = SourceRefreshOperation()

        task.expirationHandler = {
            operation.cancel()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        backgroundQueue.addOperation(operation)
    }

    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "mantou" {
            // I know this is super hacky, honestly
            // I don't *exactly* care as it just works :shrug:
            if let config = url.absoluteString.range(of: "/source/") {
                let fullPath = String(url.absoluteString[config.upperBound...])

                if fullPath.starts(with: "https://") {
                    CoreDataManager.shared.getSourceData(urlString: fullPath) { error in
                        if let error {
                            Debug.shared.log(message: "SourcesViewController.sourcesAddButtonTapped: \(error)", type: .critical)
                        } else {
                            Debug.shared.log(message: "Successfully added!", type: .success)
                            NotificationCenter.default.post(name: Notification.Name("sfetch"), object: nil)
                        }
                    }
                } else {
                    Debug.shared.log(message: "Invalid or non-HTTPS URL", type: .error)
                }
            } else if let config = url.absoluteString.range(of: "/install/") {
                let fullPath = String(url.absoluteString[config.upperBound...])
                
                if fullPath.starts(with: "https://") {
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootViewController = scene.windows.first?.rootViewController else {
                        return false
                    }
                    
                    DispatchQueue.main.async {
                        rootViewController.present(self.loaderAlert, animated: true)
                    }
                    
                    DispatchQueue.global(qos: .background).async {
                        do {
                            let tempDirectory = FileManager.default.temporaryDirectory
                            let uuid = UUID().uuidString
                            let destinationURL = tempDirectory.appendingPathComponent("\(uuid).ipa")
                            
                            // Download the file
                            if let data = try? Data(contentsOf: URL(string: fullPath)!) {
                                try data.write(to: destinationURL)
                                
                                let dl = AppDownload()
                                try handleIPAFile(destinationURL: destinationURL, uuid: uuid, dl: dl)
                                
                                DispatchQueue.main.async {
                                    self.loaderAlert.dismiss(animated: true) {
                                        let downloadedApps = CoreDataManager.shared.getDatedDownloadedApps()
                                        if let downloadedApp = downloadedApps.first(where: { $0.uuid == uuid }) {
                                            let signingDataWrapper = SigningDataWrapper(signingOptions: UserDefaults.standard.signingOptions)
                                            signingDataWrapper.signingOptions.installAfterSigned = true
                                            
                                            let libraryVC = LibraryViewController()
                                            let ap = SigningsViewController(
                                                signingDataWrapper: signingDataWrapper,
                                                application: downloadedApp,
                                                appsViewController: libraryVC
                                            )
                                            
                                            ap.signingCompletionHandler = { success in
                                                if success {
                                                    if let workspace = LSApplicationWorkspace.default() {
                                                        if let bundleId = downloadedApp.bundleidentifier {
                                                            workspace.openApplication(withBundleID: bundleId)
                                                        }
                                                    }
                                                    libraryVC.fetchSources()
                                                    libraryVC.tableView.reloadData()
                                                }
                                            }
                                            
                                            let navigationController = UINavigationController(rootViewController: ap)
                                            
											navigationController.shouldPresentFullScreen()
                                            
                                            rootViewController.present(navigationController, animated: true)
                                        }
                                    }
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.loaderAlert.dismiss(animated: true)
                                Debug.shared.log(message: "Failed to handle IPA file: \(error)", type: .error)
                            }
                        }
                    }
                } else {
                    Debug.shared.log(message: "Invalid or non-HTTPS URL", type: .error)
                }
            } else if let config = url.absoluteString.range(of: "/udid/") {
                // 处理UDID回调
                let fullPath = String(url.absoluteString[config.upperBound...])
                
                if let udid = extractUDID(from: fullPath) {
                    // 保存UDID
                    globalDeviceUUID = udid
                    UserDefaults.standard.set(udid, forKey: "deviceUDID")
                    Debug.shared.log(message: "成功获取并保存UDID: \(udid)")
                    
                    // 通知UI更新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UDIDCallbackReceived"),
                        object: nil,
                        userInfo: ["udid": udid]
                    )
                }
                
                return true
            }

            return true
        }
        // bwah
        if url.pathExtension == "ipa" {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = scene.windows.first?.rootViewController else {
                return false
            }

            DispatchQueue.main.async {
                rootViewController.present(self.loaderAlert, animated: true)
            }

            DispatchQueue.global(qos: .background).async {
                do {
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let destinationURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: destinationURL)

                    let dl = AppDownload()
                    let uuid = UUID().uuidString

                    try handleIPAFile(destinationURL: destinationURL, uuid: uuid, dl: dl)

                    DispatchQueue.main.async {
                        self.loaderAlert.dismiss(animated: true)
                        Debug.shared.log(message: "Moved IPA file to: \(destinationURL)")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.loaderAlert.dismiss(animated: true)
                        Debug.shared.log(message: "Failed to move IPA file: \(error)")
                    }
                }
            }

            return true
        }

        return false
    }
    
    // 从URL中提取UDID
    private func extractUDID(from urlString: String) -> String? {
        // 直接返回urlString，因为PHP重定向的格式是mantou://udid/UDID值
        // 所以urlString就是UDID本身
        return urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 以下旧代码已不再需要
        /*
        // 简单解析示例，实际情况可能需要根据服务器返回格式调整
        let components = urlString.components(separatedBy: "=")
        if components.count >= 2, components[0].lowercased().contains("udid") {
            return components[1]
        }
        
        // 如果无法解析，尝试URL解码并查找
        if let decodedString = urlString.removingPercentEncoding {
            // 使用正则表达式查找UDID格式的字符串
            let pattern = "[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: decodedString, range: NSRange(decodedString.startIndex..., in: decodedString)) {
                let matchedString = String(decodedString[Range(match.range, in: decodedString)!])
                return matchedString
            }
        }
        
        return nil
        */
    }

    func didFinishOnboarding(onboardingViewController _: UIOnboardingViewController) {
        Preferences.isOnboardingActive = false

        // 只在正常模式下才显示TabbarView
        if AppModeManager.shared.isNormalMode {
            let tabBarController = UIHostingController(rootView: TabbarView())
            
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.3
            
            window?.layer.add(transition, forKey: kCATransition)
            window?.rootViewController = tabBarController
        }
    }

    fileprivate func addDefaultRepos() {
        if !Preferences.defaultRepos {
            CoreDataManager.shared.saveSource(
                name: "Mantou Repository",
                id: "com.mantou.app-repo",
                iconURL: URL(string: "https://uni.cloudmantoub.online/512@2x.png"),
                url:"https://uni.cloudmantoub.online/source.json"
            ) { _ in
                Debug.shared.log(message: "Added default repos!")
                Preferences.defaultRepos = true
            }
        }
    }
	
	fileprivate func giveUserDefaultSSLCerts() {
		if !Preferences.gotSSLCerts {
			getCertificates()
			Preferences.gotSSLCerts = true
		}
	}

    fileprivate static func generateRandomString(length: Int = 8) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< length).map { _ in characters.randomElement()! })
    }

    func createSourcesDirectory() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let sourcesURL = documentsURL.appendingPathComponent("Apps")
            let certsURL = documentsURL.appendingPathComponent("Certificates")
            let importedIPAsURL = documentsURL.appendingPathComponent("ImportedIPAs", isDirectory: true)

            if !fileManager.fileExists(atPath: sourcesURL.path) {
                do { try! fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true, attributes: nil) }
            }
            if !fileManager.fileExists(atPath: certsURL.path) {
                do { try! fileManager.createDirectory(at: certsURL, withIntermediateDirectories: true, attributes: nil) }
            }
            if !fileManager.fileExists(atPath: importedIPAsURL.path) {
                do { try! fileManager.createDirectory(at: importedIPAsURL, withIntermediateDirectories: true, attributes: nil) }
            }
            
            // 设置文件监听器
            setupImportedIPAsDirectoryMonitor(at: importedIPAsURL)
        }
    }

    // 监听ImportedIPAs目录的变化，自动导入新文件
    private var directoryMonitor: DispatchSourceFileSystemObject?
    
    private func setupImportedIPAsDirectoryMonitor(at url: URL) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        if fileDescriptor < 0 {
            return
        }
        
        // 创建目录变化的监听器
        directoryMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        // 当目录内容发生变化时处理
        directoryMonitor?.setEventHandler { [weak self] in
            self?.checkForNewIPAFiles(in: url)
        }
        
        directoryMonitor?.setCancelHandler {
            close(fileDescriptor)
        }
        
        directoryMonitor?.resume()
        
        // 初始检查一次目录
        checkForNewIPAFiles(in: url)
    }
    
    private func checkForNewIPAFiles(in directoryURL: URL) {
        do {
            let fileManager = FileManager.default
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            
            // 过滤出IPA文件
            let ipaFiles = fileURLs.filter { $0.pathExtension.lowercased() == "ipa" }
            
            for ipaURL in ipaFiles {
                let uuid = UUID().uuidString
                
                // 将IPA文件复制到临时目录
                let tempDirectory = FileManager.default.temporaryDirectory
                let destinationURL = tempDirectory.appendingPathComponent(ipaURL.lastPathComponent)
                
                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    
                    try fileManager.copyItem(at: ipaURL, to: destinationURL)
                    
                    // 使用已有的处理逻辑导入IPA
                    let dl = AppDownload()
                    try handleIPAFile(destinationURL: destinationURL, uuid: uuid, dl: dl)
                    
                    // 导入成功后删除原文件，避免重复导入
                    try fileManager.removeItem(at: ipaURL)
                    
                    Debug.shared.log(message: "自动导入IPA文件成功: \(ipaURL.lastPathComponent)", type: .success)
                } catch {
                    Debug.shared.log(message: "自动导入IPA文件失败: \(error.localizedDescription)", type: .error)
                }
            }
        } catch {
            Debug.shared.log(message: "检查ImportedIPAs目录失败: \(error.localizedDescription)", type: .error)
        }
    }

    func imagePipline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = {
                let config = URLSessionConfiguration.default
                config.urlCache = nil
                return DataLoader(configuration: config)
            }()
            let dataCache = try? DataCache(name: "com.mantou.app.datacache") // disk cache
            let imageCache = Nuke.ImageCache() // memory cache
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataLoader = dataLoader
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }
        ImagePipeline.shared = pipeline
    }

    func setupLogFile() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        if FileManager.default.fileExists(atPath: logFilePath.path) {
            do {
                try FileManager.default.removeItem(at: logFilePath)
            } catch {
                Debug.shared.log(message: "Error removing existing logs.txt: \(error)", type: .error)
            }
        }

        do {
            try "".write(to: logFilePath, atomically: true, encoding: .utf8)
        } catch {
            Debug.shared.log(message: "Error removing existing logs.txt: \(error)", type: .error)
        }
    }

    func cleanTmp() {
        let fileManager = FileManager.default
        let tmpDirectory = NSHomeDirectory() + "/tmp"

        if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory) {
            for file in files {
                try? fileManager.removeItem(atPath: tmpDirectory + "/" + file)
            }
        }
    }

    public func logAppVersionInfo() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
            return "App Version: \(version) (\(build))"
        }
        return ""
    }
}

extension UIOnboardingViewConfiguration {
    static func setUp() -> Self {
        let welcomeToLine = NSMutableAttributedString(string: String.localized("ONBOARDING_WELCOMETITLE_1"))
        let featherLine = NSMutableAttributedString(string: "Mantou", attributes: [
            .foregroundColor: UIColor.tintColor,
        ])

        let featureStyle = UIOnboardingFeatureStyle(
            titleFontName: "",
            titleFontSize: 17,
            descriptionFontName: "",
            descriptionFontSize: 16,
            spacing: 0.8
        )

        let onboardingFeatures: [UIOnboardingFeature] = [
            .init(
                icon: UIImage(systemName: "arrow.down.app.fill")!,
                iconTint: .label,
                title: String.localized("ONBOARDING_CELL_1_TITLE"),
                description: String.localized("ONBOARDING_CELL_1_DESCRIPTION")
            ),
            .init(
                icon: UIImage(systemName: "sparkles.square.filled.on.square")!,
                iconTint: .tintColor,
                title: String.localized("ONBOARDING_CELL_2_TITLE"),
                description: String.localized("ONBOARDING_CELL_2_DESCRIPTION")
            ),
            .init(
                icon: UIImage(systemName: "sparkles")!,
                iconTint: .systemYellow,
                title: String.localized("ONBOARDING_CELL_3_TITLE"),
                description: String.localized("ONBOARDING_CELL_3_DESCRIPTION")
            ),
        ]

        let text = UIOnboardingTextViewConfiguration(
            text: String.localized("ONBOARDING_FOOTER"),
            linkTitle: String.localized("ONBOARDING_FOOTER_LINK"),
            link: "https://cloudmantoub.online/",
            tint: .tintColor
        )

        return .init(
            appIcon: .init(named: "AppIcon60x60")!,
            firstTitleLine: welcomeToLine,
            secondTitleLine: featherLine,
            features: onboardingFeatures,
            featureStyle: featureStyle,
            textViewConfiguration: text,
            buttonConfiguration: .init(title: String.localized("ONBOARDING_CONTINUE_BUTTON"), backgroundColor: .tintColor)
        )
    }
}
