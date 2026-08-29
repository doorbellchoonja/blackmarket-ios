import SwiftUI
import WebKit
import AuthenticationServices

@main
struct BlackMarketApp: App {
    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!
    @State private var isLoading: Bool = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                // 웹뷰 컨테이너 (패스키 및 현대적 웹 API 활성화)
                WebViewContainer(url: currentURL, isLoading: $isLoading)
                    .edgesIgnoringSafeArea(.all)

                // 커스텀 디자인 로딩 화면 (웹페이지 로드 완료 시 페이드아웃)
                if isLoading {
                    CustomLoadingOverlay()
                        .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                        .zIndex(2)
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

// MARK: - 커스텀 디자인 로딩 화면
struct CustomLoadingOverlay: View {
    @State private var isPulsing = false
    @State private var rotateDegree: Double = 0

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                ZStack {
                    // 배경 네온 글로우 링
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(rotateDegree))
                        .scaleEffect(isPulsing ? 1.05 : 0.95)

                    // 블랙마켓 심볼 텍스트
                    VStack(spacing: 2) {
                        Text("BLACK")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(3)
                        Text("MARKET")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                    }
                }

                // 하단 상태 프로그레스 바
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 3)
                        .overlay(
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 45, height: 3)
                                .offset(x: isPulsing ? 35 : -35)
                        )
                        .clipped()

                    Text("CONNECTING SECURELY...")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.8))
                        .tracking(1.5)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                rotateDegree = 360
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - 패스키(Passkey / WebAuthn) 지원 웹뷰
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    self.parent.isLoading = false
                }
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

        // WebAuthn / Passkey 팝업 및 보안 프로토콜 핸들러
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
