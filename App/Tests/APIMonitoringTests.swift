import XCTest
@testable import APIMonitoring

final class APIMonitoringTests: XCTestCase {

    // MARK: - JSONUtils

    func testJSONPathResolve() throws {
        let json: [String: Any] = [
            "data": [
                "list": [
                    ["balance": "12.5"],
                    ["balance": "3.0"]
                ]
            ]
        ]
        XCTAssertEqual(JSONUtils.resolve("data.list.0.balance", in: json) as? String, "12.5")
        XCTAssertEqual(JSONUtils.resolve("data.list.1.balance", in: json) as? String, "3.0")
        XCTAssertNil(JSONUtils.resolve("data.list.5.balance", in: json))
        XCTAssertNil(JSONUtils.resolve("missing.path", in: json))
        XCTAssertNil(JSONUtils.resolve("", in: json))
    }

    func testAsDouble() {
        XCTAssertEqual(JSONUtils.asDouble("12.34"), 12.34)
        XCTAssertEqual(JSONUtils.asDouble(42), 42.0)
        XCTAssertEqual(JSONUtils.asDouble(3.5), 3.5)
        XCTAssertNil(JSONUtils.asDouble("abc"))
        XCTAssertNil(JSONUtils.asDouble(nil))
    }

    // MARK: - DeepSeek

