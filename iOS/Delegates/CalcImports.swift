// 这个文件用于确保所有伪装模式相关的类都被编译进模块
// 无需实际代码，只需导入相关文件即可

import Foundation

// 只是声明类型，让编译器知道这些类的存在
#if false
fileprivate let _ = CalculatorViewController()
fileprivate let _ = ModeController.shared
fileprivate let _ = AppMode.calculator
fileprivate let _ = ServerController.shared
#endif 