import SwiftUI
import WebKit
import UserNotifications
import AuthenticationServices
import CryptoKit
import QuickLook

// MARK: - 지원 언어 및 자체 다국어 매니저 (파일 추가 없이 코드 내 완결)
enum AppLanguage: String, CaseIterable, Identifiable {
    case ko = "ko"
    case en = "en"
    case ja = "ja"
    case zh = "zh"
    case ru = "ru"
    case fr = "fr"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .ko: return "한국어 (Korean)"
        case .en: return "English"
        case .ja: return "日本語 (Japanese)"
        case .zh: return "中文 (Chinese)"
        case .ru: return "Русский (Russian)"
        case .fr: return "Français (French)"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("bm_selected_language") var currentLanguageRaw: String = "ko"

    var currentLanguage: AppLanguage {
        get { AppLanguage(rawValue: currentLanguageRaw) ?? .ko }
        set {
            currentLanguageRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    private let dictionary: [String: [AppLanguage: String]] = [
        // 메인/공통
        "connecting": [
            .ko: "연결 중...", .en: "CONNECTING...", .ja: "接続中...", .zh: "连接中...", .ru: "ПОДКЛЮЧЕНИЕ...", .fr: "CONNEXION..."
        ],
        "close": [
            .ko: "닫기", .en: "Close", .ja: "閉じる", .zh: "关闭", .ru: "Закрыть", .fr: "Fermer"
        ],
        "settings": [
            .ko: "설정", .en: "Settings", .ja: "設定", .zh: "设置", .ru: "Настройки", .fr: "Paramètres"
        ],
        "language_setting": [
            .ko: "언어 설정", .en: "Language", .ja: "言語設定", .zh: "语言设置", .ru: "Язык", .fr: "Langue"
        ],
        "language_sub": [
            .ko: "앱 내 모든 인터페이스 언어를 변경합니다.",
            .en: "Change all application interface languages.",
            .ja: "アプリ内のすべての言語を変更します。",
            .zh: "更改应用内的所有界面语言。",
            .ru: "Изменить язык интерфейса приложения.",
            .fr: "Modifier la langue de l'interface de l'application."
        ],
        // 우편함
        "mailbox": [
            .ko: "우편함", .en: "Mailbox", .ja: "受信箱", .zh: "收件箱", .ru: "Почтовый ящик", .fr: "Boîte de réception"
        ],
        "mailbox_sub": [
            .ko: "새로운 공지 및 개별 메시지를 확인합니다.",
            .en: "Check notices and private messages.",
            .ja: "新しいお知らせや個別メッセージを確認します。",
            .zh: "查看新公告和个人私信。",
            .ru: "Просматривайте уведомления и личные сообщения.",
            .fr: "Consultez les annonces et les messages privés."
        ],
        "copy_number": [
            .ko: "번호 복사", .en: "Copy ID", .ja: "番号コピー", .zh: "复制编号", .ru: "Копировать ID", .fr: "Copier ID"
        ],
        "copied": [
            .ko: "복사됨!", .en: "Copied!", .ja: "コピー完了!", .zh: "已复制!", .ru: "Скопировано!", .fr: "Copié !"
        ],
        "empty_mailbox": [
            .ko: "받은 우편이 없습니다.", .en: "No mails available.", .ja: "受信した郵便はありません。", .zh: "暂无收到的邮件。", .ru: "Писем нет.", .fr: "Aucun courrier reçu."
        ],
        "download_and_preview": [
            .ko: "동영상 다운로드 및 미리보기", .en: "Download & Preview Video", .ja: "動画をダウンロードしてプレビュー", .zh: "下载并预览视频", .ru: "Скачать и посмотреть видео", .fr: "Télécharger et prévisualiser la vidéo"
        ],
        "open_preview": [
            .ko: "미리보기 열기", .en: "Open Preview", .ja: "プレビューを開く", .zh: "打开预览", .ru: "Открыть просмотр", .fr: "Ouvrir l'aperçu"
        ],
        "downloaded_tag": [
            .ko: "다운로드 완료됨", .en: "Downloaded", .ja: "ダウンロード完了", .zh: "已下载", .ru: "Скачано", .fr: "Téléchargé"
        ],
        "downloading": [
            .ko: "다운로드 중...", .en: "Downloading...", .ja: "ダウンロード中...", .zh: "下载中...", .ru: "Загрузка...", .fr: "Téléchargement..."
        ],
        // 앱 정보
        "drag_shield_hint": [
            .ko: "방패를 손가락으로 드래그하여 회전시켜보세요",
            .en: "Drag the shield with your finger to rotate it",
            .ja: "指でシールドをドラッグして回転させてみてください",
            .zh: "用手指拖动盾牌进行旋转",
            .ru: "Проведите пальцем по щиту, чтобы повернуть его",
            .fr: "Faites glisser le bouclier avec votre doigt pour le faire pivoter"
        ],
        "app_version": [
            .ko: "애플리케이션 버전", .en: "Application Version", .ja: "アプリバージョン", .zh: "应用程序版本", .ru: "Версия приложения", .fr: "Version de l'application"
        ],
        "build_number": [
            .ko: "빌드 번호", .en: "Build Number", .ja: "ビルド番号", .zh: "内部版本号", .ru: "Номер сборки", .fr: "Numéro de build"
        ],
        "device_model": [
            .ko: "기기 식별 모델", .en: "Device Model", .ja: "端末識別モデル", .zh: "设备识别型号", .ru: "Модель устройства", .fr: "Modèle de l'appareil"
        ],
        "passkey_auth": [
            .ko: "생체인증 패스키", .en: "Passkey Biometrics", .ja: "生体認証パスキー", .zh: "生物识别通行密钥", .ru: "Биометрический ключ", .fr: "Clé d'accès biométrique"
        ],
        "passkey_disabled": [
            .ko: "비활성화됨", .en: "Disabled", .ja: "無効", .zh: "已停用", .ru: "Отключено", .fr: "Désactivé"
        ],
        "security_sandbox": [
            .ko: "보안 샌드박스", .en: "Security Sandbox", .ja: "セキュリティサンドボックス", .zh: "安全沙盒", .ru: "Песочница безопасности", .fr: "Bac à sable de sécurité"
        ]
    ]

    func tr(_ key: String) -> String {
        return dictionary[key]?[currentLanguage] ?? dictionary[key]?[.ko] ?? key
    }
}

// MARK: - 우편 모델
struct MailItem: Identifiable, Codable {
    let id: Int
    let target_device_id: String
    let title: String
    let content: String
    let date: String
}

// MARK: - 기기 식별자 & Supabase 연동 모듈
struct DeviceIdManager {
    private static let salt = "BM_DEVICE_SALT_2026"

    static let supabaseUrl = "https://xirtaynusdyvtntlodpz.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhpcnRheW51c2R5dnRudGxvZHB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MTQ5NTUsImV4cCI6MjEwNDE5MDk1NX0.RCiocVn7PZQnWHnyN8tGQ08AV5M5ZbvvIKB6-eQRseI"

    static func getEncryptedShortId() -> String {
        let rawUUID = UIDevice.current.identifierForVendor?.uuidString ?? "FALLBACK-DEVICE"
        let salted = rawUUID + salt
        let digest = SHA256.hash(data: Data(salted.utf8))
        let hexString = digest.map { String(format: "%02X", $0) }.joined()
        return String(hexString.prefix(8))
    }

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

    static func syncDeviceToServer() {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/devices") else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowStr = formatter.string(from: Date())

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: String] = [
            "device_id": getEncryptedShortId(),
            "device_name": getDeviceModelName(),
            "last_seen": nowStr
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
}

// MARK: - 미디어 영구 캐시 및 다운로드 매니저
class MediaDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = MediaDownloadManager()

    @Published var isDownloading: Bool = false
    @Published var progress: Double = 0.0
    @Published var loadedSizeText: String = "0.0MB / 0.0MB"
    @Published var activeURL: URL? = nil

    private var completionHandler: ((URL?) -> Void)?
    private var isVideoFile: Bool = false

    private var cacheDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("MailMediaCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func getCachedFileURL(for remoteURL: URL) -> URL {
        let ext = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        let hash = SHA256.hash(data: Data(remoteURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }

    func isMediaCached(for remoteURL: URL) -> Bool {
        let cachedURL = getCachedFileURL(for: remoteURL)
        return FileManager.default.fileExists(atPath: cachedURL.path)
    }

    func downloadOrGetMedia(url: URL, isVideo: Bool, completion: @escaping (URL?) -> Void) {
        let cachedURL = getCachedFileURL(for: url)

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            completion(cachedURL)
            return
        }

        self.completionHandler = completion
        self.isVideoFile = isVideo
        self.activeURL = url
        self.progress = 0.0
        self.loadedSizeText = "0.0MB / 0.0MB"
        self.isDownloading = true

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.downloadTask(with: url)
        task.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.progress = p
            let loadedMB = Double(totalBytesWritten) / (1024 * 1024)
            let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            self.loadedSizeText = String(format: "%.1fMB / %.1fMB", loadedMB, totalMB)
        } else {
            let loadedMB = Double(totalBytesWritten) / (1024 * 1024)
            self.loadedSizeText = String(format: "%.1fMB", loadedMB)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let sourceURL = self.activeURL else {
            finish(localURL: nil)
            return
        }

        let destinationURL = getCachedFileURL(for: sourceURL)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: location, to: destinationURL)
            finish(localURL: destinationURL)
        } catch {
            finish(localURL: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            finish(localURL: nil)
        }
    }

    private func finish(localURL: URL?) {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.activeURL = nil
            if localURL != nil {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            self.completionHandler?(localURL)
        }
    }
}

// MARK: - 닫기 버튼이 포함된 QuickLook 뷰어
struct QuickLookPreviewView: UIViewControllerRepresentable {
    let fileURL: URL
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let qlController = CustomQLController()
        qlController.dataSource = context.coordinator
        
        let nav = UINavigationController(rootViewController: qlController)
        qlController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: LocalizationManager.shared.tr("close"),
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.dismissSelf)
        )
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class CustomQLController: QLPreviewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.isNavigationBarHidden = false
        }
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreviewView
        init(_ parent: QuickLookPreviewView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.fileURL as QLPreviewItem
        }

        @objc func dismissSelf() {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Video.js 플레이어
struct VideoJSPlayerView: UIViewRepresentable {
    let videoURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <link href="https://vjs.zencdn.net/8.10.0/video-js.css" rel="stylesheet" />
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                .video-js { width: 100% !important; height: 100% !important; }
                .video-js .vjs-tech { object-fit: contain; }
                .vjs-control-bar { background: rgba(15, 15, 20, 0.75) !important; backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); border-radius: 0 0 10px 10px; }
                .vjs-play-progress, .vjs-volume-level { background-color: #3b82f6 !important; }
                .vjs-big-play-button { border-radius: 50% !important; width: 50px !important; height: 50px !important; line-height: 50px !important; border: 2px solid rgba(255,255,255,0.8) !important; background: rgba(0,0,0,0.6) !important; margin-left: -25px !important; margin-top: -25px !important; }
            </style>
        </head>
        <body>
            <video id="my-video" 
                   class="video-js vjs-default-skin vjs-big-play-centered" 
                   controls 
                   preload="metadata" 
                   playsinline 
                   webkit-playsinline>
                <source src="\(videoURL.absoluteString)" type="video/mp4">
            </video>
            <script src="https://vjs.zencdn.net/8.10.0/video.min.js"></script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
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
    @StateObject private var langMgr = LocalizationManager.shared

    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!
    @State private var isLoading: Bool = true
    @State private var showInfoSheet: Bool = false
    @State private var showMailSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    
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
                        onSettings: { showSettingsSheet = true },
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
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(isPresented: $showInfoSheet) {
                AppInfoView(onEasterEggTriggered: {
                    showInfoSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let easterEggURL = URL(string: "https://cdn.mtdv.me/video/rick.mp4") {
                            self.currentURL = easterEggURL
                        }
                    }
                })
            }
            .sheet(isPresented: $showMailSheet) {
                MailboxView(onNavigateURL: { targetURL in
                    showMailSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.currentURL = targetURL
                    }
                })
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
            .environmentObject(langMgr)
        }
    }
}

