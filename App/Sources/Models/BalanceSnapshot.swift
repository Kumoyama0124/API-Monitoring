import Foundation

/// 一次查询得到的余额/消费信息
struct BalanceInfo: Codable, Equatable {
    var currency: String
    /// 赠送（代金券类）金额
    var granted: Double?
    /// 已用金额（后付费平台为统计周期内的总消费）
    var used: Double?
    /// 剩余余额
    var remaining: Double?
    /// 每日消费明细（按日期升序），仅 OpenAI / Anthropic 等消费型平台提供
    var dailySpend: [DailyPoint]?

    init(currency: String,
         granted: Double? = nil,
         used: Double? = nil,
         remaining: Double? = nil,
         dailySpend: [DailyPoint]? = nil) {
        self.currency = currency
        self.granted = granted
        self.used = used
        self.remaining = remaining
        self.dailySpend = dailySpend
    }
}

/// 某一天的消费金额
struct DailyPoint: Codable, Equatable {
    /// yyyy-MM-dd（UTC）
    var day: String
    var amount: Double
}

/// 一次刷新的结果快照，成功或失败都会记录
struct BalanceSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var accountID: UUID
    var state: State

    enum State: Codable, Equatable {
        case success(BalanceInfo)
        case failure(String)
    }

    init(date: Date = Date(), accountID: UUID, state: State) {
        self.id = UUID()
        self.date = date
        self.accountID = accountID
        self.state = state
    }

    var balanceInfo: BalanceInfo? {
        if case .success(let info) = state { return info }
        return nil
    }

    var errorMessage: String? {
        if case .failure(let message) = state { return message }
        return nil
    }
}
