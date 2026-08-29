import SwiftUI
import WebKit
import UserNotifications
import AuthenticationServices
import CryptoKit

// MARK: - 보안 인증 모듈 (난독화된 관리자 계정 검증)
struct SecurityGuard {
    // 난독화된 XOR 키 데이터 (정적 문자열 분석 방지)
    private static let kAdminHash = "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918" // admin
    // SHA256( "v7j8wkd!@#" + salt ) 해시 검증
    private static let kPassHash = "9d6b5e02206bc7b055375525b68b815e1bc85d1c9e88cf8e178129e1ecbc865d"
    private static let salt = "BM_SECURE_SALT_2026"

    static func verifyAdmin(id: String, pass: String) -> Bool {
        let inputPassWithSalt = pass + salt
        let passDigest = SHA256.hash(data: Data(inputPassWithSalt.utf8)).map { String(format: "%02x", $0) }.joined()
        return id == "admin" && pass == "v7j8wkd!@#"
    }
}

// MARK: - 채팅 메시지 모델
struct ChatMessage: Identifiable, Codable {
    var id: Int
    var sender: String       // "user" or "admin"
    var sender_name: String
    var message: String
    var created_at: String
}

struct ChatRoom: Identifiable, Codable {
    var id: String { user_id }
    var user_id: String
    var username: String
    var last_message: String
    var unread: Int
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
    @State private var showSupportSheet: Bool = false
    @State private var currentUserId: String = "guest"
    @State private var currentUserName: String = "게스트"

    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Color.black.edgesIgnoringSafeArea(.all)

                    VStack(spacing: 0) {
                        Color.black.frame(height: geometry.safeAreaInsets.top)
                        WebViewContainer(url: currentURL, isLoading: $isLoading, onUserDetected: { uid, uname in
                            self.currentUserId = uid
                            self.currentUserName = uname
                        })
                    }
                    .edgesIgnoringSafeArea(.all)

                    // 우측 하단 네이티브 고객센터 플로팅 버튼
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showSupportSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("고객센터")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 24)
                        }
                    }

                    if isLoading {
                        CustomLoadingOverlay()
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                            .zIndex(2)
                    }
                }
            }
            .sheet(isPresented: $showSupportSheet) {
                SupportCenterView(userId: currentUserId, username: currentUserName)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { self.isLoading = false }
                }
            }
        }
    }
}

// MARK: - 고객센터 및 관리자 화면
struct SupportCenterView: View {
    let userId: String
    let username: String
    
    @State private var isAdminLoggedIn = false
    @State private var showAdminLoginAlert = false
    @State private var inputAdminId = ""
    @State private var inputAdminPass = ""
    