// MARK: - 하단 리퀴드 글래스 컨트롤 바 (설정 톱니바퀴 추가)
struct LiquidGlassNavigationBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onMail: () -> Void
    let onSettings: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 20) {
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

            // 설정 버튼
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
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

// MARK: - 설정 모달 (언어 실시간 변경)
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var langMgr = LocalizationManager.shared

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(langMgr.tr("settings"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text(langMgr.tr("language_sub"))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text(langMgr.tr("language_setting"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)

                    VStack(spacing: 4) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button(action: {
                                langMgr.currentLanguage = lang
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }) {
                                HStack {
                                    Text(lang.displayName)
                                        .font(.system(size: 14, weight: langMgr.currentLanguage == lang ? .bold : .medium))
                                        .foregroundColor(langMgr.currentLanguage == lang ? .white : .gray)
                                    Spacer()
                                    if langMgr.currentLanguage == lang {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(langMgr.currentLanguage == lang ? Color.white.opacity(0.08) : Color.clear)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(6)
                    .background(
                        ZStack {
                            BlurView(style: .systemThinMaterialDark)
                            Color.white.opacity(0.03)
                        }
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text(langMgr.tr("close"))
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
}

// MARK: - 우편 본문 뷰
struct MailContentView: View {
    let content: String
    let onNavigateURL: ((URL) -> Void)?

    @ObservedObject var langMgr = LocalizationManager.shared
    @ObservedObject var downloadManager = MediaDownloadManager.shared
    @State private var quickLookURL: URL? = nil
    @State private var updateTrigger: Bool = false

    struct ActionBtn: Identifiable {
        let id = UUID()
        let label: String
        let url: URL
    }

    var parsedButtons: [ActionBtn] {
        let pattern = "\\[([^\\]]+)\\]\\((https?://[^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        return matches.compactMap { m in
            guard m.numberOfRanges >= 3 else { return nil }
            let title = nsContent.substring(with: m.range(at: 1))
            let urlString = nsContent.substring(with: m.range(at: 2))
            guard let url = URL(string: urlString) else { return nil }
            return ActionBtn(label: title, url: url)
        }
    }

    var parsedVideos: [URL] {
        let pattern = "(https?://[^\\s]+\\.(?:mp4|mov|webm|m4v))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        return matches.compactMap { m in
            let urlString = nsContent.substring(with: m.range)
            return URL(string: urlString)
        }
    }

    var parsedImages: [URL] {
        let pattern = "(https?://[^\\s]+\\.(?:png|jpg|jpeg|gif|webp))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        return matches.compactMap { m in
            let urlString = nsContent.substring(with: m.range)
            return URL(string: urlString)
        }
    }

    var cleanedText: String {
        var txt = content
        txt = txt.replacingOccurrences(of: "\\[([^\\]]+)\\]\\((https?://[^\\)]+)\\)", with: "", options: .regularExpression)
        txt = txt.replacingOccurrences(of: "(https?://[^\\s]+\\.(?:mp4|mov|webm|m4v))", with: "", options: .regularExpression)
        txt = txt.replacingOccurrences(of: "(https?://[^\\s]+\\.(?:png|jpg|jpeg|gif|webp))", with: "", options: .regularExpression)
        return txt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !cleanedText.isEmpty {
                Text(cleanedText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }

            // 동영상
            ForEach(parsedVideos, id: \.self) { vidURL in
                let isCached = downloadManager.isMediaCached(for: vidURL)

                VStack(alignment: .trailing, spacing: 8) {
                    VideoJSPlayerView(videoURL: vidURL)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.8))

                    if downloadManager.isDownloading && downloadManager.activeURL == vidURL {
                        VStack(alignment: .trailing, spacing: 5) {
                            HStack {
                                Text(langMgr.tr("downloading"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(downloadManager.progress * 100))% (\(downloadManager.loadedSizeText))")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            ProgressView(value: downloadManager.progress, total: 1.0)
                                .tint(.blue)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            downloadManager.downloadOrGetMedia(url: vidURL, isVideo: true) { localURL in
                                if let localURL = localURL {
                                    self.quickLookURL = localURL
                                    self.updateTrigger.toggle()
                                }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: isCached ? "play.circle.fill" : "arrow.down.circle")
                                Text(isCached ? langMgr.tr("open_preview") : langMgr.tr("download_and_preview"))
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isCached ? .green : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // 이미지 및 GIF
            ForEach(parsedImages, id: \.self) { imgURL in
                let isCached = downloadManager.isMediaCached(for: imgURL)

                VStack(alignment: .trailing, spacing: 6) {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                                .onTapGesture {
                                    downloadManager.downloadOrGetMedia(url: imgURL, isVideo: false) { localURL in
                                        if let localURL = localURL {
                                            self.quickLookURL = localURL
                                            self.updateTrigger.toggle()
                                        }
                                    }
                                }
                        case .empty:
                            ProgressView().colorScheme(.dark).frame(height: 120)
                        default:
                            EmptyView()
                        }
                    }

                    if downloadManager.isDownloading && downloadManager.activeURL == imgURL {
                        HStack {
                            Text("\(Int(downloadManager.progress * 100))% (\(downloadManager.loadedSizeText))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                            ProgressView(value: downloadManager.progress, total: 1.0)
                                .frame(width: 80)
                                .tint(.blue)
                        }
                    } else if isCached {
                        Text(langMgr.tr("downloaded_tag"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            }

            // 버튼 렌더링
            if !parsedButtons.isEmpty {
                VStack(spacing: 8) {
                    ForEach(parsedButtons) { btn in
                        Button(action: {
                            onNavigateURL?(btn.url)
                        }) {
                            HStack {
                                Text(btn.label)
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.9), Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.blue.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .fullScreenCover(item: Binding(
            get: { quickLookURL.map { IdentifiableURL(url: $0) } },
            set: { quickLookURL = $0?.url }
        )) { item in
            QuickLookPreviewView(fileURL: item.url)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 우편함 모달
struct MailboxView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var langMgr = LocalizationManager.shared
    var onNavigateURL: ((URL) -> Void)? = nil

    @State private var mails: [MailItem] = []
    @State private var isFetching = true
    @State private var copySuccess = false

    var shortDeviceId: String { DeviceIdManager.getEncryptedShortId() }
    var deviceModelName: String { DeviceIdManager.getDeviceModelName() }

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
                        Text(langMgr.tr("mailbox"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(langMgr.tr("mailbox_sub"))
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
                            Text(copySuccess ? langMgr.tr("copied") : langMgr.tr("copy_number"))
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
                        Text(langMgr.tr("empty_mailbox"))
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

                                    MailContentView(content: mail.content, onNavigateURL: onNavigateURL)
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
                    Text(langMgr.tr("close"))
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
        let queryUrlStr = "\(DeviceIdManager.supabaseUrl)/rest/v1/inbox?select=*&order=id.desc&or=(target_device_id.eq.ALL,target_device_id.eq.\(shortDeviceId))"
        guard let url = URL(string: queryUrlStr) else {
            self.isFetching = false
            return
        }

        var req = URLRequest(url: url)
        req.setValue(DeviceIdManager.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(DeviceIdManager.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.isFetching = false
                guard let data = data,
                      let decoded = try? JSONDecoder().decode([MailItem].self, from: data) else {
                    return
                }
                self.mails = decoded
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
        config.mediaTypesRequiringUserActionForPlayback = []
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
        if let current = uiView.url, current != url {
            uiView.load(URLRequest(url: url))
        }

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

            let fileExtensions = ["zip", "ipa", "pdf", "apk", "rar", "7z", "txt", "png", "jpg", "jpeg", "gif"]
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
    @ObservedObject var langMgr = LocalizationManager.shared
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
                Text(langMgr.tr("connecting")).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.gray.opacity(0.8)).tracking(2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotateDegree = 360 }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isPulsing = true }
        }
    }
}

// MARK: - 앱 정보 모달 (방패 6번 터치 이스터에그)
struct AppInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var langMgr = LocalizationManager.shared
    var onEasterEggTriggered: (() -> Void)? = nil

    @State private var dragRotationX: Double = 0
    @State private var dragRotationY: Double = 0
    @State private var tapCount: Int = 0
    @State private var lastTapTime: Date = Date()

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
                    .onTapGesture {
                        let now = Date()
                        if now.timeIntervalSince(lastTapTime) > 1.2 {
                            tapCount = 1
                        } else {
                            tapCount += 1
                        }
                        lastTapTime = now

                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()

                        if tapCount >= 6 {
                            tapCount = 0
                            let heavyGenerator = UINotificationFeedbackGenerator()
                            heavyGenerator.notificationOccurred(.success)
                            onEasterEggTriggered?()
                        }
                    }
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

                    Text(langMgr.tr("drag_shield_hint"))
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.top, 4)

                VStack(spacing: 14) {
                    infoRow(title: langMgr.tr("app_version"), value: "v\(appVersion)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: langMgr.tr("build_number"), value: "Build #\(buildNumber)")
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: langMgr.tr("device_model"), value: DeviceIdManager.getDeviceModelName())
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: langMgr.tr("passkey_auth"), value: langMgr.tr("passkey_disabled"))
                    Divider().background(Color.white.opacity(0.1))
                    infoRow(title: langMgr.tr("security_sandbox"), value: "TLS 1.3")
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
                    Text(langMgr.tr("close"))
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
                .foregroundColor(value == langMgr.tr("passkey_disabled") ? Color.red.opacity(0.8) : .white)
        }
    }
}
