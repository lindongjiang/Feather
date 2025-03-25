//
//  StoreCollectionViewController.swift
//  AppFlex
//
//  Created by mantou on 2025/2/17.
//  Copyright © 2025 AppFlex. All rights reserved.
//

import UIKit
import SafariServices

// 全局变量，用于存储设备UDID
var globalDeviceUUID: String?

class StoreCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, SFSafariViewControllerDelegate {
    
    struct AppData: Decodable {
        let id: String
        let name: String
        let date: String
        let size: Int
        let version: String
        let build: String
        let icon: String
        let pkg: String
        let plist: String
    }

    private var apps: [AppData] = []
    private var deviceUUID: String {
        return globalDeviceUUID ?? UIDevice.current.identifierForVendor?.uuidString ?? "未知设备"
    }
    private var safariVC: SFSafariViewController?
    private let udidProfileURL = "https://uni.cloudmantoub.online/udid.mobileconfig"
    
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
        
        // 检查是否已经有UDID
        checkForStoredUDID()
        
        fetchAppData()
    }
    
    // 检查是否已经存储了UDID
    private func checkForStoredUDID() {
        if let storedUDID = UserDefaults.standard.string(forKey: "deviceUDID") {
            globalDeviceUUID = storedUDID
            Debug.shared.log(message: "已加载存储的UDID: \(storedUDID)")
        } else {
            Debug.shared.log(message: "未找到存储的UDID，需要获取")
            // 可以选择自动弹出获取UDID的流程
            // showUDIDProfileAlert()
        }
    }
    
    // 打开Safari安装描述文件
    @objc private func getUDIDButtonTapped() {
        showUDIDProfileAlert()
    }
    
    private func showUDIDProfileAlert() {
        let alert = UIAlertController(
            title: "获取设备UDID",
            message: "需要获取您设备的UDID以进行验证。将会安装一个描述文件，请在Safari中点击\"允许\"并按照步骤完成安装。",
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
        
        safariVC = SFSafariViewController(url: url)
        safariVC?.delegate = self
        present(safariVC!, animated: true, completion: nil)
        
        // 注册URL Scheme回调通知，如果应用支持自定义URL Scheme
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUDIDCallback(_:)),
            name: NSNotification.Name("UDIDCallbackReceived"),
            object: nil
        )
    }
    
    @objc private func handleUDIDCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let udid = userInfo["udid"] as? String else {
            return
        }
        
        // 存储UDID
        globalDeviceUUID = udid
        UserDefaults.standard.set(udid, forKey: "deviceUDID")
        Debug.shared.log(message: "成功获取并存储UDID: \(udid)")
        
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
    }

    // 添加手动输入UDID的功能
    @objc private func enterUDIDManually() {
        let alert = UIAlertController(
            title: "手动输入UDID",
            message: "请输入您的设备UDID",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "输入UDID"
        }
        
        let saveAction = UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let textField = alert?.textFields?.first,
                  let udid = textField.text, !udid.isEmpty else {
                return
            }
            
            // 存储UDID
            globalDeviceUUID = udid
            UserDefaults.standard.set(udid, forKey: "deviceUDID")
            Debug.shared.log(message: "手动保存UDID: \(udid)")
            
            // 通知用户
            let successAlert = UIAlertController(
                title: "成功",
                message: "UDID已保存",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            self?.present(successAlert, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }

    private func fetchAppData() {
        guard let url = URL(string: "https://typecho.cloudmantoub.online/api/list") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("数据请求失败：\(error?.localizedDescription ?? "未知错误")")
                return
            }
            do {
                self.apps = try JSONDecoder().decode([AppData].self, from: data)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            } catch {
                print("JSON 解析失败：\(error.localizedDescription)")
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
            
            let enterManuallyAction = UIAlertAction(title: "手动输入", style: .default) { [weak self] _ in
                self?.enterUDIDManually()
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            alert.addAction(getUDIDAction)
            alert.addAction(enterManuallyAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
            return
        }
        
        // 你的处理逻辑
        if let firstApp = apps.first, firstApp.id == app.id {
                self.startInstallation(for: app)
                return
            }
        guard let cleanUUID = globalDeviceUUID?
                   .replacingOccurrences(of: "Optional(\"", with: "")
                   .replacingOccurrences(of: "\")", with: ""),
                   !cleanUUID.isEmpty else {
                   print("设备 UUID 无效")
                   return
               }

               let paymentCheckURL = "https://store.cloudmantoua.top/check-payment/\(cleanUUID)"
               guard let url = URL(string: paymentCheckURL) else { return }
               print("paymentCheckURL消息：\(paymentCheckURL)")
               URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                   guard let data = data, error == nil else {
                       print("查询支付状态失败：\(error?.localizedDescription ?? "未知错误")")
                       return
                   }
                   do {
                       let response = try JSONDecoder().decode(PaymentResponse.self, from: data)
                       DispatchQueue.main.async {
                           if response.isPaid {
                               print("用户已支付，开始安装")
                               self?.startInstallation(for: app)
                           } else {
                               print("用户未支付，提示输入解锁码")
                               self?.promptUnlockCode(for: app)
                           }
                       }
                   } catch {
                       print("解析支付状态响应时发生错误：\(error.localizedDescription)")
                   }
               }.resume()
           }

           private func promptUnlockCode(for app: AppData) {
               let alert = UIAlertController(title: "解锁码", message: "请输入解锁码以继续安装", preferredStyle: .alert)
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

           private func verifyUnlockCode(_ code: String, for app: AppData) {
               guard let cleanUUID = globalDeviceUUID?
                   .replacingOccurrences(of: "Optional(\"", with: "")
                   .replacingOccurrences(of: "\")", with: ""),
                   !cleanUUID.isEmpty else {
                   print("设备 UUID 无效")
                   return
               }
               let verifyURL = "https://store.cloudmantoua.top/verify-card"
               guard var components = URLComponents(string: verifyURL) else { return }
               components.queryItems = [
                   URLQueryItem(name: "UDID", value: cleanUUID),
                   URLQueryItem(name: "code", value: code)
               ]

               guard let url = components.url else {
                   print("构造 URL 失败")
                   return
               }

               var request = URLRequest(url: url)
               request.httpMethod = "POST"

               URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                   if let error = error {
                       print("请求失败：\(error.localizedDescription)")
                       return
                   }

                   guard let data = data else {
                       print("未收到数据")
                       return
                   }

                   do {
                       if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let message = json["message"] as? String {
                           DispatchQueue.main.async {
                               print("服务器返回消息：\(message)")
                               if message == "验证成功" {
                                   print("解锁码验证成功，开始安装")
                                   self?.startInstallation(for: app)
                               } else {
                                   print("验证失败：\(message)")
                               }
                           }
                       } else {
                           print("解析响应失败")
                       }
                   } catch {
                       print("JSON 解析失败：\(error.localizedDescription)")
                   }
               }.resume()
           }

    private func startInstallation(for app: AppData) {
        let alert = UIAlertController(
            title: "确认安装",
            message: "是否安装 \(app.name)？",
            preferredStyle: .alert
        )

        let installAction = UIAlertAction(title: "安装", style: .default) { _ in
            if let url = URL(string: "itms-services://?action=download-manifest&url=\(app.plist)") {
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
        let step2Label = createStepLabel(number: 2, text: "Safari浏览器会打开一个网页，点击\"获取UDID\"，然后在弹出的提示中点击\"允许\"下载配置描述文件")
        
        // 步骤3
        let step3Label = createStepLabel(number: 3, text: "前往设置 -> 通用 -> VPN与设备管理，找到并点击下载的描述文件，然后点击\"安装\"")
        
        // 步骤4
        let step4Label = createStepLabel(number: 4, text: "完成安装后返回Safari浏览器，点击\"获取UDID\"，您的UDID信息会自动返回到Mantou应用")
        
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
}

// 自定义 Cell
class AppCell: UICollectionViewCell {
    private let appIcon = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let installButton = UIButton(type: .system)

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
        versionLabel.text = "版本 \(app.version) (Build \(app.build))"
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

// 数据模型
struct PaymentResponse: Decodable {
    let isPaid: Bool
}
