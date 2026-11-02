import SwiftUI

/// 添加 / 编辑账户的表单。
/// API Key 平台：选平台 + 填 Key 即可；网页登录平台：选平台 → 登录官网 → 配置余额接口。
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
    // 网页登录
    @State private var webLoginURL = ""
    @State private var webAPIURL = ""
    @State private var webRemainingPath = ""
    @State private var webGrantedPath = ""
    @State private var webUsedPath = ""
    @State private var webCurrencyPath = ""
    @State private var pendingCookieHeader: String?
    @State private var showingWebLogin = false

    @State private var errorMessage: String?
    @State private var didLoad = false

    private var isAdd: Bool {
        if case .add = mode { return true }
        return false
    }

    private var isWebSessionKind: Bool {
        kind.isWebSessionKind
    }

    /// 当前是否有可用 Cookie（编辑模式读钥匙串，本次登录的优先）
    private var hasCookie: Bool {
        if let pendingCookieHeader, !pendingCookieHeader.isEmpty { return true }
        if case .edit(let account) = mode {
            return !store.webCookieHeader(for: account).isEmpty
        }
        return false
    }

    private var effectiveLoginURL: String {
        webLoginURL.isEmpty ? kind.defaultLoginURL : webLoginURL
    }

    var body: some View {
        NavigationStack {
            Form {
                if isAdd {
                    kindPicker
                }
                Section("基本信息") {
                    TextField("名称（可选，如 DeepSeek 主号）", text: $name)
                    if isWebSessionKind {
                        webLoginSection
                    } else {
                        SecureField(kind.keyPlaceholder, text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let hint = kind.adminKeyHint {
                            Text(hint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if isWebSessionKind {
                    webConfigSection
                }
                if kind == .generic {
                    genericSection
                }
                Section {
                    DisclosureGroup("高级选项") {
                        if isWebSessionKind {
                            TextField("登录入口 URL", text: $webLoginURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            TextField("API 地址", text: $baseURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
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
                    Text(footerText)
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
            .sheet(isPresented: $showingWebLogin) {
                WebSessionLoginView(kind: kind, loginURL: effectiveLoginURL) { header in
                    pendingCookieHeader = header
                }
            }
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
                            webLoginURL = candidate.defaultLoginURL
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

    // MARK: - 网页登录

    @ViewBuilder
    private var webLoginSection: some View {
        HStack {
            Label(
                hasCookie ? "已保存登录状态" : "尚未登录",
                systemImage: hasCookie ? "checkmark.seal.fill" : "person.badge.key"
            )
            .foregroundStyle(hasCookie ? Color.green : Color.orange)
            Spacer()
            Button(hasCookie ? "重新登录" : "登录") {
                showingWebLogin = true
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
        if kind.webSessionHint.isEmpty == false {
            Text(kind.webSessionHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var webConfigSection: some View {
        Section {
            TextField("余额接口地址（完整 URL）", text: $webAPIURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("剩余余额 JSON 路径", text: $webRemainingPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("赠送余额 JSON 路径（可选）", text: $webGrantedPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("已用金额 JSON 路径（可选）", text: $webUsedPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("币种 JSON 路径（可选）", text: $webCurrencyPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("网页接口配置")
        } footer: {
            Text("登录官网后，浏览器里能看到的余额接口，把它地址和返回字段填到这里，应用会用你保存的 Cookie 直接请求。")
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

    private var footerText: String {
        if isWebSessionKind {
            return "登录入口一般是官网首页，登录后跳转到控制台也没关系，保存时自动提取对应域名的 Cookie。Cookie 保存在本机钥匙串，不会上传。"
        }
        return "API 地址已预填官方默认值，一般无需修改；使用中转站或镜像站时才需要调整。同一平台可以添加任意多个账号，各自独立统计。"
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
        webLoginURL = account.webLoginURL
        webAPIURL = account.webAPIURL
        webRemainingPath = account.webRemainingPath
        webGrantedPath = account.webGrantedPath
        webUsedPath = account.webUsedPath
        webCurrencyPath = account.webCurrencyPath
    }

    private func save() {
        errorMessage = nil

        if isWebSessionKind {
            guard hasCookie else {
                errorMessage = "请先完成网页登录并保存登录状态"
                return
            }
            if webAPIURL.isEmpty {
                errorMessage = "请填写余额接口地址（官网控制台的余额接口）"
                return
            }
            if webRemainingPath.isEmpty && webGrantedPath.isEmpty && webUsedPath.isEmpty {
                errorMessage = "至少填写一个 JSON 路径"
                return
            }
        } else {
            if apiKey.isEmpty {
                errorMessage = "请填写 API Key"
                return
            }
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
        account.authMethod = isWebSessionKind ? .webSession : .apiKey
        account.webLoginURL = webLoginURL
        account.webAPIURL = webAPIURL
        account.webRemainingPath = webRemainingPath
        account.webGrantedPath = webGrantedPath
        account.webUsedPath = webUsedPath
        account.webCurrencyPath = webCurrencyPath

        switch mode {
        case .add:
            store.add(account)
        case .edit:
            store.update(account)
        }
        if isWebSessionKind {
            if let pendingCookieHeader {
                store.setWebCookieHeader(pendingCookieHeader, for: account)
            }
        } else {
            store.setAPIKey(apiKey, for: account)
        }
        dismiss()

        Task { await store.refresh(account) }
    }
}
