import SwiftUI

/// 添加 / 编辑账户的表单。用户只需要选平台、填 API Key，
/// API 地址与请求头等收进"高级选项"（已预填默认值）。
struct AccountFormView: View {
    enum Mode {
        case add
        case edit(MonitorAccount)
    }

    let mode: Mode

    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ProviderKind = .deepseek
    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var genericPath = ""
    @State private var genericHeaderName = "Authorization"
    @State private var genericTokenPrefix = "Bearer "
    @State private var genericRemainingPath = ""
    @State private var genericGrantedPath = ""
    @State private var genericUsedPath = ""
    @State private var genericCurrencyPath = ""
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var isAdd: Bool {
        if case .add = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                if isAdd {
                    kindPicker
                }
                Section("基本信息") {
                    TextField("名称（可选，如 DeepSeek 主号）", text: $name)
                    SecureField(kind.keyPlaceholder, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let hint = kind.adminKeyHint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if kind == .generic {
                    genericSection
                }
                Section {
                    DisclosureGroup("高级选项") {
                        TextField("API 地址", text: $baseURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if kind == .generic {
                            TextField("认证请求头名称", text: $genericHeaderName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("认证值前缀（如 Bearer ）", text: $genericTokenPrefix)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                } footer: {
                    Text("API 地址已预填官方默认值，一般无需修改；使用中转站或镜像站时才需要调整。同一平台可以添加任意多个账号，各自独立统计。")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isAdd ? "添加账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - 平台选择

    private var kindPicker: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(ProviderKind.allCases) { candidate in
                    Button {
                        withAnimation {
                            kind = candidate
                            baseURL = candidate.defaultBaseURL
                        }
                    } label: {
                        VStack(spacing: 6) {
                            PlatformIcon(kind: candidate, size: 40)
                            Text(candidate.shortName)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(
                            kind == candidate ? .regular.tint(.accentColor).interactive() : .regular,
                            in: .rect(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("选择平台")
        } footer: {
            Text("支持为同一平台添加多个账号。")
        }
    }

    private var genericSection: some View {
        Section {
            TextField("接口路径或完整 URL", text: $genericPath)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("剩余余额 JSON 路径", text: $genericRemainingPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("赠送余额 JSON 路径（可选）", text: $genericGrantedPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("已用金额 JSON 路径（可选）", text: $genericUsedPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("币种 JSON 路径（可选）", text: $genericCurrencyPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("接口配置")
        } footer: {
            Text("路径按点分层级取值，数字表示数组下标。例如接口返回 {\"data\":{\"balance_infos\":[{\"total_balance\":\"88.0\"}]}}，剩余路径填 data.balance_infos.0.total_balance。剩余、已用、赠送至少填一项。")
        }
    }

    // MARK: - 数据装载与保存

    private func loadIfEditing() {
        guard !didLoad, case .edit(let account) = mode else { return }
        didLoad = true
        kind = account.kind
        name = account.name
        baseURL = account.baseURL
        apiKey = store.apiKey(for: account)
        genericPath = account.genericPath
        genericHeaderName = account.genericHeaderName
        genericTokenPrefix = account.genericTokenPrefix
        genericRemainingPath = account.genericRemainingPath
        genericGrantedPath = account.genericGrantedPath
        genericUsedPath = account.genericUsedPath
        genericCurrencyPath = account.genericCurrencyPath
    }

    private func save() {
        errorMessage = nil

        if apiKey.isEmpty {
            errorMessage = "请填写 API Key"
            return
        }

        if kind == .generic {
            let hasAnyPath = !genericRemainingPath.isEmpty || !genericGrantedPath.isEmpty || !genericUsedPath.isEmpty
            if !hasAnyPath {
                errorMessage = "自定义平台至少需要填写一个 JSON 路径"
                return
            }
            if genericPath.isEmpty && baseURL.isEmpty {
                errorMessage = "请填写 API 地址或完整的接口 URL"
                return
            }
        }

        var account: MonitorAccount
        switch mode {
        case .add:
            account = MonitorAccount(kind: kind)
        case .edit(let existing):
            account = existing
        }
        account.name = name.isEmpty
            ? (kind == .generic ? "自定义平台" : kind.displayName)
            : name
        account.baseURL = baseURL
        account.genericPath = genericPath
        account.genericHeaderName = genericHeaderName
        account.genericTokenPrefix = genericTokenPrefix
        account.genericRemainingPath = genericRemainingPath
        account.genericGrantedPath = genericGrantedPath
        account.genericUsedPath = genericUsedPath
        account.genericCurrencyPath = genericCurrencyPath

        switch mode {
        case .add:
            store.add(account)
        case .edit:
            store.update(account)
        }
        store.setAPIKey(apiKey, for: account)
        dismiss()

        Task { await store.refresh(account) }
    }
}
