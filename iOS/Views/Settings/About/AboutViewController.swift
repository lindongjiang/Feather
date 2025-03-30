//
//  AboutViewController.swift
//  mantou
//
//  Created by samara on 7/10/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import UIKit
import WebKit

class AboutViewController: UIViewController, WKNavigationDelegate {
	private var webView: WKWebView!
	private var activityIndicator: UIActivityIndicatorView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupNavigation()
		setupWebView()
		setupActivityIndicator()
		loadWebContent()
	}
	
	fileprivate func setupNavigation() {
		self.title = "致谢"
	}
	
	private func setupWebView() {
		// 配置WebView，启用移动端适配
		let configuration = WKWebViewConfiguration()
		configuration.applicationNameForUserAgent = "Mantou/Mobile"
		
		webView = WKWebView(frame: view.bounds, configuration: configuration)
		webView.navigationDelegate = self
		webView.translatesAutoresizingMaskIntoConstraints = false
		webView.allowsBackForwardNavigationGestures = true
		
		// 设置内容模式，确保正确缩放
		webView.scrollView.contentInsetAdjustmentBehavior = .automatic
		
		view.addSubview(webView)
		
		// 设置约束，使WebView填满整个视图
		NSLayoutConstraint.activate([
			webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
	
	private func setupActivityIndicator() {
		activityIndicator = UIActivityIndicatorView(style: .medium)
		activityIndicator.hidesWhenStopped = true
		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(activityIndicator)
		
		// 将活动指示器放置在视图中央
		NSLayoutConstraint.activate([
			activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
	}
	
	private func loadWebContent() {
		guard let url = URL(string: "https://uni.cloudmantoub.online/create.html") else {
			showError(message: "无效的URL")
			return
		}
		
		// 开始加载前显示活动指示器
		activityIndicator.startAnimating()
		
		let request = URLRequest(url: url)
		webView.load(request)
	}
	
	// MARK: - WKNavigationDelegate
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// 页面加载完成，隐藏活动指示器
		activityIndicator.stopAnimating()
		
		// 注入CSS使页面适配移动端
		let cssString = """
			body {
				font-size: 16px !important;
				padding: 12px !important;
				word-wrap: break-word !important;
			}
			img {
				max-width: 100% !important;
				height: auto !important;
			}
			pre, code {
				white-space: pre-wrap !important;
				overflow-x: auto !important;
			}
		"""
		
		let jsString = """
			var style = document.createElement('style');
			style.innerHTML = '\(cssString)';
			document.head.appendChild(style);
			
			// 设置视口
			var meta = document.createElement('meta');
			meta.name = 'viewport';
			meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
			document.head.appendChild(meta);
		"""
		
		webView.evaluateJavaScript(jsString, completionHandler: nil)
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		activityIndicator.stopAnimating()
		showError(message: "加载失败: \(error.localizedDescription)")
	}
	
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		activityIndicator.stopAnimating()
		showError(message: "加载失败: \(error.localizedDescription)")
	}
	
	// 显示错误消息
	private func showError(message: String) {
		let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "确定", style: .default))
		present(alert, animated: true)
	}
}
