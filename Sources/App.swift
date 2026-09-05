import SwiftUI
import WebKit
import UserNotifications
import AuthenticationServices
import CryptoKit

// MARK: - 우편 모델
struct MailItem: Identifiable, Codable {
    let id: Int
    let target_device_id: String
    let title: String
    let content: String
    let date: String
}

struct MailResponse: Codable {
    let mails: [MailItem]
}

// MARK: - 기기 모델명 & 고유 8자리 암호화 관리자
struct DeviceIdManager {
    private static let salt = "BM_DEVICE_SALT_2026"

    static func getEncryptedShortId() -> String {
        let rawUUID = UIDevice.current.identifierForVendor?.uuidString ?? "FALLBACK-DEVICE"
        let salted = rawUUID + salt
        let digest = SHA256.hash(data: Data(salted.utf8))
        let hexString = digest.map { String(format: "%02X", $0) }.joined()
        return String(hexString.prefix(8))
    }

    // 아이폰 모델명 식별 (iPhone 13, iPhone 15 Pro 등)
    static func getDeviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        default: return UIDevice.current.model
        }
    }

    // 서버로 기기 정보 자동 동기화 (최초 1회 실행)
    static func syncDeviceToServer() {
        guard let url = URL(string: "https://web.black-market.store/api/mail/register-device") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "device_id": getEncryptedShortId(),
            "device_name": getDeviceModelName()
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
}

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
        // 기기 등록 동기화 실행
        DeviceIdManager.syncDeviceToServer()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppDelegate.deviceTokenString = token
    }
}

// MARK: - 메인 앱
@main
struct BlackMarketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!
    @State private var isLoading: Bool = true
    @State private var showInfoSheet: Bool = false
    @State private var showMailSheet: Bool = false
    
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

                    LiquidGlassNavigationBar(
                        canGoBack: canGoBack,
                        canGoForward: canGoForward,
                        onBack: { webAction = .goBack },
                        onForward: { webAction = .goForward },
                        onReload: { webAction = .reload },
                        onMail: { showMailSheet = true },
                        onInfo: { showInfoSheet = true }
                    )
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16) + 28)
                    .padding(.horizontal, 20)

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
            .sheet(isPresented: $showMailSheet) {
                MailboxView()
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

// MARK: - 하단 리퀴드 글래스 바
struct LiquidGlassNavigationBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onMail: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 24) {
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
                .frame(width: 1, height: 16)
                .background(Color.white.opacity(0.2))

            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Button(action: onMail) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            ZStack {
                BlurView(style: .systemUltraThinMaterialDark)
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
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 8)
    }
}

// MARK: - 앱 정보 모달 (드래그 회전 방패)
struct AppInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var dragRotationX: Double = 0
    @State private var dragRotationY: Double = 0

    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.2), radius: 15, x: 0, y: 5)
                        
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                    }
                    .rotation3DEffect(.degrees(dragRotationX), axis: (x: 1.0, y: 0.0, z: 0.0))
                    .rotation3DEffect(.degrees(dragRotationY), axis: (x: 0.0, y: 1.0, z: 0.0))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                withAnimation(.interactiveSpring()) {
                                    dragRotationY = Double(value.translation.width) * 0.8
                                    dragRotationX = -Double(value.translation.height) * 0.8
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                    dragRotationX = 0
                                    dragRotationY = 0
                                }
                            }
                    )

                    Text("BLACK MARKET")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)

                    Text("방패를 손가락으로 드래그하여 회전시켜보세요")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.top, 4)

                VStack(spacing: 14) {
                    infoRow(title: "애플리케이션 버전", value: "v\(appVersion)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "빌드 번호", value: "Build #\(buildNumber)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "기기 식별 모델", value: DeviceIdManager.getDeviceModelName())
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: "생체인증 패스키", value: "비활성화됨")
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
            Text(title).font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(value == "비활성화됨" ? Color.red.opacity(0.8) : .white)
        }
    }
}

// MARK: - 우편함 모달
struct MailboxView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var mails: [MailItem] = []
    @State private var isFetching = true
    @State private var copySuccess = false

    var shortDeviceId: String { DeviceIdManager.getEncryptedShortId() }
    var deviceModelName: String { DeviceIdManager.getDeviceModelName() }
    let githubPagesMailURL = "https://web.black-market.store/mail/inbox.json"

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("우편함")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("새로운 공지 및 개별 메시지를 확인합니다.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(deviceModelName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = shortDeviceId
                            copySuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copySuccess = false }
                        }) {
                            Text(copySuccess ? "복사됨!" : "번호 복사")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(copySuccess ? .green : .blue)
                        }
                    }
                    Text(shortDeviceId)
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .padding(.horizontal, 20)

                if isFetching {
                    Spacer()
                    ProgressView().colorScheme(.dark)
                    Spacer()
                } else if mails.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("받은 우편이 없습니다.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(mails) { mail in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(mail.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(mail.date)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Text(mail.content)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(3)
                                }
                                .padding(16)
                                .background(
                                    ZStack {
                                        BlurView(style: .systemThinMaterialDark)
                                        Color.white.opacity(0.03)
                                    }
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

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
        .onAppear { fetchMails() }
    }

    func fetchMails() {
        guard let url = URL(string: "\(githubPagesMailURL)?t=\(Date().timeIntervalSince1970)") else {
            self.isFetching = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.isFetching = false
                guard let data = data,
                      let decoded = try? JSONDecoder().decode(MailResponse.self, from: data) else {
                    return
                }
                let myMails = decoded.mails.filter {
                    $0.target_device_id == "ALL" || $0.target_device_id.uppercased() == self.shortDeviceId
                }
                self.mails = myMails
            }
        }.resume()
    }
}

// MARK: - UIKit 블러 뷰
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = UIBlurEffect(style: style) }
}

// MARK: - 웹뷰
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
                    DispatchQueue.main.async { self?.parent.isLoading = false }
                }
            }
        }

        func setupHistoryObserver(for webView: WKWebView) {
            backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async { self?.parent.canGoBack = webView.canGoBack }
            }
            forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async { self?.parent.canGoForward = webView.canGoForward }
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
