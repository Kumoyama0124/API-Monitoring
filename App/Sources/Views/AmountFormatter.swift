import Foundation

/// 金额格式化：优先按币种代码输出，无法识别时降级为纯数字
enum AmountFormatter {
    static func string(_ value: Double, currency: String) -> String {
        let code = currency.trimmingCharacters(in: .whitespaces).uppercased()
        if code.count == 3 {
            return value.formatted(.currency(code: code))
        }
        if code.isEmpty {
            return String(format: "%.2f", value)
        }
        return String(format: "%.2f %@", value, code)
    }
}
