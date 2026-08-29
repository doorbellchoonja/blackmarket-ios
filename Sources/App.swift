import SwiftUI
import WebKit

@main
struct BlackMarketApp: App {
    @State private var currentURL: URL = URL(string: "https://web.black-market.store")!

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                WebViewContainer(url: currentURL)
                    .edgesIgnoringSafeArea(.all)
            }
            // blackmarket:// 스키마로 열렸을 때 이벤트 감지 및 처리
            .onOpenURL { url in
                print("Received URL: \(url.absoluteString)")
                // blackmarket:// 뒤에 특정 경로가 있으면 웹뷰 이동, 없으면 기본 웹 로드
                if let host = url.host, !host.isEmpty {
                    if let targetURL = URL(string: "https://web.black-market.store/\(host)") {
                        self.currentURL = targetURL
                    }
                }
            }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.bounces = true
        
        // 로딩 화면 (UIActivityIndicatorView) 생성 및 웹뷰 중앙에 부착
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        
        webView.addSubview(spinner)
        context.coordinator.spinner = spinner
        
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var spinner: UIActivityIndicatorView?

        // 웹페이지 로딩 시작 시
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            spinner?.startAnimating()
        }

        // 웹페이지 로딩 완료 시 스피너 숨김
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            spinner?.stopAnimating()
        }

        // 로딩 실패 시 스피너 숨김
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            spinner?.stopAnimating()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            spinner?.stopAnimating()
        }
    }
}
