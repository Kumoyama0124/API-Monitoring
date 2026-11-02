import Foundation

/// 支持监控的 API 平台类型
enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case moonshot
    case siliconflow
    case openrouter
    case openai
    case anthropic
    case generic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .moonshot: return "Moonshot (Kimi)"
        case .siliconflow: return "SiliconFlow 硅基流动"
        case .openrouter: return "OpenRouter"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .generic: return "自定义平台"
        }
    }

    /// 选择平台网格里用的短名
    var shortName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .moonshot: return "Kimi"
        case .siliconflow: return "硅基流动"
        case .openrouter: return "OpenRouter"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .generic: return "自定义"
        }
    }

    /// 资源目录中的官方品牌图标；自定义平台无图标，回退到 emoji
    var brandIconName: String? {
        switch self {
        case .deepseek: return "brand.deepseek"
        case .moonshot: return "brand.moonshot"
        case .siliconflow: return "brand.siliconflow"
        case .openrouter: return "brand.openrouter"
        case .openai: return "brand.openai"
        case .anthropic: return "brand.anthropic"
        case .generic: return nil
        }
    }

    var emoji: String {
        switch self {
        case .deepseek: return "🐋"
        case .moonshot: return "🌙"
        case .siliconflow: return "⚡️"
        case .openrouter: return "🧭"
        case .openai: return "🤖"
        case .anthropic: return "📜"
        case .generic: return "🛠"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .moonshot: return "https://api.moonshot.cn"
        case .siliconflow: return "https://api.siliconflow.cn"
        case .openrouter: return "https://openrouter.ai"
        case .openai: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        case .generic: return ""
        }
    }

    /// true = 查询预付费余额；false = 后付费平台，查询周期内消费
    var isBalanceStyle: Bool {
        switch self {
        case .openai, .anthropic: return false
        default: return true
        }
    }

    /// 是否需要组织级管理员密钥（普通 API Key 无法查询消费/余额）
    var requiresAdminKey: Bool {
        switch self {
        case .openai, .anthropic: return true
        default: return false
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-admin-...（管理员密钥）"
        case .anthropic: return "sk-ant-admin-...（管理员密钥）"
        case .generic: return "API Key / Token"
        default: return "sk-..."
        }
    }

    var adminKeyHint: String? {
        switch self {
        case .openai:
            return "OpenAI 需要 Admin Key（在 platform.openai.com 的管理员设置中创建），普通项目密钥无权访问组织消费接口。"
        case .anthropic:
            return "Anthropic 需要 Admin API Key（sk-ant-admin-...），在 Claude Console 的设置中创建。"
        default:
            return nil
        }
    }
}
