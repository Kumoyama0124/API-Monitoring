import Foundation
import Combine

/// 账户与快照的本地存储（UserDefaults + Keychain），以及刷新调度。
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [MonitorAccount] = []
    /// 每个账户的快照历史，新记录在前，最多保留 maxHistoryPerAccount 条
    @Published private(set) var history: [UUID: [BalanceSnapshot]] = [:]
    @Published private(set) var refreshingIDs: Set<UUID> = []

    private let defaults: UserDefaults
    private let accountsKey = "apimonitor.accounts"
    private let historyKey = "apimonitor.history"
    private let maxHistoryPerAccount = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([MonitorAccount].self, from: data) {
            accounts = decoded
        }
        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([UUID: [BalanceSnapshot]].self, from: data) {
            history = decoded
        }
    }

    // MARK: - 账户管理

    func add(_ account: MonitorAccount) {
        accounts.append(account)
        persist()
    }

    func update(_ account: MonitorAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            persist()
        }
    }

    func delete(_ id: UUID) {
        accounts.removeAll { $0.id == id }
        history.removeValue(forKey: id)
        KeychainStore.delete(key: id.uuidString)
        persist()
    }

    func deleteAll() {
        for account in accounts { KeychainStore.delete(key: account.id.uuidString) }
        accounts = []
        history = [:]
        persist()
    }

    // MARK: - API Key

    func apiKey(for account: MonitorAccount) -> String {
        KeychainStore.get(key: account.id.uuidString) ?? ""
    }

    func setAPIKey(_ key: String, for account: MonitorAccount) {
        KeychainStore.set(key: account.id.uuidString, value: key)
    }

    // MARK: - 快照

    func lastSnapshot(for id: UUID) -> BalanceSnapshot? {
        history[id]?.first
    }

    // MARK: - 刷新

    func refresh(_ account: MonitorAccount) async {
        guard !refreshingIDs.contains(account.id) else { return }
        refreshingIDs.insert(account.id)
        defer { refreshingIDs.remove(account.id) }

        let key = apiKey(for: account)
        let snapshot: BalanceSnapshot
        do {
            let info = try await BalanceService.fetchBalance(for: account, apiKey: key)
            snapshot = BalanceSnapshot(accountID: account.id, state: .success(info))
        } catch {
            snapshot = BalanceSnapshot(accountID: account.id, state: .failure(error.localizedDescription))
        }
        var list = history[account.id] ?? []
        list.insert(snapshot, at: 0)
        if list.count > maxHistoryPerAccount {
            list = Array(list.prefix(maxHistoryPerAccount))
        }
        history[account.id] = list
        persist()
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                group.addTask { await self.refresh(account) }
            }
        }
    }

    /// 距上次成功刷新超过 maxAge 时自动全量刷新
    func refreshIfStale(maxAge: TimeInterval = 300) async {
        guard !accounts.isEmpty else { return }
        let newest = history.values.compactMap { $0.first?.date }.max()
        if let newest, Date().timeIntervalSince(newest) < maxAge { return }
        await refreshAll()
    }

    // MARK: - 持久化

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: accountsKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }
}
