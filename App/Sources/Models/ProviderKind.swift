import Foundation

/// 账户认证方式
enum AuthMethod: String, Codable {
    /// 普通 API Key（Bearer 等请求头）
    case apiKey
    /// 网页登录：Cookie 存本机钥匙串，用官网同款接口查询
    case webSession
}

/// 支持监控的 API 平台类型
enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case moonshot
    case siliconflow
    case openrouter
    case openai
    case anthropic
    case zhipu
    case qwen
    case xiaomi
    case xai
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
        case .zhipu: return "智谱 GLM"
        case .qwen: return "通义千问"
        case .xiaomi: return "小米"
        case .xai: return "xAI (Grok)"
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
        case .zhipu: return "智谱"
        case .qwen: return "千问"
        case .xiaomi: return "小米"
        case .xai: return "xAI"
        case .generic: return "自定义"
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
        case .zhipu: return "🔮"
        case .qwen: return "🪁"
        case .xiaomi: return "📱"
        case .xai: return "🌐"
        case .generic: return "🛠"
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
        case .zhipu: return "brand.zhipu"
        case .qwen: return "brand.qwen"
        case .xiaomi: return "brand.xiaomi"
        case .xai: return "brand.xai"
        case .generic: return nil
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
        case .zhipu, .qwen, .xiaomi, .xai: return ""
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

    /// 该平台是否只支持网页登录方式（官网无公开余额 API）
    var isWebSessionKind: Bool {
        switch self {
        case .zhipu, .qwen, .xiaomi, .xai: return true
        default: return false
        }
    }

    /// 网页登录入口（官网控制台）
    var defaultLoginURL: String {
        switch self {
        case .zhipu: return "https://open.bigmodel.cn/"
        case .qwen: return "https://bailian.aliyun.com/"
        case .xiaomi: return "https://platform.xiaomimimo.com/"
        case .xai: return "https://console.x.ai/"
        default: return ""
        }
    }

    /// 该平台网页端余额查询的配置提示
    var webSessionHint: String {
        switch self {
        case .zhipu:
            return "登录 open.bigmodel.cn 后，在浏览器网络面板找到返回余额/资源包的接口地址，填入下方配置即可。"
        case .qwen:
            return "百炼控制台的用量接口可能需要额外签名，若 Cookie 方式取不到数据，建议改用「自定义平台」方式接入。"
        case .xiaomi:
            return "登录小米大模型平台后，从网络面板找到余额接口地址填入下方配置。"
        case .xai:
            return "登录 console.x.ai 后，从网络面板找到团队额度接口地址填入下方配置。"
        default:
            return ""
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
        case .zhipu, .qwen, .xiaomi, .xai: return "无需 API Key，请使用网页登录"
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
