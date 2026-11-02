import Foundation

/// JSON 解析工具：动态结构解析 + 点分路径取值
enum JSONUtils {
    static func jsonDictionary(from data: Data) throws -> [String: Any] {
        guard !data.isEmpty else { throw BalanceError.emptyData }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw BalanceError.decode("顶层不是 JSON 对象")
        }
        return dictionary
    }

    /// 按 "a.b.0.c" 形式的路径在 JSON 结构中取值，数字分量表示数组下标
    static func resolve(_ path: String, in object: Any) -> Any? {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var current: Any = object
        for component in trimmed.split(separator: ".") {
            let key = String(component)
            if let dictionary = current as? [String: Any] {
                guard let next = dictionary[key] else { return nil }
                current = next
            } else if let array = current as? [Any] {
                guard let index = Int(key), array.indices.contains(index) else { return nil }
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }

    /// 兼容数字与字符串两种数值表示，如 "12.30" / 12.3
    static func asDouble(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let string = value as? String { return Double(string) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    static func asString(_ value: Any?) -> String? {
        value as? String
    }

    // MARK: - UTC 日期

    private static let utcDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func utcDayString(fromUnixTime time: Double) -> String {
        utcDayFormatter.string(from: Date(timeIntervalSince1970: time))
    }

    static func utcDate(fromDay day: String) -> Date? {
        utcDayFormatter.date(from: day)
    }
}
