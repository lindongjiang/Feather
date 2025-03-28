//
//  listCollectionViewController.swift
//  mantou
//
//  Created by mantou on 2025/3/28.
//

import UIKit
import SafariServices

class ListCollectionViewController: UIViewController {
    
    // MARK: - 属性
    
    private var collectionView: UICollectionView!
    private var apps: [StoreApp] = []
    private let cellIdentifier = "AppCell"
    private var appStoreData: StoreAppStoreData?
    private var isLoading = false
    private var refreshControl = UIRefreshControl()
    private var announcementView: UIView?
    private var filterView: UIView?
    private var isFilterViewVisible = false
    private var emptyStateView: UIView?
    
    // 接收的参数
    private let sourceURL: String
    private let sourceName: String
    
    // 分类筛选数据
    private let categories = ["全部", "应用", "游戏", "影音", "工具", "插件"]
    private let priceFilters = ["全部", "免费", "收费"]
    private let sortOptions = ["默认", "最新", "最旧"]
    private var selectedCategory = "全部"
    private var selectedPriceFilter = "全部"
    private var selectedSortOption = "默认"
    
    // MARK: - 初始化
    
    init(sourceURL: String, sourceName: String) {
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureNavBar()
        loadData()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 设置CollectionView布局
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // 计算卡片大小
        let screenWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight = itemWidth * 1.4
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        // 创建CollectionView
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(AppCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        
        // 添加下拉刷新
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = .systemBlue
        collectionView.refreshControl = refreshControl
    }
    
    private func configureNavBar() {
        title = sourceName
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 设置导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        
        // 添加右上角筛选按钮
        let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"), style: .plain, target: self, action: #selector(toggleFilterView))
        navigationItem.rightBarButtonItem = filterButton
    }
    
    // 创建顶部公告视图
    private func setupAnnouncementView(withMessage message: String) {
        guard !message.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let messageHeight = message.heightWithConstrainedWidth(width: screenWidth - 32, font: UIFont.systemFont(ofSize: 14))
        let announcementHeight: CGFloat = messageHeight + 32
        
        announcementView?.removeFromSuperview()
        
        announcementView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight))
        announcementView?.backgroundColor = .secondarySystemBackground
        
        // 添加模糊效果
        let blurEffect = UIBlurEffect(style: .systemThickMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight)
        announcementView?.addSubview(blurView)
        
        // 添加公告图标
        let iconImageView = UIImageView(image: UIImage(systemName: "megaphone.fill"))
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.frame = CGRect(x: 16, y: (announcementHeight - 24) / 2, width: 24, height: 24)
        blurView.contentView.addSubview(iconImageView)
        
        // 添加公告文本
        let messageLabel = UILabel(frame: CGRect(x: 50, y: 16, width: screenWidth - 66, height: messageHeight))
        messageLabel.text = message
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .label
        blurView.contentView.addSubview(messageLabel)
        
        // 添加底部分隔线
        let separatorLine = UIView(frame: CGRect(x: 0, y: announcementHeight - 1, width: screenWidth, height: 1))
        separatorLine.backgroundColor = .separator
        blurView.contentView.addSubview(separatorLine)
        
        view.addSubview(announcementView!)
        
