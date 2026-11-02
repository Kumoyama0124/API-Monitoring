import SwiftUI
import Charts

/// 账户详情：玻璃卡片布局——状态卡、余额趋势卡、每日消费卡、历史记录卡、平台信息卡
struct AccountDetailView: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    @State private var accountToEdit: MonitorAccount?
    @State private var showingDeleteConfirm = false

    private var account: MonitorAccount? {
        store.accounts.first { $0.id == accountID }
    }

    private var latest: BalanceSnapshot? {
        store.lastSnapshot(for: accountID)
    }

    private var trendPoints: [TrendPoint] {
        (store.history[accountID] ?? [])
            .compactMap { snapshot -> TrendPoint? in
                guard let remaining = snapshot.balanceInfo?.remaining else { return nil }
                return TrendPoint(date: snapshot.date, amount: remaining)
            }
            .sorted { $0.date < $1.date }
    }

    private var spendPoints: [SpendPoint] {
        guard let daily = latest?.balanceInfo?.dailySpend else { return [] }
        return daily.compactMap { point in
            guard let date = JSONUtils.utcDate(fromDay: point.day) else { return nil }
            return SpendPoint(date: date, amount: point.amount)
        }
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    private struct SpendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    var body: some View {
        Group {
            if let account {
                cards(account)
            } else {
                ContentUnavailableView("账户已删除", systemImage: "questionmark.circle")
            }
        }
        .task {
            if let account, latest == nil {
                await store.refresh(account)
            }
        }
        .sheet(item: $accountToEdit) { target in
            AccountFormView(mode: .edit(target))
        }
        .confirmationDialog("确定删除该账户？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(accountID)
                dismiss()
            }
        } message: {
            Text("API Key 也将从钥匙串中移除。")
        }
    }

    @ViewBuilder
    private func cards(_ account: MonitorAccount) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard(account)
                if trendPoints.count >= 2 {
                    trendCard
                }
                if !spendPoints.isEmpty {
                    spendCard
                }
                recordsCard
                infoCard(account)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await store.refresh(account)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await store.refresh(account) }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    Button {
                        accountToEdit = account
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    if store.refreshingIDs.contains(accountID) {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - 状态卡

    @ViewBuilder
    private func summaryCard(_ account: MonitorAccount) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PlatformIcon(kind: account.kind, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.refreshingIDs.contains(accountID) {
                    ProgressView()
                }
            }

            Divider()

            if let snapshot = latest {
                switch snapshot.state {
                case .success(let info):
                    if let remaining = info.remaining {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AmountFormatter.string(remaining, currency: info.currency))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("剩余余额")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let used = info.used {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AmountFormatter.string(used, currency: info.currency))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("近 30 天消费")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    row("赠送金额", info.granted.map { AmountFormatter.string($0, currency: info.currency) })
                    row("已用金额", info.used.map { AmountFormatter.string($0, currency: info.currency) })
                    HStack {
                        Text("更新时间")
                        Spacer()
                        Text(snapshot.date, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                case .failure(let message):
                    Label("获取失败", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("尚未获取数据，下拉或点按菜单刷新")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 余额趋势卡

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("余额趋势", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.semibold))
            Chart(trendPoints) { point in
                AreaMark(
                    x: .value("时间", point.date),
                    y: .value("余额", point.amount)
                )
                .foregroundStyle(.linearGradient(
                    colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("时间", point.date),
                    y: .value("余额", point.amount)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
                .symbol(Circle())
            }
            .frame(height: 150)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 每日消费卡

    private var spendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("每日消费（近 30 天）", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
            Chart(spendPoints) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("金额", point.amount)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7))
            }
            .frame(height: 150)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 历史记录卡

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("历史记录", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
            let snapshots = store.history[accountID] ?? []
            if snapshots.isEmpty {
                Text("暂无记录")
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshots.prefix(20)) { snapshot in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(snapshot.date, format: .dateTime.year().month().day().hour().minute())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshotSummary(snapshot))
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    if let message = snapshot.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 3)
                if snapshot.id != snapshots.prefix(20).last?.id {
                    Divider()
                }
            }
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 平台信息卡

    private func infoCard(_ account: MonitorAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("平台信息", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            row("平台", account.kind.displayName)
            row("API 地址", account.effectiveBaseURL)
            row("多账号", "同平台可添加任意数量的账号")
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 辅助

    private func snapshotSummary(_ snapshot: BalanceSnapshot) -> String {
        switch snapshot.state {
        case .success(let info):
            if let remaining = info.remaining {
                return "剩余 " + AmountFormatter.string(remaining, currency: info.currency)
            }
            if let used = info.used {
                return "消费 " + AmountFormatter.string(used, currency: info.currency)
            }
            return "成功"
        case .failure:
            return "失败"
        }
    }

    private func row(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer()
            if let value {
                Text(value)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}
