import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showingDeleteAllConfirm = false

    var body: some View {
        Form {
            Section {
                Text("本应用完全在本地运行：账户信息仅保存在本机 UserDefaults，API Key 保存在 iOS 钥匙串（Keychain），不会上传到任何服务器。查询余额时直接从设备请求对应平台接口。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("隐私与存储")
            }

            Section("提示") {
                Text("OpenAI / Anthropic 为后付费平台，显示的是近 30 天消费统计，需要管理员密钥。")
                Text("其余平台显示预付费余额，使用普通 API Key 即可。")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Section {
                Link(destination: URL(string: "https://github.com/Kumoyama0124/API-Monitoring")!) {
                    Label("GitHub 仓库", systemImage: "link")
                }
            } header: {
                Text("关于")
            } footer: {
                Text("API Monitoring v1.1 · SwiftUI · Liquid Glass")
            }

            Section {
                Button("清除所有账户数据", role: .destructive) {
                    showingDeleteAllConfirm = true
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确定清除所有账户？", isPresented: $showingDeleteAllConfirm, titleVisibility: .visible) {
            Button("清除", role: .destructive) {
                store.deleteAll()
            }
        } message: {
            Text("所有账户、历史记录与钥匙串中的 API Key 都将被移除，无法恢复。")
        }
    }
}