    func testParseDeepSeek() throws {
        let data = Data(#"""
        {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}
        """#.utf8)
        let info = try BalanceService.parseDeepSeek(data)
        XCTAssertEqual(info.currency, "CNY")
        XCTAssertEqual(info.remaining, 110.0)
        XCTAssertEqual(info.granted, 10.0)
        XCTAssertNil(info.used)
    }

    func testParseDeepSeekMissingField() {
        let data = Data(#"{"foo":1}"#.utf8)
        XCTAssertThrowsError(try BalanceService.parseDeepSeek(data))
    }

    // MARK: - Moonshot

    func testParseMoonshot() throws {
        let data = Data(#"""
        {"code":0,"data":{"available_balance":"9.50","voucher_balance":"0.50","cash_balance":"9.00"},"sensitive_words_checked":true}
        """#.utf8)
        let info = try BalanceService.parseMoonshot(data)
        XCTAssertEqual(info.remaining, 9.5)
        XCTAssertEqual(info.granted, 0.5)
        XCTAssertEqual(info.currency, "CNY")
    }

    // MARK: - SiliconFlow

    func testParseSiliconFlow() throws {
        let data = Data(#"""
        {"code":200,"message":"OK","status":true,"data":{"id":"usr_x","name":"u","balance":"1.00","totalBalance":"8.88","voucherBalance":"2.00","usdBalance":"0.00"}}
        """#.utf8)
        let info = try BalanceService.parseSiliconFlow(data)
        XCTAssertEqual(info.remaining, 8.88)
        XCTAssertEqual(info.granted, 2.0)
    }

    // MARK: - OpenRouter

    func testParseOpenRouter() throws {
        let data = Data(#"{"data":{"total_credits":10.5,"total_usage":3.0}}"#.utf8)
        let info = try BalanceService.parseOpenRouter(data)
        XCTAssertEqual(info.granted, 10.5)
        XCTAssertEqual(info.used, 3.0)
        XCTAssertEqual(info.remaining, 7.5, accuracy: 0.0001)
        XCTAssertEqual(info.currency, "USD")
    }

    // MARK: - OpenAI

    func testParseOpenAICosts() throws {
        let data = Data(#"""
        {"object":"list","data":[{"start_time":1793548800.0,"end_time":1793635199.0,"results":[{"amount":{"value":1.25,"currency":"USD"},"line_item":"gpt-4o"}]}],"has_more":false,"next":null}
        """#.utf8)
        let result = try BalanceService.parseOpenAICosts(data)
        let day = JSONUtils.utcDayString(fromUnixTime: 1_793_548_800)
        XCTAssertEqual(result.daily[day] ?? 0, 1.25, accuracy: 0.0001)
        XCTAssertEqual(result.currency, "USD")
    }

    // MARK: - Anthropic

    func testParseAnthropicCostReport() throws {
        let data = Data(#"""
        {"data":[{"cost_usd":0.50,"created_at":"2026-10-30T12:00:00.000Z"},{"cost_usd":1.50,"created_at":"2026-10-30T18:00:00.000Z"},{"cost_usd":0.25,"created_at":"2026-10-31T00:00:00.000Z"}],"has_more":false,"next_page":null}
        """#.utf8)
        let daily = try BalanceService.parseAnthropicCostReport(data)
        XCTAssertEqual(daily["2026-10-30"] ?? 0, 2.0, accuracy: 0.0001)
        XCTAssertEqual(daily["2026-10-31"] ?? 0, 0.25, accuracy: 0.0001)
    }

    // MARK: - 自定义平台

    func testParseGeneric() throws {
        var account = MonitorAccount(kind: .generic)
        account.genericRemainingPath = "data.balance_infos.0.total_balance"
        account.genericGrantedPath = "data.balance_infos.0.granted_balance"
        account.genericCurrencyPath = "data.balance_infos.0.currency"
        let data = Data(#"""
        {"success":true,"data":{"balance_infos":[{"currency":"USD","total_balance":"88.5","granted_balance":"8.5"}]}}
        """#.utf8)
        let info = try BalanceService.parseGeneric(data, account: account)
        XCTAssertEqual(info.remaining, 88.5)
        XCTAssertEqual(info.granted, 8.5)
        XCTAssertEqual(info.currency, "USD")
    }

    func testParseGenericNoMatchThrows() throws {
        let account = MonitorAccount(kind: .generic)
        let data = Data(#"{"foo":"bar"}"#.utf8)
        XCTAssertThrowsError(try BalanceService.parseGeneric(data, account: account))
    }

    // MARK: - URL 构造

    func testEndpointURL() throws {
        let url = try BalanceService.endpointURL(base: "https://api.deepseek.com/", path: "/user/balance")
        XCTAssertEqual(url.absoluteString, "https://api.deepseek.com/user/balance")

        XCTAssertThrowsError(try BalanceService.endpointURL(base: "not a url", path: "/x"))
    }

    func testGenericURLWithFullPath() throws {
        var account = MonitorAccount(kind: .generic)
        account.genericPath = "https://relay.example.com/api/user/self"
        let url = try BalanceService.genericURL(for: account)
        XCTAssertEqual(url.absoluteString, "https://relay.example.com/api/user/self")

        account.genericPath = "/api/user/self"
        account.baseURL = "https://relay.example.com"
        let url2 = try BalanceService.genericURL(for: account)
        XCTAssertEqual(url2.absoluteString, "https://relay.example.com/api/user/self")
    }

    // MARK: - 模型持久化

    func testAccountCodableRoundtrip() throws {
        var account = MonitorAccount(kind: .generic, name: "中转站")
        account.baseURL = "https://relay.example.com"
        account.genericRemainingPath = "data.balance"

        let data = try JSONEncoder().encode([account])
        let decoded = try JSONDecoder().decode([MonitorAccount].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0], account)
    }

    func testSnapshotStateCodableRoundtrip() throws {
        let snapshot = BalanceSnapshot(accountID: UUID(), state: .success(BalanceInfo(currency: "CNY", granted: 1, used: 2, remaining: 3)))
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BalanceSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)

        let failure = BalanceSnapshot(accountID: UUID(), state: .failure("HTTP 401"))
        let failureData = try JSONEncoder().encode(failure)
        let decodedFailure = try JSONDecoder().decode(BalanceSnapshot.self, from: failureData)
        XCTAssertEqual(decodedFailure.errorMessage, "HTTP 401")
    }
}
