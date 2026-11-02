import Foundation

/// 查询失败时的错误信息，提供中文描述
enum BalanceError: LocalizedError {
    case invalidURL(String)
    case missingAPIKey
    case http(statusCode: Int, body: String)
    case network(String)
    case decode(String)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的 URL：\(url)"
        case .missingAPIKey:
            return "未配置 API Key"
        case .http(let statusCode, let body):
            let trimmed = String(body.prefix(200))
            return trimmed.isEmpty ? "HTTP 错误 \(statusCode)" : "HTTP \(statusCode)：\(trimmed)"
        case .network(let message):
            return "网络错误：\(message)"
        case .decode(let message):
            return "解析失败：\(message)"
        case .emptyData:
            return "响应内容为空"
        }
    }
}
