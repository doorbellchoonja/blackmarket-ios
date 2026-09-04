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

// MARK: - 메인 앱 엔트리포인트
@main
struct BlackMarketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!
    @State private var isLoading: Bool = true
    @State private var showInfoSheet: Bool = false
    
    // 웹뷰 네비게이션 제어 상태
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webAction: WebAction = .none

    enum WebAction {
        case none
        case goBack
        case goForward
        case reload
    }

    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Color.black.edgesIgnoringSafeArea(.all)

                    // 웹뷰 레이아웃 (상단 노치 패딩 보정)
                    VStack(spacing: 0) {
                        Color.black.frame(height: geometry.safeAreaInsets.top)
                        WebViewContainer(
                            url: currentURL,
                            isLoading: $isLoading,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            webAction: $webAction
                        )
                    }
                    .edgesIgnoringSafeArea(.all)

                    // 플로팅 리퀴드 글래스 하단 컨트롤 바
                    LiquidGlassNavigationBar(
                        canGoBack: canGoBack,
                        canGoForward: canGoForward,
                        onBack: { webAction = .goBack },
                        onForward: { webAction = .goForward },
                        onReload: { webAction = .reload },
                        onInfo: { showInfoSheet = true }
                    )
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                    .padding(.horizontal, 24)

                    // 로딩 오버레이
                    if isLoading {
                        CustomLoadingOverlay()
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                            .zIndex(2)
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                AppInfoView()
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

// MARK: - 리퀴드 글래스(Liquid Glassmorphism) 컨트롤 바
struct LiquidGlassNavigationBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canGoBack ? .white : .white.opacity(0.25))
            }
            .disabled(!canGoBack)

            Button(action: onForward) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canGoForward ? .white : .white.opacity(0.25))
            }
            .disabled(!canGoForward)

            Divider()
                .frame(width: 1, height: 18)
                .background(Color.white.opacity(0.2))

            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        // 리퀴드 글래스 효과 레이어링
        .background(
            ZStack {
                // 울트라 씬 반투명 블러 백드롭
                BlurView(style: .systemUltraThinMaterialDark)
                
                // 표면 반사광 그라디언트
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.04),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(Capsule())
        // 미세 유리 테두리 (Rim Light)
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        // 굴절 그림자
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }
}

// UIKit 초미세 블러 뷰
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - 앱 정보 모달 화면 (리퀴드 다크 테마)
struct AppInfoView: View {
    @Environment(\.presentationMode) var presentationMode

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                // 닫기 핸들
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // 브랜드 심볼
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }

                    Text("BLACK MARKET")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                }
                .padding(.top, 8)

                // 정보 글래스 카드
                VStack(spacing: 14) {
                    infoRow(title: "애플리케이션 버전", value: "v\(appVersion)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "빌드 번호", value: "Build #\(buildNumber)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "연결 도메인", value: "web.black-market.store")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "생체인증 패스키", value: "활성화됨")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "보안 샌드박스", value: "TLS 1.3 암호화")
                }
                .padding(18)
                .background(
                    ZStack {
                        BlurView(style: .systemThinMaterialDark)
                        Color.white.opacity(0.03)
                    }
                )
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )
                .padding(.horizontal, 20)

                Spacer()

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("닫기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 웹뷰 (네비게이션 액션 및 다운로드 처리)
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webAction: BlackMarketApp.WebAction

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.setupProgressObserver(for: webView)
        context.coordinator.setupHistoryObserver(for: webView)

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 하단 탭바 버튼 액션 수신 처리
        switch webAction {
        case .goBack:
            if uiView.canGoBack { uiView.goBack() }
            DispatchQueue.main.async { self.webAction = .none }
        case .goForward:
            if uiView.canGoForward { uiView.goForward() }
            DispatchQueue.main.async { self.webAction = .none }
        case .reload:
            uiView.reload()
            DispatchQueue.main.async { self.webAction = .none }
        case .none:
            break
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        var parent: WebViewContainer
        private var progressObservation: NSKeyValueObservation?
        private var backObservation: NSKeyValueObservation?
        private var forwardObservation: NSKeyValueObservation?
        private var downloadedFileURLs: [ObjectIdentifier: URL] = [:]

        init(_ parent: WebViewContainer) { self.parent = parent }

        func setupProgressObserver(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                if webView.estimatedProgress >= 0.3 {
                    DispatchQueue.main.async {
                        self?.parent.isLoading = false
                    }
                }
            }
        }

        func setupHistoryObserver(for webView: WKWebView) {
            backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = webView.canGoBack
                }
            }
            forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = webView.canGoForward
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let reqURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = reqURL.scheme?.lowercased() ?? ""
            if scheme != "http" && scheme != "https" && scheme != "about" {
                if UIApplication.shared.canOpenURL(reqURL) {
                    UIApplication.shared.open(reqURL, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }

            let fileExtensions = ["zip", "ipa", "pdf", "apk", "rar", "7z", "txt", "png", "jpg", "jpeg"]
            if fileExtensions.contains(reqURL.pathExtension.lowercased()) {
                if #available(iOS 14.5, *) {
                    decisionHandler(.download)
                    return
                }
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let response = navigationResponse.response as? HTTPURLResponse {
                let disposition = response.allHeaderFields["Content-Disposition"] as? String ?? ""
                if disposition.contains("attachment") {
                    if #available(iOS 14.5, *) {
                        decisionHandler(.download)
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }

        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        @available(iOS 14.5, *)
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent(suggestedFilename)
            try? FileManager.default.removeItem(at: destinationURL)
            
            let downloadId = ObjectIdentifier(download)
            self.downloadedFileURLs[downloadId] = destinationURL
            completionHandler(destinationURL)
        }

        @available(iOS 14.5, *)
        func downloadDidFinish(_ download: WKDownload) {
            let downloadId = ObjectIdentifier(download)
            guard let fileURL = self.downloadedFileURLs[downloadId] else { return }
            self.downloadedFileURLs.removeValue(forKey: downloadId)

            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    activityVC.popoverPresentationController?.sourceView = rootVC.view
                    rootVC.present(activityVC, animated: true)
                }
            }
        }

        @available(iOS 14.5, *)
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            let downloadId = ObjectIdentifier(download)
            self.downloadedFileURLs.removeValue(forKey: downloadId)
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
