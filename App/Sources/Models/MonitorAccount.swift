import Foundation

/// 一个被监控的 API 平台账户。API Key 不随账户持久化，存放在 Keychain。
struct MonitorAccount: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var kind: ProviderKind
    /// API 基地址，留空时使用该平台默认值
    var baseURL: String
    // MARK: 自定义平台 (generic) 专用字段
    /// 接口路径；若填完整 URL（http/https 开头）则直接使用
    var genericPath: String
    /// 认证请求头名称，默认 Authorization
    var genericHeaderName: String
    /// 认证值前缀，如 "Bearer "，可为空
    var genericTokenPrefix: String
    /// 剩余余额的 JSON 路径，如 data.balance
    var genericRemainingPath: String
    /// 赠送余额的 JSON 路径
    var genericGrantedPath: String
    /// 已用金额的 JSON 路径
    var genericUsedPath: String
    /// 币种的 JSON 路径
    var genericCurrencyPath: String
    var createdAt: Date

    init(kind: ProviderKind, name: String = "", baseURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.kind = kind
        self.baseURL = baseURL ?? kind.defaultBaseURL
        self.genericPath = ""
        self.genericHeaderName = "Authorization"
        self.genericTokenPrefix = "Bearer "
        self.genericRemainingPath = ""
        self.genericGrantedPath = ""
        self.genericUsedPath = ""
        self.genericCurrencyPath = ""
        self.createdAt = Date()
    }

    var effectiveBaseURL: String {
        baseURL.isEmpty ? kind.defaultBaseURL : baseURL
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind
        case baseURL = "base_url"
        case genericPath = "generic_path"
        case genericHeaderName = "generic_header_name"
        case genericTokenPrefix = "generic_token_prefix"
        case genericRemainingPath = "generic_remaining_path"
        case genericGrantedPath = "generic_granted_path"
        case genericUsedPath = "generic_used_path"
        case genericCurrencyPath = "generic_currency_path"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(ProviderKind.self, forKey: .kind)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? kind.defaultBaseURL
        genericPath = try container.decodeIfPresent(String.self, forKey: .genericPath) ?? ""
        genericHeaderName = try container.decodeIfPresent(String.self, forKey: .genericHeaderName) ?? "Authorization"
        genericTokenPrefix = try container.decodeIfPresent(String.self, forKey: .genericTokenPrefix) ?? "Bearer "
        genericRemainingPath = try container.decodeIfPresent(String.self, forKey: .genericRemainingPath) ?? ""
        genericGrantedPath = try container.decodeIfPresent(String.self, forKey: .genericGrantedPath) ?? ""
        genericUsedPath = try container.decodeIfPresent(String.self, forKey: .genericUsedPath) ?? ""
        genericCurrencyPath = try container.decodeIfPresent(String.self, forKey: .genericCurrencyPath) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