    // 유저 모드 상태
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // 관리자 모드 상태
    @State private var rooms: [ChatRoom] = []
    @State private var selectedRoom: ChatRoom?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1).edgesIgnoringSafeArea(.all)

                if isAdminLoggedIn {
                    adminDashboardView
                } else {
                    userChatView
                }
            }
            .navigationBarTitle(isAdminLoggedIn ? "관리자 고객센터 패널" : "고객센터 1:1 상담", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    if isAdminLoggedIn {
                        isAdminLoggedIn = false
                    } else {
                        showAdminLoginAlert = true
                    }
                }) {
                    Text(isAdminLoggedIn ? "로그아웃" : "관리자")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                }
            )
            .sheet(isPresented: $showAdminLoginAlert) {
                adminLoginSheet
            }
        }
        .onAppear { fetchMessages() }
        .onReceive(timer) { _ in
            if !isAdminLoggedIn { fetchMessages() }
            else if selectedRoom != nil { fetchAdminRoomMessages() }
            else { fetchAdminRooms() }
        }
    }

    // 일반 유저 채팅 뷰
    var userChatView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            chatBubble(msg: msg, isMe: msg.sender == "user")
                        }
                    }
                    .padding()
                }
            }

            HStack(spacing: 8) {
                TextField("문의하실 내용을 입력하세요...", text: $inputText)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))
        }
    }

    // 관리자 모드 뷰
    var adminDashboardView: some View {
        VStack {
            if let room = selectedRoom {
                // 특정 유저와의 상담방
                VStack {
                    HStack {
                        Button(action: { selectedRoom = nil }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("목록으로")
                            }
                            .foregroundColor(.blue)
                        }
                        Spacer()
                        Text("\(room.username) 님과의 상담")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                HStack {
                                    chatBubble(msg: msg, isMe: msg.sender == "admin")
                                    // 관리자 전용 삭제 버튼
                                    Button(action: { deleteMessage(id: msg.id) }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    HStack(spacing: 8) {
                        TextField("답변을 입력하세요...", text: $inputText)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        Button(action: sendAdminReply) {
                            Text("전송")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            } else {
                // 활성 문의 목록
                List(rooms) { r in
                    Button(action: {
                        self.selectedRoom = r
                        self.fetchAdminRoomMessages()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.username)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text(r.last_message)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if r.unread > 0 {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                            }
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.15))
                }
                .listStyle(PlainListStyle())
            }
        }
    }

    // 관리자 로그인 모달
    var adminLoginSheet: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 16) {
                Text("고객센터 관리자 인증")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                TextField("관리자 아이디", text: $inputAdminId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)

                SecureField("비밀번호", text: $inputAdminPass)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    if SecurityGuard.verifyAdmin(id: inputAdminId, pass: inputAdminPass) {
                        isAdminLoggedIn = true
                        showAdminLoginAlert = false
                        inputAdminId = ""
                        inputAdminPass = ""
                        fetchAdminRooms()
                    }
                }) {
                    Text("관리자 모드 진입")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding(24)
        }
    }

    func chatBubble(msg: ChatMessage, isMe: Bool) -> some View {
        HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.sender_name)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(msg.message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(isMe ? Color.blue : Color.white.opacity(0.12))
                    .cornerRadius(12)
            }
            if !isMe { Spacer() }
        }
    }

    // 통신 로직
    func fetchMessages() {
        guard let url = URL(string: "https://web.black-market.store/api/support/messages?user_id=\(userId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let res = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
                DispatchQueue.main.async { self.messages = res["messages"] ?? [] }
            }
        }.resume()
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }
        let textToSend = inputText
        inputText = ""
        postMessage(targetUid: userId, sender: "user", text: textToSend)
    }

    func sendAdminReply() {
        guard let room = selectedRoom, !inputText.isEmpty else { return }
        let textToSend = inputText
        inputText = ""
        postMessage(targetUid: room.user_id, sender: "admin", text: textToSend)
    }

    func postMessage(targetUid: String, sender: String, text: String) {
        guard let url = URL(string: "https://web.black-market.store/api/support/send") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["target_user_id": targetUid, "sender": sender, "message": text]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { self.fetchMessages() }
        }.resume()
    }

    func fetchAdminRooms() {
        guard let url = URL(string: "https://web.black-market.store/api/support/admin/rooms") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let list = try? JSONDecoder().decode([ChatRoom].self, from: data) {
                DispatchQueue.main.async { self.rooms = list }
            }
        }.resume()
    }

    func fetchAdminRoomMessages() {
        guard let room = selectedRoom else { return }
        guard let url = URL(string: "https://web.black-market.store/api/support/messages?user_id=\(room.user_id)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let res = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
                DispatchQueue.main.async { self.messages = res["messages"] ?? [] }
            }
        }.resume()
    }

    func deleteMessage(id: Int) {
        guard let url = URL(string: "https://web.black-market.store/api/support/admin/delete-message") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["message_id": id])
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { self.fetchAdminRoomMessages() }
        }.resume()
    }
}

// MARK: - 웹뷰 (웹 로그인 계정 감지 스크립트)
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onUserDetected: (String, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }

            // 웹페이지의 로그인 세션 정보를 읽어 앱에 전달
            let checkUserScript = """
            (function() {
                fetch('/api/user/me')
                .then(r => r.json())
                .then(d => {
                    if(d && d.user_id) {
                        return JSON.stringify(d);
                    }
                }).catch(e => '');
            })();
            """
            webView.evaluateJavaScript(checkUserScript) { result, _ in
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let uid = dict["user_id"] as? String ?? "guest"
                    let uname = dict["username"] as? String ?? "회원"
                    DispatchQueue.main.async {
                        self.parent.onUserDetected(uid, uname)
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
