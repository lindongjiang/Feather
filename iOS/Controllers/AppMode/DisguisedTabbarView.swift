//
//  DisguisedTabbarView.swift
//  mantou
//
//  Created by samara on 6/26/24.
//

import SwiftUI

// 伪装模式下的TabBar视图
struct DisguisedTabbarView: View {
    @State private var selectedTab: Tab = Tab(rawValue: UserDefaults.standard.string(forKey: "disguisedSelectedTab") ?? "home") ?? .home
    
    enum Tab: String {
        case home     // 主页
        case gallery  // 图库
        case tools    // 工具
        case profile  // 个人
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            tab(for: .home)
            tab(for: .gallery)
            tab(for: .tools)
            tab(for: .profile)
        }
        .onChange(of: selectedTab) { newTab in
            UserDefaults.standard.set(newTab.rawValue, forKey: "disguisedSelectedTab")
        }
    }
    
    @ViewBuilder
    func tab(for tab: Tab) -> some View {
        switch tab {
        case .home:
            DisguisedNavigationViewController(DisguisedHomeViewController.self, title: "馒头壁纸")
                .edgesIgnoringSafeArea(.all)
                .tabItem {
                    Label("壁纸", systemImage: "photo.fill")
                }
                .tag(Tab.home)
        case .gallery:
            DisguisedNavigationViewController(DisguisedGalleryViewController.self, title: "我的图库")
                .edgesIgnoringSafeArea(.all)
                .tabItem {
                    Label("图库", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.gallery)
        case .tools:
            DisguisedNavigationViewController(DisguisedToolsViewController.self, title: "工具箱")
                .edgesIgnoringSafeArea(.all)
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(Tab.tools)
        case .profile:
            DisguisedNavigationViewController(DisguisedProfileViewController.self, title: "个人中心")
                .edgesIgnoringSafeArea(.all)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

// NavigationViewController包装器 - 重命名为DisguisedNavigationViewController
struct DisguisedNavigationViewController<T: UIViewController>: UIViewControllerRepresentable {
    let controllerType: T.Type
    let title: String
    
    init(_ controllerType: T.Type, title: String) {
        self.controllerType = controllerType
        self.title = title
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let viewController = controllerType.init()
        viewController.title = title
        let navigationController = UINavigationController(rootViewController: viewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let viewController = uiViewController.viewControllers.first {
            viewController.title = title
        }
    }
}

// 伪装模式下的各个主要视图控制器（基本实现）

// 伪装主页 - 壁纸应用
class DisguisedHomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private var wallpapers: [WallpaperItem] = []
    private var categories = ["推荐", "风景", "动物", "城市", "抽象", "汽车", "艺术"]
    private var selectedCategory = 0
    private var categoryCollection: UICollectionView!
    
    struct WallpaperItem {
        let image: String
        let title: String
        let category: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMockData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 设置分类选择器
        let categoryLayout = UICollectionViewFlowLayout()
        categoryLayout.scrollDirection = .horizontal
        categoryLayout.minimumLineSpacing = 15
        categoryLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        categoryCollection = UICollectionView(frame: .zero, collectionViewLayout: categoryLayout)
        categoryCollection.backgroundColor = .systemBackground
        categoryCollection.showsHorizontalScrollIndicator = false
        categoryCollection.delegate = self
        categoryCollection.dataSource = self
        categoryCollection.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoryCollection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(categoryCollection)
        
        // 设置壁纸网格
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(WallpaperCell.self, forCellWithReuseIdentifier: "WallpaperCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            categoryCollection.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            categoryCollection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryCollection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryCollection.heightAnchor.constraint(equalToConstant: 50),
            
            collectionView.topAnchor.constraint(equalTo: categoryCollection.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 添加刷新控件
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWallpapers), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func loadMockData() {
        // 模拟从服务器加载壁纸数据
        wallpapers = [
            WallpaperItem(image: "wallpaper1", title: "山水画卷", category: "风景"),
            WallpaperItem(image: "wallpaper2", title: "海滩日落", category: "风景"),
            WallpaperItem(image: "wallpaper3", title: "星空夜景", category: "风景"),
            WallpaperItem(image: "wallpaper4", title: "城市夜景", category: "城市"),
            WallpaperItem(image: "wallpaper5", title: "萌宠合集", category: "动物"),
            WallpaperItem(image: "wallpaper6", title: "艺术图案", category: "艺术"),
            WallpaperItem(image: "wallpaper7", title: "炫彩抽象", category: "抽象"),
            WallpaperItem(image: "wallpaper8", title: "超跑合集", category: "汽车")
        ]
        collectionView.reloadData()
    }
    
    @objc private func refreshWallpapers() {
        // 模拟刷新操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.loadMockData()
            self.collectionView.refreshControl?.endRefreshing()
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoryCollection {
            return categories.count
        } else {
            if selectedCategory == 0 {
                return wallpapers.count
            } else {
                let category = categories[selectedCategory]
                return wallpapers.filter { $0.category == category }.count
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoryCollection {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            cell.configure(with: categories[indexPath.item], isSelected: indexPath.item == selectedCategory)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WallpaperCell", for: indexPath) as! WallpaperCell
            
            var filteredWallpapers = wallpapers
            if selectedCategory != 0 {
                let category = categories[selectedCategory]
                filteredWallpapers = wallpapers.filter { $0.category == category }
            }
            
            if indexPath.item < filteredWallpapers.count {
                cell.configure(with: filteredWallpapers[indexPath.item])
            }
            return cell
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoryCollection {
            selectedCategory = indexPath.item
            categoryCollection.reloadData()
            self.collectionView.reloadData()
        } else {
            // 展示壁纸详情
            var filteredWallpapers = wallpapers
            if selectedCategory != 0 {
                let category = categories[selectedCategory]
                filteredWallpapers = wallpapers.filter { $0.category == category }
            }
            
            // 检查数组索引是否有效
            guard indexPath.item < filteredWallpapers.count else { return }
            
            let detailVC = DisguisedWallpaperDetailViewController()
            detailVC.wallpaper = filteredWallpapers[indexPath.item]
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoryCollection {
            let categoryText = categories[indexPath.item]
            let width = categoryText.size(withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .medium)]).width + 30
            return CGSize(width: width, height: 40)
        } else {
            let width = (view.frame.width - 30) / 2
            return CGSize(width: width, height: width * 1.5)
        }
    }
}

// 分类Cell
class CategoryCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .systemGray6
        contentView.layer.cornerRadius = 20
        
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with title: String, isSelected: Bool) {
        titleLabel.text = title
        if isSelected {
            contentView.backgroundColor = .systemBlue
            titleLabel.textColor = .white
        } else {
            contentView.backgroundColor = .systemGray6
            titleLabel.textColor = .label
        }
    }
}

// 壁纸Cell
class WallpaperCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .systemGray6
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(with wallpaper: DisguisedHomeViewController.WallpaperItem) {
        titleLabel.text = wallpaper.title
        
        // 模拟壁纸图片
        // 在实际应用中，这里应该加载真实的图片
        // 这里我们使用了模拟的图片名称，您需要替换为实际的图片资源
        imageView.backgroundColor = randomColor()
    }
    
    private func randomColor() -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPink, .systemPurple, .systemTeal]
        return colors.randomElement() ?? .systemBlue
    }
}

// 壁纸详情页
class DisguisedWallpaperDetailViewController: UIViewController {
    var wallpaper: DisguisedHomeViewController.WallpaperItem?
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let downloadButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = wallpaper?.title ?? "壁纸详情"
        
        // 设置图片视图
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = randomColor()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // 设置标题标签
        titleLabel.text = wallpaper?.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // 设置下载按钮
        downloadButton.setTitle("下载壁纸", for: .normal)
        downloadButton.backgroundColor = .systemBlue
        downloadButton.setTitleColor(.white, for: .normal)
        downloadButton.layer.cornerRadius = 12
        downloadButton.addTarget(self, action: #selector(downloadWallpaper), for: .touchUpInside)
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            downloadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            downloadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            downloadButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            downloadButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func downloadWallpaper() {
        // 模拟下载操作
        let alertController = UIAlertController(title: "下载中", message: "正在下载壁纸...", preferredStyle: .alert)
        present(alertController, animated: true)
        
        // 模拟下载完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            alertController.dismiss(animated: true) {
                let successAlert = UIAlertController(title: "下载成功", message: "壁纸已保存至您的相册", preferredStyle: .alert)
                successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(successAlert, animated: true)
            }
        }
    }
    
    private func randomColor() -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPink, .systemPurple, .systemTeal]
        return colors.randomElement() ?? .systemBlue
    }
}

