import Foundation

/// 各平台余额/消费查询的统一入口。
/// 每个平台的 parseXxx 方法为纯函数，便于单元测试。
enum BalanceService {
    static func fetchBalance(for account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        guard !apiKey.isEmpty else { throw BalanceError.missingAPIKey }
        switch account.kind {
        case .deepseek:
            return try await fetchDeepSeek(account: account, apiKey: apiKey)
        case .moonshot:
            return try await fetchMoonshot(account: account, apiKey: apiKey)
        case .siliconflow:
            return try await fetchSiliconFlow(account: account, apiKey: apiKey)
        case .openrouter:
            return try await fetchOpenRouter(account: account, apiKey: apiKey)
        case .openai:
            return try await fetchOpenAICosts(account: account, apiKey: apiKey)
        case .anthropic:
            return try await fetchAnthropicCosts(account: account, apiKey: apiKey)
        case .generic:
            return try await fetchGeneric(account: account, apiKey: apiKey)
        }
    }

    // MARK: - DeepSeek

    private static func fetchDeepSeek(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let url = try endpointURL(base: account.effectiveBaseURL, path: "/user/balance")
        let data = try await httpGet(url: url, headers: ["Authorization": "Bearer \(apiKey)"])
        return try parseDeepSeek(data)
    }

    static func parseDeepSeek(_ data: Data) throws -> BalanceInfo {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let infos = json["balance_infos"] as? [[String: Any]], let first = infos.first else {
            throw BalanceError.decode("缺少 balance_infos 字段")
        }
        return BalanceInfo(
            currency: JSONUtils.asString(first["currency"]) ?? "CNY",
            granted: JSONUtils.asDouble(first["granted_balance"]),
            used: nil,
            remaining: JSONUtils.asDouble(first["total_balance"])
        )
    }

    // MARK: - Moonshot (Kimi)

    private static func fetchMoonshot(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let url = try endpointURL(base: account.effectiveBaseURL, path: "/v1/users/me/balance")
        let data = try await httpGet(url: url, headers: ["Authorization": "Bearer \(apiKey)"])
        return try parseMoonshot(data)
    }

    static func parseMoonshot(_ data: Data) throws -> BalanceInfo {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let payload = json["data"] as? [String: Any] else {
            throw BalanceError.decode("缺少 data 字段")
        }
        return BalanceInfo(
            currency: "CNY",
            granted: JSONUtils.asDouble(payload["voucher_balance"]),
            used: nil,
            remaining: JSONUtils.asDouble(payload["available_balance"])
        )
    }

    // MARK: - SiliconFlow

    private static func fetchSiliconFlow(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let url = try endpointURL(base: account.effectiveBaseURL, path: "/v1/user/info")
        let data = try await httpGet(url: url, headers: ["Authorization": "Bearer \(apiKey)"])
        return try parseSiliconFlow(data)
    }

    static func parseSiliconFlow(_ data: Data) throws -> BalanceInfo {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let payload = json["data"] as? [String: Any] else {
            throw BalanceError.decode("缺少 data 字段")
        }
        let remaining = JSONUtils.asDouble(payload["totalBalance"]) ?? JSONUtils.asDouble(payload["balance"])
        return BalanceInfo(
            currency: "CNY",
            granted: JSONUtils.asDouble(payload["voucherBalance"]),
            used: nil,
            remaining: remaining
        )
    }

    // MARK: - OpenRouter

    private static func fetchOpenRouter(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let url = try endpointURL(base: account.effectiveBaseURL, path: "/api/v1/credits")
        let data = try await httpGet(url: url, headers: ["Authorization": "Bearer \(apiKey)"])
        return try parseOpenRouter(data)
    }

    static func parseOpenRouter(_ data: Data) throws -> BalanceInfo {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let payload = json["data"] as? [String: Any] else {
            throw BalanceError.decode("缺少 data 字段")
        }
        let credits = JSONUtils.asDouble(payload["total_credits"])
        let usage = JSONUtils.asDouble(payload["total_usage"])
        let remaining = credits.map { $0 - (usage ?? 0) }
        return BalanceInfo(currency: "USD", granted: credits, used: usage, remaining: remaining)
    }

