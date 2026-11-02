import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showingAdd = false
    @State private var accountToEdit: MonitorAccount?

    var body: some View {
        NavigationStack {
            Group {
                if store.accounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle("API 监控")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AccountFormView(mode: .add)
            }
            .sheet(item: $accountToEdit) { account in
                AccountFormView(mode: .edit(account))
            }
            .refreshable { await store.refreshAll() }
            .task { await store.refreshIfStale() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有账户", systemImage: "gauge.with.needle")
        } description: {
            Text("添加 API 平台账户，随时查看余额与使用情况")
        } actions: {
            Button("添加账户") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var accountList: some View {
        List {
            ForEach(store.accounts) { account in
                NavigationLink {
                    AccountDetailView(accountID: account.id)
                } label: {
                    AccountCard(account: account)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.delete(account.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        accountToEdit = account
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button {
                        Task { await store.refresh(account) }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .contextMenu {
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
                        store.delete(account.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// 账户卡片：图标 + 名称 + 剩余/消费概览
struct AccountCard: View {
    @EnvironmentObject private var store: AccountStore
    let account: MonitorAccount

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                Text(account.kind.emoji)
                    .font(.title2)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                    .lineLimit(1)
                subtitle
                usageProgress
            }

            Spacer()

            if store.refreshingIDs.contains(account.id) {
                ProgressView()
            } else {
                statusView
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var subtitle: Text {
        let base = Text(account.kind.displayName)
        if let snapshot = store.lastSnapshot(for: account.id) {
            return base + Text(" · ") + Text(snapshot.date, style: .relative)
        }
        return base + Text(" · 尚未刷新")
    }

    @ViewBuilder
    private var statusView: some View {
        switch store.lastSnapshot(for: account.id)?.state {
        case .some(.success(let info)):
            VStack(alignment: .trailing, spacing: 2) {
                if let remaining = info.remaining {
                    Text(AmountFormatter.string(remaining, currency: info.currency))
                        .font(.title3).bold()
                        .monospacedDigit()
                    Text("剩余")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if let used = info.used {
                    Text(AmountFormatter.string(used, currency: info.currency))
                        .font(.title3).bold()
                        .monospacedDigit()
                    Text("近 30 天消费")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("—").font(.title3)
                }
            }
        case .some(.failure):
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("获取失败")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .none:
            Text("未刷新")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var usageProgress: some View {
        if let info = store.lastSnapshot(for: account.id)?.balanceInfo,
           let granted = info.granted, granted > 0,
           let remaining = info.remaining, remaining >= 0 {
            let fraction = min(max((granted - remaining) / granted, 0), 1)
            ProgressView(value: fraction)
                .tint(fraction > 0.8 ? Color.orange : Color.accentColor)
                .frame(width: 120)
        }
    }
}
