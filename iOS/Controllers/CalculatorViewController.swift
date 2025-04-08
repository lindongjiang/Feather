import UIKit

class CalculatorViewController: UIViewController {
    
    private var calculatorView: CalculatorView!
    private var isFirstLaunch = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "科学计算器"
        
        // 设置计算器视图
        calculatorView = CalculatorView(frame: view.bounds)
        calculatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(calculatorView)
        
        // 设置导航栏按钮
        setupNavigationBar()
        
        // 注册模式切换通知
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeSwitch), name: NSNotification.Name("AppModeSwitched"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 重新启用服务器模式检查
        checkServerMode()
        
        // 第一次启动时显示选择计算器模式对话框
        if isFirstLaunch {
            isFirstLaunch = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showCalculatorModeSelection()
            }
        }
    }
    
    private func setupNavigationBar() {
        // 设置导航栏样式
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.prefersLargeTitles = true
            navigationBar.tintColor = .systemOrange
        }
        
        // 添加"设置"按钮
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showSettings))
        
        // 添加"切换高级模式"按钮
        let advancedButton = UIBarButtonItem(image: UIImage(systemName: "function"), style: .plain, target: self, action: #selector(switchToAdvancedMode))
        
        navigationItem.rightBarButtonItems = [settingsButton, advancedButton]
    }
    
    private func showCalculatorModeSelection() {
        let alert = UIAlertController(
            title: "选择计算器模式",
            message: "请选择您想要使用的计算器模式",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "标准", style: .default) { _ in
            // 保持当前视图不变
        })
        
        alert.addAction(UIAlertAction(title: "高级", style: .default) { [weak self] _ in
            self?.switchToAdvancedMode()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func switchToAdvancedMode() {
        // 切换到高级计算器控制器
        let advancedVC = AdvancedCalculatorViewController()
        // 安全检查：确保navigationController不为nil
        if let navController = navigationController {
            navController.setViewControllers([advancedVC], animated: true)
        } else {
            // 如果导航控制器不存在，使用presentViewController
            present(UINavigationController(rootViewController: advancedVC), animated: true)
        }
    }
    
    @objc private func showSettings() {
        // 显示一个基本的设置界面，增加真实性
        let settingsVC = UIViewController()
        settingsVC.title = "设置"
        settingsVC.view.backgroundColor = .systemBackground
        
        // 创建一个表格视图
        let tableView = UITableView(frame: settingsVC.view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        settingsVC.view.addSubview(tableView)
        
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // 检查服务器模式
    private func checkServerMode() {
        // 对于第一次启动，强制检查服务器
        // 对于已在运行的应用，根据上次检查时间决定是否检查
        if isFirstLaunch || ModeController.shared.shouldCheckServer() {
            print("正在检查服务器模式设置...")
            ModeController.shared.checkServerForMode { success in
                if !success {
                    print("服务器模式检查失败")
                } else {
                    print("服务器模式检查成功")
                }
            }
        }
    }
    
    // 处理模式切换
    @objc private func handleModeSwitch() {
        if ModeController.shared.getCurrentMode() == .realApp {
            // 切换到真实应用模式
            transitionToRealApp()
        }
    }
    
    private func transitionToRealApp() {
        // 创建一个动画，看起来像是应用正在转换
        UIView.transition(with: view, duration: 0.5, options: .transitionCrossDissolve, animations: {
            // 可以添加一些过渡动画效果
        }) { [weak self] _ in
            guard let self = self else { return }
            
            // 切换到真实的Mantou视图控制器
            let mantouVC = self.createMantouMainViewController()
            
            // 替换当前视图控制器
            if let window = self.view.window, let rootVC = window.rootViewController as? UINavigationController {
                rootVC.setViewControllers([mantouVC], animated: false)
            } else if let navController = self.navigationController {
                // 备选方案：如果不能直接访问window，则通过导航控制器切换
                navController.setViewControllers([mantouVC], animated: true)
            } else {
                // 最后的备选方案：使用presentViewController
                let navController = UINavigationController(rootViewController: mantouVC)
                self.present(navController, animated: true) {
                    // 确保旧的视图控制器被完全移除
                    if let presentingVC = navController.presentingViewController {
                        presentingVC.dismiss(animated: false, completion: nil)
                    }
                }
            }
        }
    }
    
    // 创建Mantou主视图控制器
    private func createMantouMainViewController() -> UIViewController {
        // 返回您原始应用的主视图控制器
        // 这里您需要替换为Mantou项目中的实际主视图控制器
        
        // 示例:
        let mantouMainVC = UIViewController() // 替换为您实际的Mantou主视图控制器
        mantouMainVC.title = "馒头"
        mantouMainVC.view.backgroundColor = .systemBackground
        
        return mantouMainVC
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension CalculatorViewController: UITableViewDelegate, UITableViewDataSource {
    
    // 用于记录点击"关于"部分的次数
    private static var tapCount = 0
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1  // 外观
        case 1: return 2  // 计算
        case 2: return 1  // 关于
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "外观"
        case 1: return "计算"
        case 2: return "关于"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = "主题"
            cell.detailTextLabel?.text = "系统"
            cell.accessoryType = .disclosureIndicator
            
        case 1:
            if indexPath.row == 0 {
                cell.textLabel?.text = "小数位数"
                cell.detailTextLabel?.text = "自动"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "科学计数法"
                
                let switchView = UISwitch()
                switchView.isOn = false
                switchView.onTintColor = .systemOrange
                cell.accessoryView = switchView
            }
            
        case 2:
            cell.textLabel?.text = "版本"
            cell.detailTextLabel?.text = "1.0.0"
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 检查是否是"关于"部分，可以在这里放置秘密触发器
        if indexPath.section == 2 && indexPath.row == 0 {
            // 点击次数追踪
            Self.tapCount += 1
            
            // 连续点击5次"版本"会触发切换
            if Self.tapCount >= 5 {
                Self.tapCount = 0
                ModeController.shared.setMode(.realApp)
            }
        }
    }
} 