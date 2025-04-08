import UIKit

class CalculatorView: UIView {
    
    // MARK: - 属性
    
    private var displayLabel: UILabel!
    private var secondaryDisplayLabel: UILabel!  // 新增：二级显示，用于显示计算过程
    private var buttonsStackView: UIStackView!
    private var historyLabel: UILabel!
    private var modeSegmentedControl: UISegmentedControl!  // 新增：模式切换
    
    private var currentInput: String = "0"
    private var firstOperand: Double?
    private var operation: String?
    private var shouldResetInput: Bool = true
    private var lastCalculation: String = ""
    private var isInScientificMode: Bool = false  // 是否处于科学计算模式
    private var memoryValue: Double = 0  // 内存值
    private var angleMode: AngleMode = .degrees  // 角度模式，默认为角度制
    
    // 角度模式枚举
    enum AngleMode {
        case degrees
        case radians
    }
    
    // 用于检测特殊序列的变量
    private var secretSequence: String = ""
    
    // 科学计算器额外按钮
    private var scientificButtonsView: UIStackView!
    
    // MARK: - 初始化
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI 设置
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // 先创建所有UI组件，然后再配置布局
        createUIComponents()
        
        // 现在设置布局约束
        setupConstraints()
        
        // 最后设置按钮
        setupButtons()
        setupScientificButtons()
    }
    
    private func createUIComponents() {
        // 设置模式切换控件
        modeSegmentedControl = UISegmentedControl(items: ["标准", "科学"])
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.selectedSegmentIndex = 0
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        addSubview(modeSegmentedControl)
        
        // 历史标签
        historyLabel = UILabel()
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        historyLabel.textAlignment = .right
        historyLabel.textColor = .secondaryLabel
        historyLabel.font = UIFont.systemFont(ofSize: 16)
        historyLabel.adjustsFontSizeToFitWidth = true
        historyLabel.minimumScaleFactor = 0.7
        addSubview(historyLabel)
        
        // 二级显示标签
        secondaryDisplayLabel = UILabel()
        secondaryDisplayLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryDisplayLabel.text = ""
        secondaryDisplayLabel.textAlignment = .right
        secondaryDisplayLabel.textColor = .secondaryLabel
        secondaryDisplayLabel.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        secondaryDisplayLabel.adjustsFontSizeToFitWidth = true
        secondaryDisplayLabel.minimumScaleFactor = 0.6
        addSubview(secondaryDisplayLabel)
        
        // 显示标签
        displayLabel = UILabel()
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.text = "0"
        displayLabel.textAlignment = .right
        displayLabel.font = UIFont.systemFont(ofSize: 50, weight: .light)
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.5
        addSubview(displayLabel)
        
        // 按钮容器
        buttonsStackView = UIStackView()
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .vertical
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 10
        addSubview(buttonsStackView)
        
        // 科学计算器按钮视图
        scientificButtonsView = UIStackView()
        scientificButtonsView.translatesAutoresizingMaskIntoConstraints = false
        scientificButtonsView.axis = .vertical
        scientificButtonsView.distribution = .fillEqually
        scientificButtonsView.spacing = 10
        scientificButtonsView.isHidden = true // 默认隐藏
        addSubview(scientificButtonsView)
    }
    
    private func setupConstraints() {
        // 布局约束
        NSLayoutConstraint.activate([
            modeSegmentedControl.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            modeSegmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            modeSegmentedControl.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            
            historyLabel.topAnchor.constraint(equalTo: modeSegmentedControl.bottomAnchor, constant: 16),
            historyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            historyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            secondaryDisplayLabel.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 4),
            secondaryDisplayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            secondaryDisplayLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            displayLabel.topAnchor.constraint(equalTo: secondaryDisplayLabel.bottomAnchor, constant: 8),
            displayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            displayLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            scientificButtonsView.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 20),
            scientificButtonsView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scientificButtonsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scientificButtonsView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.15),
            
            buttonsStackView.topAnchor.constraint(equalTo: scientificButtonsView.bottomAnchor, constant: 10),
            buttonsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            buttonsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            buttonsStackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        isInScientificMode = sender.selectedSegmentIndex == 1
        scientificButtonsView.isHidden = !isInScientificMode
        
        // 可以在这里调整布局以适应不同模式
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    private func setupButtons() {
        // 定义按钮布局
        let buttonLabels: [[String]] = [
            ["C", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["0", ".", "="]
        ]
        
        // 创建按钮行
        for row in buttonLabels {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 10
            
            for buttonText in row {
                let button = createButton(withTitle: buttonText)
                
                // 特殊按钮样式
                if "+-×÷=".contains(buttonText) {
                    button.backgroundColor = .systemOrange
                    button.setTitleColor(.white, for: .normal)
                } else if "C±%".contains(buttonText) {
                    button.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
                    button.setTitleColor(.black, for: .normal)
                } else {
                    button.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
                    button.setTitleColor(.black, for: .normal)
                }
                
                // 0按钮宽度加倍
                if buttonText == "0" {
                    button.layer.cornerRadius = 25
                    rowStackView.addArrangedSubview(button)
                    button.widthAnchor.constraint(equalTo: rowStackView.widthAnchor, multiplier: 0.5, constant: -5).isActive = true
                } else {
                    button.layer.cornerRadius = 25
                    rowStackView.addArrangedSubview(button)
                }
            }
            
            buttonsStackView.addArrangedSubview(rowStackView)
        }
    }
    
    private func setupScientificButtons() {
        // 定义科学计算器按钮
        let scientificRows: [[String]] = [
            ["sin", "cos", "tan", "π"],
            ["ln", "log", "√", "x²"],
            ["MC", "MR", "M+", "M-"]
        ]
        
        for row in scientificRows {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 10
            
            for buttonText in row {
                let button = createButton(withTitle: buttonText)
                button.backgroundColor = UIColor.systemGray5
                button.setTitleColor(.black, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
                button.layer.cornerRadius = 20
                rowStackView.addArrangedSubview(button)
            }
            
            scientificButtonsView.addArrangedSubview(rowStackView)
        }
    }
    
    private func createButton(withTitle title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        button.clipsToBounds = true
        
        // 添加阴影和边框效果
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 1
        
        // 添加触摸效果
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.9
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    // MARK: - 按钮操作
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let buttonText = sender.titleLabel?.text else { return }
        
        // 记录按钮序列用于秘密触发
        secretSequence += buttonText
        if secretSequence.count > 20 {
            secretSequence = String(secretSequence.suffix(20))
        }
        
        // 检查是否触发了特殊序列
        if ModeController.shared.checkSpecialSequence(secretSequence) {
            // 如果触发，ModeController会自动处理模式切换
            secretSequence = ""
            return
        }
        
        // 根据按钮内容处理
        switch buttonText {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            inputDigit(buttonText)
        case ".":
            inputDecimal()
        case "+", "-", "×", "÷":
            setOperation(buttonText)
        case "=":
            calculateResult()
        case "C":
            clearAll()
        case "±":
            toggleSign()
        case "%":
            calculatePercentage()
        case "sin":
            calculateTrigFunction(.sin)
        case "cos":
            calculateTrigFunction(.cos)
        case "tan":
            calculateTrigFunction(.tan)
        case "π":
            inputPi()
        case "√":
            calculateSquareRoot()
        case "x²":
            calculateSquare()
        case "ln":
            calculateLogarithm(isNatural: true)
        case "log":
            calculateLogarithm(isNatural: false)
        case "MC":
            memoryClear()
        case "MR":
            memoryRecall()
        case "M+":
            memoryAdd()
        case "M-":
            memorySubtract()
        default:
            break
        }
        
        // 更新显示
        updateDisplay()
    }
    
    // MARK: - 计算器逻辑
    
    private func inputDigit(_ digit: String) {
        if shouldResetInput {
            currentInput = digit
            shouldResetInput = false
        } else {
            // 避免前导零
            if currentInput == "0" {
                currentInput = digit
            } else {
                currentInput += digit
            }
        }
        
        // 更新二级显示
        updateSecondaryDisplay()
    }
    
    private func inputDecimal() {
        if shouldResetInput {
            currentInput = "0."
            shouldResetInput = false
        } else if !currentInput.contains(".") {
            currentInput += "."
        }
    }
    
    private func setOperation(_ op: String) {
        if let value = Double(currentInput) {
            if firstOperand == nil {
                firstOperand = value
            } else if operation != nil {
                calculateResult()
                firstOperand = Double(currentInput)
            }
        }
        
        operation = op
        shouldResetInput = true
        lastCalculation = "\(formatNumber(firstOperand ?? 0)) \(op)"
        
        // 更新二级显示
        updateSecondaryDisplay()
    }
    
    private func calculateResult() {
        guard let firstOperand = firstOperand, let operation = operation, !shouldResetInput else {
            return
        }
        
        let secondOperand = Double(currentInput) ?? 0
        var result: Double = 0
        
        switch operation {
        case "+":
            result = firstOperand + secondOperand
        case "-":
            result = firstOperand - secondOperand
        case "×":
            result = firstOperand * secondOperand
        case "÷":
            if secondOperand != 0 {
                result = firstOperand / secondOperand
            } else {
                // 除以零处理
                clearAll()
                currentInput = "错误"
                return
            }
        default:
            break
        }
        
        // 更新历史计算
        lastCalculation = "\(formatNumber(firstOperand)) \(operation) \(formatNumber(secondOperand)) ="
        
        // 更新结果
        currentInput = formatNumber(result)
        self.firstOperand = result
        self.operation = nil
        shouldResetInput = true
        
        // 清空二级显示
        secondaryDisplayLabel.text = ""
    }
    
    private func toggleSign() {
        if let value = Double(currentInput) {
            currentInput = formatNumber(-value)
            updateSecondaryDisplay()
        }
    }
    
    private func calculatePercentage() {
        if let value = Double(currentInput) {
            if let firstOperand = firstOperand, operation != nil {
                // 在操作中的百分比，如5+10%意味着5+0.5
                currentInput = formatNumber(firstOperand * value / 100.0)
            } else {
                // 直接百分比
                currentInput = formatNumber(value / 100.0)
            }
            updateSecondaryDisplay()
        }
    }
    
    private func clearAll() {
        currentInput = "0"
        firstOperand = nil
        operation = nil
        shouldResetInput = true
        lastCalculation = ""
        secondaryDisplayLabel.text = ""
    }
    
    // MARK: - 科学计算功能
    
    enum TrigFunction {
        case sin, cos, tan
    }
    
    private func calculateTrigFunction(_ function: TrigFunction) {
        guard let value = Double(currentInput) else { return }
        
        // 转换为弧度（如果用户选择角度模式）
        let valueInRadians = angleMode == .degrees ? value * .pi / 180.0 : value
        
        var result: Double
        
        switch function {
        case .sin:
            result = sin(valueInRadians)
            lastCalculation = "sin(\(formatNumber(value))) ="
        case .cos:
            result = cos(valueInRadians)
            lastCalculation = "cos(\(formatNumber(value))) ="
        case .tan:
            if abs(cos(valueInRadians)) < 1e-10 {
                currentInput = "错误"
                return
            }
            result = tan(valueInRadians)
            lastCalculation = "tan(\(formatNumber(value))) ="
        }
        
        currentInput = formatNumber(result)
        shouldResetInput = true
    }
    
    private func inputPi() {
        currentInput = formatNumber(Double.pi)
        shouldResetInput = true
        lastCalculation = "π ="
    }
    
    private func calculateSquareRoot() {
        if let value = Double(currentInput), value >= 0 {
            currentInput = formatNumber(sqrt(value))
            lastCalculation = "√(\(formatNumber(value))) ="
            shouldResetInput = true
        } else {
            currentInput = "错误"
        }
    }
    
    private func calculateSquare() {
        if let value = Double(currentInput) {
            currentInput = formatNumber(pow(value, 2))
            lastCalculation = "(\(formatNumber(value)))² ="
            shouldResetInput = true
        }
    }
    
    private func calculateLogarithm(isNatural: Bool) {
        if let value = Double(currentInput), value > 0 {
            if isNatural {
                currentInput = formatNumber(log(value))
                lastCalculation = "ln(\(formatNumber(value))) ="
            } else {
                currentInput = formatNumber(log10(value))
                lastCalculation = "log(\(formatNumber(value))) ="
            }
            shouldResetInput = true
        } else {
            currentInput = "错误"
        }
    }
    
    // MARK: - 内存操作
    
    private func memoryClear() {
        memoryValue = 0
        updateSecondaryDisplay()
    }
    
    private func memoryRecall() {
        currentInput = formatNumber(memoryValue)
        shouldResetInput = true
        updateSecondaryDisplay()
    }
    
    private func memoryAdd() {
        if let value = Double(currentInput) {
            memoryValue += value
            shouldResetInput = true
            updateSecondaryDisplay()
        }
    }
    
    private func memorySubtract() {
        if let value = Double(currentInput) {
            memoryValue -= value
            shouldResetInput = true
            updateSecondaryDisplay()
        }
    }
    
    // MARK: - 辅助方法
    
    private func updateDisplay() {
        displayLabel.text = currentInput
        historyLabel.text = lastCalculation
    }
    
    private func updateSecondaryDisplay() {
        if let firstOp = firstOperand, let op = operation {
            secondaryDisplayLabel.text = "\(formatNumber(firstOp)) \(op) \(currentInput)"
        } else if memoryValue != 0 {
            secondaryDisplayLabel.text = "M: \(formatNumber(memoryValue))"
        } else {
            secondaryDisplayLabel.text = ""
        }
    }
    
    private func formatNumber(_ number: Double) -> String {
        // 如果是整数，显示为整数格式
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        } else {
            // 格式化浮点数并添加千分位分隔符
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 1
            formatter.usesGroupingSeparator = true
            
            // 移除末尾多余的零
            let formattedString = formatter.string(from: NSNumber(value: number)) ?? "\(number)"
            return formattedString.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
    }
}