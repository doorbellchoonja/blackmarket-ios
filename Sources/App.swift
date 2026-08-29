import SwiftUI
import WebKit
import UserNotifications
import AuthenticationServices

// MARK: - AppDelegate: APNs 토큰 수신 및 포그라운드 알림 처리
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var deviceTokenString: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        AppDelegate.deviceTokenString = token
        print("Device Token: \(token)")
        
        sendTokenToServer(token: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - 서버 토큰 전송 함수
func sendTokenToServer(token: String) {
    guard let url = URL(string: "https://web.black-market.store/api/push/register-device-token") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "device_token": token,
        "platform": "ios",
        "bundle_id": "com.worksin.one"
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Token registration error: \(error)")
        } else if let httpResponse = response as? HTTPURLResponse {
            print("Token registered with status: \(httpResponse.statusCode)")
        }
    }.resume()
}

// MARK: - 메인 앱 엔트리포인트
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

                    // 웹뷰 컨테이너 (상단 Safe Area 패딩을 직접 계산하여 밀어줌)
                    VStack(spacing: 0) {
                        Color.black
                            .frame(height: geometry.safeAreaInsets.top)
                        
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
                    withAnimation {
                        self.isLoading = false
                    }
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

// MARK: - 로딩 화면
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
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(rotateDegree))
                        .scaleEffect(isPulsing ? 1.03 : 0.97)

                    VStack(spacing: 1) {
                        Text("BLACK")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2.5)
                        Text("MARKET")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(1.8)
                    }
                }

                Text("CONNECTING...")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.8))
                    .tracking(2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotateDegree = 360
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - 웹뷰 (Safe Area 상단 침범 완벽 방지)
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "pushBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.setupProgressObserver(for: webView)

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        private var observation: NSKeyValueObservation?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func setupProgressObserver(for webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                if webView.estimatedProgress >= 0.3 {
                    DispatchQueue.main.async {
                        self?.parent.isLoading = false
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "pushBridge" {
                if let token = AppDelegate.deviceTokenString {
                    sendTokenToServer(token: token)
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            if let token = AppDelegate.deviceTokenString {
                let js = "window.__DEVICE_TOKEN__ = '\(token)';"
                webView.evaluateJavaScript(js, completionHandler: nil)
                sendTokenToServer(token: token)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
