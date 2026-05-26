import Foundation
import WebKit

class Tab: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var url: URL?
    @Published var favicon: UIImage?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var snapshot: UIImage?
    /// Flips to true the moment a navigation is requested — before the URL loads.
    /// This lets us swap the start page out for the WebView immediately.
    @Published var hasNavigated: Bool = false

    // Each tab owns its WKWebView
    let webView: WKWebView

    init(id: UUID = UUID(), url: URL? = nil, title: String = "New Tab") {
        self.id = id
        self.url = url
        self.title = title
        self.hasNavigated = url != nil

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Enable JS (required for modern web)
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.allowsLinkPreview = true

        if let url = url {
            webView.load(URLRequest(url: url))
        }
    }
}
