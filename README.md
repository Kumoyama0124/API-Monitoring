# API Monitoring 📊

![iOS Build](https://github.com/Kumoyama0124/API-Monitoring/actions/workflows/build.yml/badge.svg)

一款监控各大 API 平台**余额与使用情况**的 iOS 应用。SwiftUI 编写，采用 iOS 26 Liquid Glass 设计（玻璃卡片 + 卡片式图表），完全本地运行——账户数据只存在本机，API Key 保存在 iOS 钥匙串（Keychain），不上传到任何服务器。

## 功能特性

- **多平台账户管理**：为每个平台添加任意数量的账户（多 Key 场景友好）
- **余额总览**：剩余、已用、赠送金额一目了然，用量进度条提醒
- **消费统计**：OpenAI / Anthropic 显示近 30 天消费总额与每日消费图表
- **自定义平台**：支持任意 OpenAI 兼容中转站，配置 JSON 点分路径即可读取余额
- **安全存储**：API Key 存于 Keychain，卸载应用即随之清除
- **自动刷新**：下拉刷新；超过 5 分钟未更新时打开应用自动刷新

## 支持的平台

| 平台 | 接口 | 所需凭据 | 展示内容 |
| --- | --- | --- | --- |
| DeepSeek | `/user/balance` | 普通 API Key | 预付费余额 |
| Moonshot (Kimi) | `/v1/users/me/balance` | 普通 API Key | 预付费余额 |
| SiliconFlow 硅基流动 | `/v1/user/info` | 普通 API Key | 预付费余额 |
| OpenRouter | `/api/v1/credits` | 普通 API Key | 余额与已用 |
| OpenAI | `/v1/organization/costs` | **管理员密钥** | 近 30 天每日消费 |
| Anthropic | `/v1/organizations/cost_report` | **管理员密钥** | 近 30 天每日消费 |
| 智谱 GLM | 网页登录（Cookie） | 官网账号 | 余额（需配置接口） |
| 通义千问 | 网页登录（Cookie） | 官网账号 | 余额（需配置接口） |
| 小米 | 网页登录（Cookie） | 官网账号 | 余额（需配置接口） |
| xAI (Grok) | 网页登录（Cookie） | 官网账号 | 余额（需配置接口） |
| 自定义平台 | 任意 URL | 任意 | 按配置的 JSON 路径展示 |

> OpenAI / Anthropic 为后付费平台，官方不提供余额接口，需要组织级管理员密钥（Admin Key）查询消费记录。普通项目密钥无权访问这些端点。

### 网页登录方式（智谱 / 千问 / 小米 / xAI）

这些平台的官网**没有公开的余额 API**，应用提供网页登录方式：

1. 添加账户时选择平台，点按「登录」，在内置浏览器里登录官网控制台
2. 点按「保存登录状态」，Cookie 存入本机钥匙串（不上传）
3. 在「网页接口配置」里填写官网余额接口的地址和返回字段 JSON 路径（在浏览器开发者工具的网络面板可以看到；不同账号套餐返回结构可能有差异）
4. 之后应用带着你设备上的 Cookie 直接请求该接口，点开账户即可看到余额；Cookie 过期时重新登录一次即可

### 自定义平台配置示例

接口返回：

```json
{"success":true,"data":{"balance_infos":[{"currency":"USD","total_balance":"88.5"}]}}
```

配置：

- 接口路径：`/api/user/balance`（或直接填完整 URL）
- 剩余余额 JSON 路径：`data.balance_infos.0.total_balance`
- 币种 JSON 路径：`data.balance_infos.0.currency`

## 构建

Xcode 工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，`.xcodeproj` 不入库。

### 本地构建（macOS）

```bash
brew install xcodegen
xcodegen generate
open APIMonitoring.xcodeproj
# 选择 APIMonitoring scheme，Cmd+R 运行
```

### CI 构建

推送到 `main` 后，[GitHub Actions](.github/workflows/build.yml) 会自动在 macOS runner 上生成工程并执行 `xcodebuild test`（包含各平台响应解析的单元测试）。Raw 构建日志会作为 Artifact 上传，便于排查。

## 技术栈

- SwiftUI + Swift Concurrency（async/await、TaskGroup 并发刷新）
- iOS 26+，Liquid Glass 设计，Swift Charts 绘制余额趋势与每日消费图表
- 平台官方图标来源：[Oasisic-Icons](https://github.com/Hawaiine/Oasisic-Icons) → [Orz-3/mini](https://github.com/Orz-3/mini) → icon.horse / 站点官方图标
- 目标代码零依赖：无第三方包，解析基于 Foundation

## 许可

MIT