    // MARK: - OpenAI（管理员密钥，查近 30 天消费）

    private static func fetchOpenAICosts(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
            ?? Date().addingTimeInterval(-30 * 86400)
        let startUnix = Int(startDate.timeIntervalSince1970)
        var next: String?
        var daily: [String: Double] = [:]
        var currency = "USD"
        var hasMore = true

        repeat {
            let url = try openAICostsURL(base: account.effectiveBaseURL, startUnix: startUnix, next: next)
            let data = try await httpGet(url: url, headers: ["Authorization": "Bearer \(apiKey)"])
            let page = try parseOpenAICosts(data)
            for (day, value) in page.daily { daily[day, default: 0] += value }
            currency = page.currency
            let json = try JSONUtils.jsonDictionary(from: data)
            hasMore = json["has_more"] as? Bool ?? false
            next = json["next"] as? String
        } while hasMore && next != nil

        guard !daily.isEmpty else { throw BalanceError.decode("未返回消费数据") }
        let points = daily.keys.sorted().map { DailyPoint(day: $0, amount: daily[$0] ?? 0) }
        return BalanceInfo(
            currency: currency,
            used: points.reduce(0) { $0 + $1.amount },
            dailySpend: points
        )
    }

    static func parseOpenAICosts(_ data: Data) throws -> (daily: [String: Double], currency: String) {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let buckets = json["data"] as? [[String: Any]] else {
            throw BalanceError.decode("缺少 data 字段")
        }
        var daily: [String: Double] = [:]
        var currency = "USD"
        for bucket in buckets {
            guard let unix = JSONUtils.asDouble(bucket["start_time"]) else { continue }
            let day = JSONUtils.utcDayString(fromUnixTime: unix)
            guard let results = bucket["results"] as? [[String: Any]] else { continue }
            for result in results {
                guard let amount = result["amount"] as? [String: Any] else { continue }
                if let code = JSONUtils.asString(amount["currency"]) { currency = code }
                if let value = JSONUtils.asDouble(amount["value"]) { daily[day, default: 0] += value }
            }
        }
        return (daily, currency)
    }

    private static func openAICostsURL(base: String, startUnix: Int, next: String?) throws -> URL {
        var components = URLComponents(string: normalizedBase(base) + "/v1/organization/costs")
        guard components != nil else { throw BalanceError.invalidURL(base) }
        var items = [
            URLQueryItem(name: "start_time", value: String(startUnix)),
            URLQueryItem(name: "limit", value: "100")
        ]
        if let next { items.append(URLQueryItem(name: "next", value: next)) }
        components?.queryItems = items
        guard let url = components?.url else { throw BalanceError.invalidURL(base) }
        return url
    }

    // MARK: - Anthropic（管理员密钥，查近 30 天消费）

    private static func fetchAnthropicCosts(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
            ?? Date().addingTimeInterval(-30 * 86400)
        let isoFormatter = ISO8601DateFormatter()
        var page: String?
        var daily: [String: Double] = [:]
        var hasMore = true

        repeat {
            let url = try anthropicCostReportURL(
                base: account.effectiveBaseURL,
                startingAt: isoFormatter.string(from: startDate),
                endingAt: isoFormatter.string(from: Date()),
                page: page
            )
            let data = try await httpGet(
                url: url,
                headers: ["x-api-key": apiKey, "anthropic-version": "2023-06-01"]
            )
            for (day, value) in try parseAnthropicCostReport(data) { daily[day, default: 0] += value }
            let json = try JSONUtils.jsonDictionary(from: data)
            hasMore = json["has_more"] as? Bool ?? false
            page = json["next_page"].flatMap { "\($0)" }
        } while hasMore && page != nil

        guard !daily.isEmpty else { throw BalanceError.decode("未返回消费数据") }
        let points = daily.keys.sorted().map { DailyPoint(day: $0, amount: daily[$0] ?? 0) }
        return BalanceInfo(
            currency: "USD",
            used: points.reduce(0) { $0 + $1.amount },
            dailySpend: points
        )
    }