// 图库页面
class DisguisedGalleryViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        let label = UILabel()
        label.text = "我的图库 - 敬请期待"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// 工具页面
class DisguisedToolsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        let label = UILabel()
        label.text = "图片工具 - 敬请期待"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// 个人中心页面
class DisguisedProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var tableView: UITableView!
    private let sections = ["账户信息", "应用设置", "关于我们"]
    private let rows = [
        ["个人资料", "我的收藏", "消息通知"],
        ["主题设置", "隐私设置", "清除缓存"],
        ["应用评分", "关于馒头壁纸", "检查更新"]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        // 设置表格视图
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 添加头部视图
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 150))
        
        let profileImageView = UIImageView(frame: CGRect(x: (view.frame.width - 80) / 2, y: 20, width: 80, height: 80))
        profileImageView.backgroundColor = .systemGray4
        profileImageView.layer.cornerRadius = 40
        profileImageView.clipsToBounds = true
        headerView.addSubview(profileImageView)
        
        let nameLabel = UILabel(frame: CGRect(x: 0, y: 110, width: view.frame.width, height: 30))
        nameLabel.text = "用户名"
        nameLabel.textAlignment = .center
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        headerView.addSubview(nameLabel)
        
        tableView.tableHeaderView = headerView
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows[section].count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        cell.accessoryType = .disclosureIndicator
        
        // 添加一些模拟数据
        if indexPath.section == 0 && indexPath.row == 2 {
            cell.detailTextLabel?.text = "5"
            cell.detailTextLabel?.textColor = .systemRed
        } else if indexPath.section == 1 && indexPath.row == 0 {
            cell.detailTextLabel?.text = "深色"
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 处理特殊情况：显示隐藏的开发者菜单
        if indexPath.section == 2 && indexPath.row == 1 {
            // 连续点击5次可以进入开发者模式
            DevModeManager.shared.registerTap()
        } else if indexPath.section == 1 && indexPath.row == 2 {
            // 清除缓存
            let alert = UIAlertController(title: "清除缓存", message: "缓存已清除", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
}

// 开发者模式管理器
class DevModeManager {
    static let shared = DevModeManager()
    
    private var tapCount = 0
    private var lastTapTime: Date = .distantPast
    private let tapTimeWindow: TimeInterval = 3.0 // 3秒内需要点击完成
    private let requiredTaps = 5 // 需要连续点击5次
    
    private init() {}
    
    func registerTap() {
        let now = Date()
        
        if now.timeIntervalSince(lastTapTime) <= tapTimeWindow {
            tapCount += 1
        } else {
            tapCount = 1
        }
        
        lastTapTime = now
        
        if tapCount >= requiredTaps {
            activateDevMode()
            tapCount = 0
        }
    }
    
    private func activateDevMode() {
        DispatchQueue.main.async {
            // 切换到正常模式
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                let alert = UIAlertController(title: "开发者选项", message: "请选择应用模式", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "切换到原始功能", style: .default) { _ in
                    AppModeManager.shared.toggleMode()
                })
                
                alert.addAction(UIAlertAction(title: "保持壁纸模式", style: .cancel))
                
                rootVC.present(alert, animated: true)
            }
        }
    }
} 