import SwiftUI
import WebKit
import UserNotifications
import AuthenticationServices

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var deviceTokenString: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppDelegate.deviceTokenString = token
    }
}

// MARK: - 메인 앱 뷰
@main
struct BlackMarketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!
    @State private var isLoading: Bool = true

    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Color.black.edgesIgnoringSafeArea(.all)

                    VStack(spacing: 0) {
                        Color.black.frame(height: geometry.safeAreaInsets.top)
                        WebViewContainer(url: currentURL, isLoading: $isLoading)
                    }
                    .edgesIgnoringSafeArea(.all)

                    if isLoading {
                        CustomLoadingOverlay()
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                            .zIndex(2)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { self.isLoading = false }
                }
            }
            .onOpenURL { url in
                if let host = url.host, !host.isEmpty {
                    if let targetURL = URL(string: "https://web.black-market.store/\(host)") {
                        self.currentURL = targetURL
                    }
                }
            }
        }
    }
}

// MARK: - 패스키(Passkey) 완벽 지원 웹뷰
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default() // 패스키 키체인 세션 공유 필수

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator // Passkey Face ID 호출 필수
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.setupProgressObserver(for: webView)

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        private var observation: NSKeyValueObservation?

        init(_ parent: WebViewContainer) { self.parent = parent }

        func setupProgressObserver(for webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                if webView.estimatedProgress >= 0.3 {
                    DispatchQueue.main.async {
                        self?.parent.isLoading = false
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        // [핵심] 패스키 인증 시 새 창 및 보안 팝업 프레임 가로채기
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - 로딩 오버레이
struct CustomLoadingOverlay: View {
    @State private var isPulsing = false
    @State private var rotateDegree: Double = 0

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.8), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2.5
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(rotateDegree))
                        .scaleEffect(isPulsing ? 1.03 : 0.97)

                    VStack(spacing: 1) {
                        Text("BLACK").font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(.white).tracking(2.5)
                        Text("MARKET").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.gray).tracking(1.8)
                    }
                }
                Text("CONNECTING...").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.gray.opacity(0.8)).tracking(2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotateDegree = 360 }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isPulsing = true }
        }
    }
}
