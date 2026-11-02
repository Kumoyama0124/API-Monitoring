import SwiftUI
import Charts

/// 账户详情：当前余额/消费、每日消费图表、历史记录
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

    private var chartPoints: [ChartPoint] {
        guard let daily = latest?.balanceInfo?.dailySpend else { return [] }
        return daily.compactMap { point in
            guard let date = JSONUtils.utcDate(fromDay: point.day) else { return nil }
            return ChartPoint(date: date, amount: point.amount)
        }
    }

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    var body: some View {
        Group {
            if let account {
                content(account)
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
    private func content(_ account: MonitorAccount) -> some View {
        List {
            summarySection(account)
            if !chartPoints.isEmpty {
                chartSection
            }
            historySection
        }
        .listStyle(.insetGrouped)
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

    // MARK: - 概要

    @ViewBuilder
    private func summarySection(_ account: MonitorAccount) -> some View {
        Section("当前状态") {
            if let snapshot = latest {
                switch snapshot.state {
                case .success(let info):
                    row("币种", info.currency.uppercased())
                    row("剩余余额", info.remaining.map { AmountFormatter.string($0, currency: info.currency) })
                    row("赠送金额", info.granted.map { AmountFormatter.string($0, currency: info.currency) })
                    if info.remaining != nil {
                        row("已用金额", info.used.map { AmountFormatter.string($0, currency: info.currency) })
                    } else if let used = info.used {
                        row("近 30 天消费", AmountFormatter.string(used, currency: info.currency))
                    }
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
            LabeledContent("平台", value: account.kind.displayName)
            LabeledContent("API 地址", value: account.effectiveBaseURL)
                .lineLimit(2)
        }
    }

    // MARK: - 每日消费图表

    private var chartSection: some View {
        Section("每日消费（近 30 天）") {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("金额", point.amount)
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7))
            }
            .frame(height: 180)
        }
    }

    // MARK: - 历史记录

    private var historySection: some View {
        Section("历史记录") {
            let snapshots = store.history[accountID] ?? []
            if snapshots.isEmpty {
                Text("暂无记录")
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshots) { snapshot in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(snapshot.date, format: .dateTime.year().month().day().hour().minute())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshotSummary(snapshot))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    if let message = snapshot.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 2)
            }
        }
    }

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
        HStack {
            Text(label)
            Spacer()
            if let value {
                Text(value)
                    .monospacedDigit()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}