    static func parseAnthropicCostReport(_ data: Data) throws -> [String: Double] {
        let json = try JSONUtils.jsonDictionary(from: data)
        guard let entries = json["data"] as? [[String: Any]] else {
            throw BalanceError.decode("缺少 data 字段")
        }
        var daily: [String: Double] = [:]
        for entry in entries {
            guard let cost = JSONUtils.asDouble(entry["cost_usd"]) else { continue }
            guard let created = JSONUtils.asString(entry["created_at"]), created.count >= 10 else { continue }
            daily[String(created.prefix(10)), default: 0] += cost
        }
        return daily
    }

    private static func anthropicCostReportURL(base: String, startingAt: String, endingAt: String, page: String?) throws -> URL {
        var components = URLComponents(string: normalizedBase(base) + "/v1/organizations/cost_report")
        guard components != nil else { throw BalanceError.invalidURL(base) }
        var items = [
            URLQueryItem(name: "starting_at", value: startingAt),
            URLQueryItem(name: "ending_at", value: endingAt)
        ]
        if let page { items.append(URLQueryItem(name: "page", value: page)) }
        components?.queryItems = items
        guard let url = components?.url else { throw BalanceError.invalidURL(base) }
        return url
    }

    // MARK: - 自定义平台

    private static func fetchGeneric(account: MonitorAccount, apiKey: String) async throws -> BalanceInfo {
        let url = try genericURL(for: account)
        let headerName = account.genericHeaderName.isEmpty ? "Authorization" : account.genericHeaderName
        let data = try await httpGet(url: url, headers: [headerName: account.genericTokenPrefix + apiKey])
        return try parseGeneric(data, account: account)
    }

    static func parseGeneric(_ data: Data, account: MonitorAccount) throws -> BalanceInfo {
        let json = try JSONUtils.jsonDictionary(from: data)
        let currency: String
        if account.genericCurrencyPath.isEmpty {
            currency = "CNY"
        } else {
            currency = JSONUtils.asString(JSONUtils.resolve(account.genericCurrencyPath, in: json)) ?? "CNY"
        }
        let remaining = JSONUtils.asDouble(JSONUtils.resolve(account.genericRemainingPath, in: json))
        let granted = JSONUtils.asDouble(JSONUtils.resolve(account.genericGrantedPath, in: json))
        let used = JSONUtils.asDouble(JSONUtils.resolve(account.genericUsedPath, in: json))
        if remaining == nil && granted == nil && used == nil {
            throw BalanceError.decode("配置的 JSON 路径均未取到数值")
        }
        return BalanceInfo(currency: currency, granted: granted, used: used, remaining: remaining)
    }

    // MARK: - URL 构造

    static func genericURL(for account: MonitorAccount) throws -> URL {
        let path = account.genericPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            guard let url = URL(string: path) else { throw BalanceError.invalidURL(path) }
            return url
        }
        let full = path.isEmpty
            ? normalizedBase(account.effectiveBaseURL)
            : normalizedBase(account.effectiveBaseURL) + "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: full), url.scheme == "http" || url.scheme == "https" else {
            throw BalanceError.invalidURL(full)
        }
        return url
    }

    static func endpointURL(base: String, path: String) throws -> URL {
        let full = normalizedBase(base) + "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: full), url.scheme == "http" || url.scheme == "https" else {
            throw BalanceError.invalidURL(full)
        }
        return url
    }

    static func normalizedBase(_ base: String) -> String {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }

    // MARK: - HTTP

    private static func httpGet(url: URL, headers: [String: String]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BalanceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BalanceError.network("非 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw BalanceError.http(statusCode: http.statusCode, body: body)
        }
        return data
    }
}
