import Foundation

/// 一个被监控的 API 平台账户。
/// API Key 与网页登录 Cookie 都不随账户持久化，存放在 Keychain。
struct MonitorAccount: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var kind: ProviderKind
    /// 认证方式：API Key 或网页登录（Cookie）
    var authMethod: AuthMethod
    /// API 基地址，留空时使用该平台默认值（仅 apiKey 方式）
    var baseURL: String
    // MARK: 网页登录 (webSession) 字段
    /// 登录入口 URL
    var webLoginURL: String
    /// 官网余额接口地址
    var webAPIURL: String
    /// 剩余余额的 JSON 路径
    var webRemainingPath: String
    /// 赠送余额的 JSON 路径
    var webGrantedPath: String
    /// 已用金额的 JSON 路径
    var webUsedPath: String
    /// 币种的 JSON 路径
    var webCurrencyPath: String
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
        self.authMethod = kind.isWebSessionKind ? .webSession : .apiKey
        self.baseURL = baseURL ?? kind.defaultBaseURL
        self.webLoginURL = kind.defaultLoginURL
        self.webAPIURL = ""
        self.webRemainingPath = ""
        self.webGrantedPath = ""
        self.webUsedPath = ""
        self.webCurrencyPath = ""
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

    var effectiveWebLoginURL: String {
        webLoginURL.isEmpty ? kind.defaultLoginURL : webLoginURL
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind
        case authMethod = "auth_method"
        case baseURL = "base_url"
        case webLoginURL = "web_login_url"
        case webAPIURL = "web_api_url"
        case webRemainingPath = "web_remaining_path"
        case webGrantedPath = "web_granted_path"
        case webUsedPath = "web_used_path"
        case webCurrencyPath = "web_currency_path"
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
        authMethod = try container.decodeIfPresent(AuthMethod.self, forKey: .authMethod)
            ?? (kind.isWebSessionKind ? .webSession : .apiKey)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? kind.defaultBaseURL
        webLoginURL = try container.decodeIfPresent(String.self, forKey: .webLoginURL) ?? kind.defaultLoginURL
        webAPIURL = try container.decodeIfPresent(String.self, forKey: .webAPIURL) ?? ""
        webRemainingPath = try container.decodeIfPresent(String.self, forKey: .webRemainingPath) ?? ""
        webGrantedPath = try container.decodeIfPresent(String.self, forKey: .webGrantedPath) ?? ""
        webUsedPath = try container.decodeIfPresent(String.self, forKey: .webUsedPath) ?? ""
        webCurrencyPath = try container.decodeIfPresent(String.self, forKey: .webCurrencyPath) ?? ""
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
