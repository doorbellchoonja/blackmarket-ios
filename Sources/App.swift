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

                WebViewContainer(url: currentURL, isLoading: $isLoading)
                    .edgesIgnoringSafeArea(.all)

                // 로딩 화면 (최대 1.0초 후 무조건 부드럽게 사라짐)
                if isLoading {
                    CustomLoadingOverlay()
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                        .zIndex(2)
                }
            }
            .onAppear {
                // [핵심] 1.0초 이상 로딩 화면에 머무르지 않도록 강제 해제
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

// MARK: - 로딩 화면 UI
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

// MARK: - 웹뷰
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

        // 진행률이 30%만 넘어도(초기 HTML 수신 즉시) 로딩 닫기
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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        private var observation: NSKeyValueObservation?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func setupProgressObserver(for webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                // 웹페이지 기본 HTML만 들어오면 즉시 로딩 오버레이 제거
                if webView.estimatedProgress >= 0.3 {
                    DispatchQueue.main.async {
                        self?.parent.isLoading = false
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // 웹 화면 그리기 시작 즉시 로딩 끄기
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
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
