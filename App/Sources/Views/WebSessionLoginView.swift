import SwiftUI
import WebKit

/// 内嵌浏览器：登录平台官网后，把该站点的 Cookie 保存到钥匙串，
/// 之后应用以网页同款方式（带 Cookie）请求余额接口。
struct WebSessionLoginView: View {
    let kind: ProviderKind
    /// 平台要求的登录入口
    let loginURL: String
    /// 保存成功后回调，参数为 "name=value; name2=value2" 形式的 Cookie 头
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var webViewRef: WKWebView?

    private var loginHost: String {
        URL(string: loginURL)?.host ?? ""
    }

    var body: some View {
        NavigationStack {
            WebViewRepresentable(loginURL: effectiveURL, webViewRef: $webViewRef)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("登录\(kind.shortName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存登录状态") { saveCookies() }
                            .fontWeight(.semibold)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Text("登录完成后点按右上角「保存登录状态」，Cookie 只保存在本机钥匙串。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
        }
    }

    private var effectiveURL: URL {
        URL(string: loginURL) ?? URL(string: "https://www.example.com")!
    }

    private func saveCookies() {
        guard let webView = webViewRef else { return }
        let host = loginHost
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let relevant = cookies.filter { cookie in
                cookie.domain.contains(host)
            }
            let header = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            DispatchQueue.main.async {
                if header.isEmpty {
                    // 该站点没有 Cookie 时也允许保存，但提示用户先登录
                }
                onSaved(header)
                dismiss()
            }
        }
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let loginURL: URL
    @Binding var webViewRef: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: loginURL))
        DispatchQueue.main.async {
            webViewRef = webView
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
