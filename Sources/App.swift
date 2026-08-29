import SwiftUI
import WebKit

@main
struct BlackMarketApp: App {
    var body: some Scene {
        WindowGroup {
            WebViewContainer(url: URL(string: "https://web.black-market.store")!)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}
