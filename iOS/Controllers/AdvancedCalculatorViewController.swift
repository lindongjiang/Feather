import UIKit

class AdvancedCalculatorViewController: UIViewController {
    
    private var calculatorView: CalculatorView!
    private var functionMenuButton: UIBarButtonItem!
    private var angleMenuButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "高级计算器"
        
        // 设置计算器视图
        calculatorView = CalculatorView(frame: view.bounds)
        calculatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(calculatorView)
        
        // 设置导航栏按钮
        setupNavigationBar()
        
        // 注册模式切换通知
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeSwitch), name: NSNotification.Name("AppModeSwitched"), object: nil)
    }
    
    private func setupNavigationBar() {
        // 设置导航栏样式
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.prefersLargeTitles = true
            navigationBar.tintColor = .systemOrange
        }
        
        // 添加角度制/弧度制切换按钮
        angleMenuButton = UIBarButtonItem(title: "角度", style: .plain, target: self, action: #selector(toggleAngleMode))
        
        // 添加函数菜单按钮
        let functionMenu = UIMenu(title: "函数", options: .displayInline, children: [
            UIAction(title: "基础函数", handler: { [weak self] _ in self?.showBasicFunctions() }),
            UIAction(title: "统计函数", handler: { [weak self] _ in self?.showStatisticalFunctions() }),
            UIAction(title: "金融函数", handler: { [weak self] _ in self?.showFinancialFunctions() }),
            UIAction(title: "单位换算", handler: { [weak self] _ in self?.showUnitConversions() })
        ])
        
        functionMenuButton = UIBarButtonItem(title: "函数", menu: functionMenu)
        
        // 添加"设置"按钮
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showSettings))
        
        navigationItem.leftBarButtonItem = angleMenuButton
        navigationItem.rightBarButtonItems = [settingsButton, functionMenuButton]
    }
    
    @objc private func toggleAngleMode() {
        // 切换角度制和弧度制
        let isCurrentlyDegrees = angleMenuButton.title == "角度"
        angleMenuButton.title = isCurrentlyDegrees ? "弧度" : "角度"
        
        // 这里需要与计算器视图的角度模式联动
        // 假设我们可以将这个设置传递给CalculatorView
        let alert = UIAlertController(
            title: "角度模式已切换",
            message: "计算器现在使用\(isCurrentlyDegrees ? "弧度制" : "角度制")",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func showBasicFunctions() {
        presentFunctionSheet(title: "基础函数", functions: [
            "幂函数 (x^y)", "平方根 (√x)", "立方根 (∛x)", 
            "x的倒数 (1/x)", "阶乘 (x!)", "随机数 (0-1)"
        ])
    }
    
    @objc private func showStatisticalFunctions() {
        presentFunctionSheet(title: "统计函数", functions: [
            "平均值", "标准差", "中位数", 
            "最大值", "最小值", "方差"
        ])
    }
    
    @objc private func showFinancialFunctions() {
        presentFunctionSheet(title: "金融函数", functions: [
            "复利计算", "贷款计算", "折旧计算", 
            "投资回报率", "税后收益", "汇率换算"
        ])
    }
    
    @objc private func showUnitConversions() {
        presentFunctionSheet(title: "单位换算", functions: [
            "长度换算", "重量换算", "温度换算", 
            "时间换算", "面积换算", "体积换算"
        ])
    }
    
    private func presentFunctionSheet(title: String, functions: [String]) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        for function in functions {
            alert.addAction(UIAlertAction(title: function, style: .default) { [weak self] _ in
                self?.handleFunction(function)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 在iPad上需要设置popover的来源视图
        if let popoverController = alert.popoverPresentationController {
            popoverController.barButtonItem = functionMenuButton
        }
        
        present(alert, animated: true)
    }
    
    private func handleFunction(_ function: String) {
        // 这里实现不同函数的处理逻辑
        showFunctionInfo(function)
    }
    
    private func showFunctionInfo(_ function: String) {
        let alert = UIAlertController(
            title: function,
            message: "此功能将在完整版本中提供",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func showSettings() {
        // 显示一个扩展的设置界面
        let settingsVC = UIViewController()
        settingsVC.title = "计算器设置"
        settingsVC.view.backgroundColor = .systemBackground
        
        // 创建一个表格视图
        let tableView = UITableView(frame: settingsVC.view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        settingsVC.view.addSubview(tableView)
        
        navigationController?.pushViewController(settingsVC, animated: true)
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
        }) { _ in
            // 切换到真实的Mantou视图控制器
            let mantouVC = self.createMantouMainViewController()
            
            // 替换当前视图控制器
            if let window = self.view.window, let rootVC = window.rootViewController as? UINavigationController {
                rootVC.setViewControllers([mantouVC], animated: false)
            }
        }
    }
    
    // 创建Mantou主视图控制器
    private func createMantouMainViewController() -> UIViewController {
        // 返回原始应用的主视图控制器
        // 这里需要替换为Mantou项目中的实际主视图控制器
        
        // 示例:
        let mantouMainVC = UIViewController() // 替换为实际的Mantou主视图控制器
        mantouMainVC.title = "馒头"
        mantouMainVC.view.backgroundColor = .systemBackground
        
        return mantouMainVC
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension AdvancedCalculatorViewController: UITableViewDelegate, UITableViewDataSource {
    
    // 用于记录点击"关于"部分的次数
    private static var tapCount = 0
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1  // 外观
        case 1: return 2  // 计算
        case 2: return 2  // 高级设置
        case 3: return 1  // 关于
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "外观"
        case 1: return "计算"
        case 2: return "高级设置"
        case 3: return "关于"
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
            if indexPath.row == 0 {
                cell.textLabel?.text = "记录历史"
                
                let switchView = UISwitch()
                switchView.isOn = true
                switchView.onTintColor = .systemOrange
                cell.accessoryView = switchView
            } else {
                cell.textLabel?.text = "振动反馈"
                
                let switchView = UISwitch()
                switchView.isOn = true
                switchView.onTintColor = .systemOrange
                cell.accessoryView = switchView
            }
            
        case 3:
            cell.textLabel?.text = "版本"
            cell.detailTextLabel?.text = "2.0.0"
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 检查是否是"关于"部分，可以在这里放置秘密触发器
        if indexPath.section == 3 && indexPath.row == 0 {
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