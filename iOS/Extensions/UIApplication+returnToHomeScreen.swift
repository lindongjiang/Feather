//
//  UIApplication+returnToHomeScreen.swift
//  mantou
//
//  Created by Lakhan Lothiyi on 22/08/2024.
//

import Foundation
import UIKit

extension UIApplication {
  /// 返回主屏幕的功能
  /// 注意：由于App Store限制，此功能有局限性
  func returnToHomeScreen() {
    // 方法1: 尝试使用URL Scheme跳转
    if let url = URL(string: "shortcuts://") {
      UIApplication.shared.open(url, options: [:], completionHandler: { _ in
        // 快速返回
        if let url = URL(string: "about:blank") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
      })
    } else {
      // 方法2: 尝试最小化应用
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
      }
    }
    
    // 显示提示信息
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = scene.windows.first?.rootViewController {
      let alert = UIAlertController(
        title: "返回主屏幕",
        message: "由于系统限制，应用无法直接返回主屏幕。请使用设备的Home手势或Home键返回。",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "知道了", style: .default))
      rootVC.present(alert, animated: true)
    }
  }
}

// 获取当前最顶层视图控制器的辅助函数
extension UIApplication {
  class func topViewController(controller: UIViewController? = UIApplication.shared.connectedScenes
                            .filter({$0.activationState == .foregroundActive})
                            .compactMap({$0 as? UIWindowScene})
                            .first?.windows
                            .filter({$0.isKeyWindow}).first?.rootViewController) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(controller: navigationController.visibleViewController)
    }
    if let tabController = controller as? UITabBarController {
      if let selected = tabController.selectedViewController {
        return topViewController(controller: selected)
      }
    }
    if let presented = controller?.presentedViewController {
      return topViewController(controller: presented)
    }
    return controller
  }
}