        // 调整CollectionView的contentInset以适应顶部公告
        collectionView.contentInset = UIEdgeInsets(top: announcementHeight, left: 0, bottom: 0, right: 0)
    }
    
    // 创建筛选视图
    private func setupFilterView() {
        let screenWidth = UIScreen.main.bounds.width
        let filterHeight: CGFloat = 350 // 增加一点高度以容纳更好的UI
        
        filterView?.removeFromSuperview()
        
        // 创建模糊背景
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backgroundView.alpha = 0
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFilterView))
        backgroundView.addGestureRecognizer(tapGesture)
        
        // 创建筛选面板
        filterView = UIView(frame: CGRect(x: 0, y: view.bounds.height, width: screenWidth, height: filterHeight))
        filterView?.backgroundColor = .systemBackground
        filterView?.layer.cornerRadius = 20
        filterView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        filterView?.layer.masksToBounds = true
        
        // 创建头部指示器 (拖动条)
        let handleView = UIView(frame: CGRect(x: (screenWidth - 40) / 2, y: 8, width: 40, height: 5))
        handleView.backgroundColor = .systemGray4
        handleView.layer.cornerRadius = 2.5
        filterView?.addSubview(handleView)
        
        // 创建标题
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 24, width: screenWidth, height: 30))
        titleLabel.text = "筛选和排序"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        filterView?.addSubview(titleLabel)
        
        // 创建分类筛选
        let categoryLabel = createFilterSectionLabel(text: "分类", y: 70)
        filterView?.addSubview(categoryLabel)
        
        let categoryStackView = createFilterButtonGroup(items: categories, y: 100, selectedItem: selectedCategory, action: #selector(categorySelected(_:)))
        filterView?.addSubview(categoryStackView)
        
        // 创建付费筛选
        let priceLabel = createFilterSectionLabel(text: "付费类型", y: 160)
        filterView?.addSubview(priceLabel)
        
        let priceStackView = createFilterButtonGroup(items: priceFilters, y: 190, selectedItem: selectedPriceFilter, action: #selector(priceFilterSelected(_:)))
        filterView?.addSubview(priceStackView)
        
        // 创建排序筛选
        let sortLabel = createFilterSectionLabel(text: "排序方式", y: 250)
        filterView?.addSubview(sortLabel)
        
        let sortStackView = createFilterButtonGroup(items: sortOptions, y: 280, selectedItem: selectedSortOption, action: #selector(sortOptionSelected(_:)))
        filterView?.addSubview(sortStackView)
        
        // 添加应用按钮
        let applyButton = UIButton(type: .system)
        applyButton.frame = CGRect(x: 20, y: filterHeight - 60, width: screenWidth - 40, height: 50)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitle("应用筛选", for: .normal)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        applyButton.layer.cornerRadius = 12
        applyButton.addTarget(self, action: #selector(dismissFilterView), for: .touchUpInside)
        filterView?.addSubview(applyButton)
        
        view.addSubview(backgroundView)
        view.addSubview(filterView!)
        
        // 动画显示
        UIView.animate(withDuration: 0.3) {
            backgroundView.alpha = 1.0
            self.filterView?.frame.origin.y = self.view.bounds.height - filterHeight
        }
    }
    
    private func createFilterSectionLabel(text: String, y: CGFloat) -> UILabel {
        let label = UILabel(frame: CGRect(x: 20, y: y, width: 200, height: 22))
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }
    
    private func createFilterButtonGroup(items: [String], y: CGFloat, selectedItem: String, action: Selector) -> UIScrollView {
        let screenWidth = UIScreen.main.bounds.width
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: y, width: screenWidth, height: 44))
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillProportionally
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        var totalWidth: CGFloat = 0
        
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(item, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            button.tag = index
            button.addTarget(self, action: action, for: .touchUpInside)
            
            // 设置按钮样式
            button.layer.cornerRadius = 15
            button.layer.masksToBounds = true
            
            // 设置内边距，兼容iOS 15+
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button.configuration = config
            } else {
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            }
            
            if item == selectedItem {
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .secondarySystemBackground
                button.setTitleColor(.label, for: .normal)
            }
            
            stackView.addArrangedSubview(button)
            
            // 计算按钮宽度
            let buttonWidth = item.size(withAttributes: [.font: UIFont.systemFont(ofSize: 15, weight: .medium)]).width + 40
            totalWidth += buttonWidth + 12
        }
        
        scrollView.addSubview(stackView)
        
        // 设置stackView约束
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // 设置scrollView内容大小
        scrollView.contentSize = CGSize(width: totalWidth, height: 44)
        
        return scrollView
    }
    
    @objc private func dismissFilterView() {
        guard let filterView = self.filterView else { return }
        
        // 移除背景
        if let backgroundView = filterView.superview?.subviews.first(where: { $0 !== filterView }) {
            UIView.animate(withDuration: 0.3) {
                backgroundView.alpha = 0
                filterView.frame.origin.y = self.view.bounds.height
            } completion: { _ in
                backgroundView.removeFromSuperview()
                filterView.removeFromSuperview()
                self.isFilterViewVisible = false
            }
        }
    }
    
    @objc private func toggleFilterView() {
        if isFilterViewVisible {
            dismissFilterView()
        } else {
            setupFilterView()
            isFilterViewVisible = true
        }
    }
    
    @objc private func categorySelected(_ sender: UIButton) {
        selectedCategory = categories[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    @objc private func priceFilterSelected(_ sender: UIButton) {
        selectedPriceFilter = priceFilters[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    @objc private func sortOptionSelected(_ sender: UIButton) {
        selectedSortOption = sortOptions[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    private func applyFilters() {
        // 这里应该根据选择的筛选条件过滤数据
        // 简单的模拟实现，实际应用中需要根据实际数据结构进行过滤
        if let originalData = appStoreData?.apps {
            var filteredApps = originalData
            
            // 应用分类筛选
            if selectedCategory != "全部" {
                // 类型筛选逻辑，这里假设type字段表示分类
                // 这里只是示例，实际应用中需要根据实际数据结构进行过滤
                if selectedCategory == "应用" {
                    filteredApps = filteredApps.filter { $0.type == 0 }
                } else if selectedCategory == "游戏" {
                    filteredApps = filteredApps.filter { $0.type == 1 }
                }
                // 其他分类筛选...
            }
            
            // 应用付费筛选
            if selectedPriceFilter != "全部" {
                // 付费筛选逻辑，这里假设lock字段表示付费状态
                if selectedPriceFilter == "免费" {
                    filteredApps = filteredApps.filter { !$0.isLocked }
                } else if selectedPriceFilter == "收费" {
                    filteredApps = filteredApps.filter { $0.isLocked }
                }
            }
            
            // 应用排序
            if selectedSortOption == "最新" {
                filteredApps.sort { app1, app2 in
                    return app1.versionDate > app2.versionDate
                }
            } else if selectedSortOption == "最旧" {
                filteredApps.sort { app1, app2 in
                    return app1.versionDate < app2.versionDate
                }
            }
            
            apps = filteredApps
            collectionView.reloadData()
        }
    }
    
    // 设置空状态视图
    private func setupEmptyStateView() {
        if apps.isEmpty && !isLoading {
            if emptyStateView == nil {
                let emptyView = UIView()
                emptyView.translatesAutoresizingMaskIntoConstraints = false
                
                let stackView = UIStackView()
                stackView.axis = .vertical
                stackView.spacing = 16
                stackView.alignment = .center
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                let imageView = UIImageView(image: UIImage(systemName: "square.grid.2x2"))
                imageView.tintColor = .systemGray3
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
                imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
                
                let titleLabel = UILabel()
                titleLabel.text = "没有找到应用"
                titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                titleLabel.textColor = .label
                
                let descLabel = UILabel()
                descLabel.text = "尝试调整筛选条件，或刷新页面"
                descLabel.font = UIFont.systemFont(ofSize: 16)
                descLabel.textColor = .secondaryLabel
                descLabel.textAlignment = .center
                descLabel.numberOfLines = 0
                
                let refreshButton = UIButton(type: .system)
                refreshButton.setTitle("刷新", for: .normal)
                refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
                refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                refreshButton.backgroundColor = .systemBlue
                refreshButton.setTitleColor(.white, for: .normal)
                refreshButton.tintColor = .white
                refreshButton.layer.cornerRadius = 20
                
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.filled()
                    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                    config.image = UIImage(systemName: "arrow.clockwise")
                    config.imagePlacement = .leading
                    config.imagePadding = 8
                    config.title = "刷新"
                    config.baseBackgroundColor = .systemBlue
                    config.baseForegroundColor = .white
                    refreshButton.configuration = config
                } else {
                    refreshButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
                }
                
                refreshButton.addTarget(self, action: #selector(refreshData), for: .touchUpInside)
                
                stackView.addArrangedSubview(imageView)
                stackView.addArrangedSubview(titleLabel)
                stackView.addArrangedSubview(descLabel)
                stackView.addArrangedSubview(refreshButton)
                
                emptyView.addSubview(stackView)
                
                NSLayoutConstraint.activate([
                    stackView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
                    stackView.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -50),
                    stackView.leadingAnchor.constraint(greaterThanOrEqualTo: emptyView.leadingAnchor, constant: 40),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: emptyView.trailingAnchor, constant: -40)
                ])
                
                collectionView.backgroundView = emptyView
                emptyStateView = emptyView
            }
        } else {
            collectionView.backgroundView = nil
            emptyStateView = nil
        }
    }
    
    // MARK: - 数据操作
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        
        // 获取UDID
        let udid = UserDefaults.standard.string(forKey: "deviceUDID") ?? ""
        
        // 构建请求URL
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        // 添加UDID参数
        if !udid.isEmpty {
            queryItems.append(URLQueryItem(name: "udid", value: udid))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            isLoading = false
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshControl.endRefreshing()
                
                // 恢复筛选按钮
                let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"), style: .plain, target: self, action: #selector(self?.toggleFilterView))
                self?.navigationItem.rightBarButtonItem = filterButton
                
                if let error = error {
                    self?.showError(message: "网络错误: \(error.localizedDescription)")
                    self?.setupEmptyStateView()
                    return
                }
                
                guard let data = data else {
                    self?.showError(message: "没有返回数据")
                    self?.setupEmptyStateView()
                    return
                }
                
                do {
                    // 解析JSON数据
                    let decoder = JSONDecoder()
                    let storeData = try decoder.decode(StoreAppStoreData.self, from: data)
                    
                    self?.appStoreData = storeData
                    self?.apps = storeData.apps
                    
                    // 设置顶部公告
                    if !storeData.message.isEmpty {
                        self?.setupAnnouncementView(withMessage: storeData.message)
                    }
                    
                    self?.collectionView.reloadData()
                    self?.setupEmptyStateView()
                    
                } catch {
                    self?.showError(message: "数据解析错误: \(error.localizedDescription)")
                    self?.setupEmptyStateView()
                }
            }
        }.resume()
    }
    
    @objc private func refreshData() {
        loadData()
    }
    
    // 修改下载逻辑，保存到IPA库
    private func downloadApp(_ app: StoreApp) {
        if app.isLocked {
            // 应用被锁定，显示解锁界面
            showUnlockDialog()
        } else if let downloadURL = URL(string: app.downloadURL) {
            // 显示下载确认对话框
            let alert = UIAlertController(
                title: "下载应用",
                message: "确定要下载\(app.name) (v\(app.version))吗？下载后将自动保存至IPA库。",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
                // 显示下载进度
                let progressAlert = UIAlertController(title: "正在下载", message: "请稍候...", preferredStyle: .alert)
                
                let progressView = UIProgressView(progressViewStyle: .default)
                progressView.frame = CGRect(x: 10, y: 70, width: 250, height: 2)
                progressView.progress = 0.0
                progressAlert.view.addSubview(progressView)
                
                self?.present(progressAlert, animated: true)
                
                // 创建下载任务
                let downloadTask = URLSession.shared.downloadTask(with: downloadURL) { url, response, error in
                    DispatchQueue.main.async {
                        progressAlert.dismiss(animated: true) {
                            if let error = error {
                                self?.showError(message: "下载失败: \(error.localizedDescription)")
                                return
                            }
                            
                            guard let tempURL = url else {
                                self?.showError(message: "下载失败: 无法获取文件")
                                return
                            }
                            
                            do {
                                // 创建IPA库目录
                                let fileManager = FileManager.default
                                let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                                let ipaLibraryURL = documentsURL.appendingPathComponent("IPALibrary", isDirectory: true)
                                
                                if !fileManager.fileExists(atPath: ipaLibraryURL.path) {
                                    try fileManager.createDirectory(at: ipaLibraryURL, withIntermediateDirectories: true)
                                }
                                
                                // 创建文件名（使用应用名称和版本）
                                let filename = "\(app.name)_v\(app.version).ipa"
                                let fileURL = ipaLibraryURL.appendingPathComponent(filename)
                                
                                // 如果文件已存在，先删除
                                if fileManager.fileExists(atPath: fileURL.path) {
                                    try fileManager.removeItem(at: fileURL)
                                }
                                
                                // 将下载的文件移动到IPA库
                                try fileManager.moveItem(at: tempURL, to: fileURL)
                                
                                // 成功保存
                                self?.showMessage(title: "下载成功", message: "\(app.name) 已下载并保存到IPA库")
                                
                                // 通知IPA库更新
                                NotificationCenter.default.post(name: NSNotification.Name("IPALibraryUpdated"), object: nil)
                                
                            } catch {
                                self?.showError(message: "保存失败: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // 观察下载进度
                let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                    DispatchQueue.main.async {
                        progressView.progress = Float(progress.fractionCompleted)
                        progressAlert.message = "下载中...(\(Int(progress.fractionCompleted * 100))%)"
                    }
                }
                
                // 开始下载
                downloadTask.resume()
                
                // 在适当的时候，可以释放观察者
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    observation.invalidate()
                }
            })
            
            present(alert, animated: true)
        } else {
            showError(message: "无效的下载链接")
        }
    }
    
    private func showUnlockDialog() {
        let alertController = UIAlertController(title: "解锁应用", message: "请输入解锁码", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "解锁码"
            textField.autocapitalizationType = .none
            textField.clearButtonMode = .whileEditing
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let unlockAction = UIAlertAction(title: "解锁", style: .default) { [weak self, weak alertController] _ in
            guard let code = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty else {
                return
            }
            
            self?.unlockApp(code: code)
        }
        
        // 添加跳转到购买页面的按钮
        if let payURL = appStoreData?.payURL, !payURL.isEmpty, let url = URL(string: payURL) {
            let buyAction = UIAlertAction(title: "购买解锁码", style: .default) { [weak self] _ in
                let safariVC = SFSafariViewController(url: url)
                self?.present(safariVC, animated: true)
            }
            alertController.addAction(buyAction)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(unlockAction)
        
        present(alertController, animated: true)
    }
    
    private func unlockApp(code: String) {
        // 获取UDID
        guard let udid = UserDefaults.standard.string(forKey: "deviceUDID"), !udid.isEmpty else {
            showError(message: "无法获取设备UDID，请先获取UDID")
            return
        }
        
        // 构建解锁请求URL
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        // 添加UDID和code参数
        queryItems.append(URLQueryItem(name: "udid", value: udid))
        queryItems.append(URLQueryItem(name: "code", value: code))
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            return
        }
        
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: nil, message: "正在验证...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 发起解锁请求
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error {
                        self?.showError(message: "网络错误: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        self?.showError(message: "没有返回数据")
                        return
                    }
                    
                    do {
                        // 解析解锁响应
                        let decoder = JSONDecoder()
                        let unlockResponse = try decoder.decode(StoreUnlockResponse.self, from: data)
                        
                        // 判断解锁结果
                        if unlockResponse.code == 0 {
                            // 解锁成功，刷新数据
                            self?.showMessage(title: "解锁成功", message: unlockResponse.msg) {
                                self?.loadData()
                            }
                        } else {
                            // 解锁失败
                            self?.showError(message: unlockResponse.msg)
                        }
                        
                    } catch {
                        self?.showError(message: "数据解析错误: \(error.localizedDescription)")
                    }
                }
            }
        }.resume()
    }
    
    private func showDetailForApp(_ app: StoreApp) {
        let alertController = UIAlertController(
            title: app.name,
            message: "版本: \(app.version)\n更新日期: \(formatDate(app.versionDate))\n\n\(app.versionDescription)",
            preferredStyle: .alert
        )
        
        // 根据应用锁定状态添加不同的操作按钮
        if app.isLocked {
            alertController.addAction(UIAlertAction(title: "解锁", style: .default) { [weak self] _ in
                self?.showUnlockDialog()
            })
        } else {
            alertController.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
                if let url = URL(string: app.downloadURL) {
                    let safariVC = SFSafariViewController(url: url)
                    self?.present(safariVC, animated: true)
                }
            })
        }
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ dateString: String) -> String {
        // 将日期字符串转换为更友好的格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showMessage(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UICollectionView 数据源与代理

extension ListCollectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? AppCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let app = apps[indexPath.item]
        cell.configure(with: app)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let app = apps[indexPath.item]
        showDetailForApp(app)
    }
}

