import Foundation

class ScientificCalculator {
    
    // MARK: - 基本运算
    
    func add(_ a: Double, _ b: Double) -> Double {
        return a + b
    }
    
    func subtract(_ a: Double, _ b: Double) -> Double {
        return a - b
    }
    
    func multiply(_ a: Double, _ b: Double) -> Double {
        return a * b
    }
    
    func divide(_ a: Double, _ b: Double) -> Double? {
        if b == 0 {
            return nil // 除数不能为零
        }
        return a / b
    }
    
    // MARK: - 科学计算
    
    func power(_ base: Double, _ exponent: Double) -> Double {
        return pow(base, exponent)
    }
    
    func squareRoot(_ value: Double) -> Double? {
        if value < 0 {
            return nil // 实数域内无法计算负数的平方根
        }
        return sqrt(value)
    }
    
    func nthRoot(_ value: Double, _ n: Double) -> Double? {
        if value < 0 && Int(n) % 2 == 0 {
            return nil // 偶次方根不能为负数
        }
        return pow(value, 1.0 / n)
    }
    
    // MARK: - 三角函数
    
    enum AngleMode {
        case radians
        case degrees
    }
    
    func sine(_ angle: Double, mode: AngleMode = .radians) -> Double {
        let radians = (mode == .degrees) ? angle * .pi / 180.0 : angle
        return sin(radians)
    }
    
    func cosine(_ angle: Double, mode: AngleMode = .radians) -> Double {
        let radians = (mode == .degrees) ? angle * .pi / 180.0 : angle
        return cos(radians)
    }
    
    func tangent(_ angle: Double, mode: AngleMode = .radians) -> Double? {
        let radians = (mode == .degrees) ? angle * .pi / 180.0 : angle
        
        // 检查是否在切线无穷大的点上（如90度）
        if abs(cos(radians)) < 1e-10 {
            return nil
        }
        
        return tan(radians)
    }
    
    // 反三角函数
    func arcSine(_ value: Double) -> Double? {
        if value < -1.0 || value > 1.0 {
            return nil // 超出定义域
        }
        return asin(value)
    }
    
    func arcCosine(_ value: Double) -> Double? {
        if value < -1.0 || value > 1.0 {
            return nil // 超出定义域
        }
        return acos(value)
    }
    
    func arcTangent(_ value: Double) -> Double {
        return atan(value)
    }
    
    // MARK: - 对数函数
    
    func naturalLogarithm(_ value: Double) -> Double? {
        if value <= 0 {
            return nil // 对数定义域为正数
        }
        return log(value)
    }
    
    func logarithm(_ value: Double, base: Double = 10) -> Double? {
        if value <= 0 || base <= 0 || base == 1 {
            return nil // 对数和底数都必须为正数，且底数不能为1
        }
        
        return log(value) / log(base)
    }
    
    // MARK: - 双曲函数
    
    func hyperbolicSine(_ value: Double) -> Double {
        return sinh(value)
    }
    
    func hyperbolicCosine(_ value: Double) -> Double {
        return cosh(value)
    }
    
    func hyperbolicTangent(_ value: Double) -> Double {
        return tanh(value)
    }
    
    // MARK: - 统计功能
    
    func mean(_ values: [Double]) -> Double? {
        if values.isEmpty {
            return nil
        }
        
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }
    
    func median(_ values: [Double]) -> Double? {
        if values.isEmpty {
            return nil
        }
        
        let sortedValues = values.sorted()
        let count = sortedValues.count
        
        if count % 2 == 0 {
            // 偶数个元素，取中间两个的平均值
            return (sortedValues[count/2 - 1] + sortedValues[count/2]) / 2.0
        } else {
            // 奇数个元素，取中间的元素
            return sortedValues[count/2]
        }
    }
    
    func standardDeviation(_ values: [Double]) -> Double? {
        if values.isEmpty {
            return nil
        }
        
        guard let meanValue = mean(values) else {
            return nil
        }
        
        let squaredDifferences = values.map { pow($0 - meanValue, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count)
        
        return sqrt(variance)
    }
    
    // MARK: - 复数运算
    
    struct Complex {
        var real: Double
        var imaginary: Double
        
        static func +(lhs: Complex, rhs: Complex) -> Complex {
            return Complex(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
        }
        
        static func -(lhs: Complex, rhs: Complex) -> Complex {
            return Complex(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
        }
        
        static func *(lhs: Complex, rhs: Complex) -> Complex {
            return Complex(
                real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
                imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
            )
        }
        
        static func /(lhs: Complex, rhs: Complex) -> Complex? {
            let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
            
            if denominator == 0 {
                return nil // 除数不能为零
            }
            
            return Complex(
                real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
                imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
            )
        }
    }
    
    // MARK: - 单位转换
    
    // 温度转换
    func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9/5 + 32
    }
    
    func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32) * 5/9
    }
    
    func celsiusToKelvin(_ celsius: Double) -> Double {
        return celsius + 273.15
    }
    
    func kelvinToCelsius(_ kelvin: Double) -> Double {
        return kelvin - 273.15
    }
    
    // 长度转换
    func metersToFeet(_ meters: Double) -> Double {
        return meters * 3.28084
    }
    
    func feetToMeters(_ feet: Double) -> Double {
        return feet / 3.28084
    }
    
    func kilometersToMiles(_ kilometers: Double) -> Double {
        return kilometers * 0.621371
    }
    
    func milesToKilometers(_ miles: Double) -> Double {
        return miles / 0.621371
    }
    
    // 重量转换
    func kilogramsToPounds(_ kilograms: Double) -> Double {
        return kilograms * 2.20462
    }
    
    func poundsToKilograms(_ pounds: Double) -> Double {
        return pounds / 2.20462
    }
    
    // 体积转换
    func litersToGallons(_ liters: Double) -> Double {
        return liters * 0.264172
    }
    
    func gallonsToLiters(_ gallons: Double) -> Double {
        return gallons / 0.264172
    }
    
    // MARK: - 矩阵运算
    
    typealias Matrix = [[Double]]
    
    func matrixAddition(_ a: Matrix, _ b: Matrix) -> Matrix? {
        // 检查矩阵维度是否匹配
        guard !a.isEmpty && !b.isEmpty else { return nil }
        guard a.count == b.count && a[0].count == b[0].count else { return nil }
        
        var result = a
        for i in 0..<a.count {
            for j in 0..<a[0].count {
                result[i][j] = a[i][j] + b[i][j]
            }
        }
        return result
    }
    
    func matrixMultiplication(_ a: Matrix, _ b: Matrix) -> Matrix? {
        // 检查矩阵维度是否匹配乘法要求
        guard !a.isEmpty && !b.isEmpty else { return nil }
        guard a[0].count == b.count else { return nil }
        
        let rowsA = a.count
        let colsA = a[0].count
        let colsB = b[0].count
        
        var result = Array(repeating: Array(repeating: 0.0, count: colsB), count: rowsA)
        
        for i in 0..<rowsA {
            for j in 0..<colsB {
                for k in 0..<colsA {
                    result[i][j] += a[i][k] * b[k][j]
                }
            }
        }
        return result
    }
} 