// MARK: - 自定义集合视图单元格

class AppCollectionViewCell: UICollectionViewCell {
    
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let downloadButton = UIButton(type: .system)
    private let lockIconView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 设置卡片外观
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        // 添加阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        layer.cornerRadius = 16
        
        // 图标
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 16
        iconImageView.layer.masksToBounds = true
        iconImageView.backgroundColor = UIColor.systemGray6
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        // 名称标签
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textAlignment = .left
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // 版本标签
        versionLabel.font = UIFont.systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .left
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)
        
        // 描述标签
        descriptionLabel.font = UIFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        // 下载按钮
        downloadButton.setImage(UIImage(systemName: "icloud.and.arrow.down"), for: .normal)
        downloadButton.tintColor = .systemBlue
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(downloadButton)
        
        // 锁定图标
        lockIconView.image = UIImage(systemName: "lock.fill")
        lockIconView.tintColor = .systemYellow
        lockIconView.contentMode = .scaleAspectFit
        lockIconView.isHidden = true
        lockIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lockIconView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor), // 1:1 宽高比
            
            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            downloadButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            downloadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            downloadButton.widthAnchor.constraint(equalToConstant: 40),
            downloadButton.heightAnchor.constraint(equalToConstant: 40),
            
            lockIconView.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 8),
            lockIconView.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: -8),
            lockIconView.widthAnchor.constraint(equalToConstant: 20),
            lockIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with app: StoreApp) {
        nameLabel.text = app.name
        versionLabel.text = "v\(app.version) · \(app.size)"
        descriptionLabel.text = app.versionDescription.isEmpty ? "暂无描述" : app.versionDescription
        
        // 设置锁定状态
        lockIconView.isHidden = !app.isLocked
        
        // 加载图标（如果有）
        if let iconURLString = app.iconURL, let iconURL = URL(string: iconURLString) {
            URLSession.shared.dataTask(with: iconURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.iconImageView.image = image
                    }
                }
            }.resume()
        } else {
            // 使用默认图标
            iconImageView.image = UIImage(systemName: "square.fill")
            iconImageView.tintColor = .systemBlue
            
            // 尝试使用自定义颜色
            if let tintHex = app.tintColor {
                let color = UIColor(hex: tintHex)
                iconImageView.tintColor = color
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        lockIconView.isHidden = true
    }
}

// MARK: - 辅助扩展

extension String {
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

// 软件源数据模型
struct StoreAppStoreData: Codable {
    let name: String
    let message: String
    let identifier: String
    let sourceURL: String?
    let sourceicon: String?
    let payURL: String
    let unlockURL: String
    let apps: [StoreApp]
}

struct StoreApp: Codable {
    let name: String
    let type: Int
    let version: String
    let versionDate: String
    let versionDescription: String
    let lock: String
    let downloadURL: String
    let isLanZouCloud: String
    let iconURL: String?
    let tintColor: String?
    let size: String
    
    var isLocked: Bool {
        return lock == "1"
    }
}

// 解锁响应模型
struct StoreUnlockResponse: Codable {
    let code: Int
    let msg: String
}

