# SafariClone

A full-featured iOS browser built with SwiftUI + WKWebView, deployable directly to your iOS device.

## Features

- **Full WKWebView browsing** — renders any website just like Safari
- **Multi-tab support** — tab switcher with live snapshots, open/close/switch tabs
- **Address bar** — smart URL resolution: bare domains → `https://`, plain text → Google search
- **Bookmarks** — add, remove, organize into folders, persisted across launches
- **History** — grouped by date, searchable, clearable, persisted
- **Downloads** — intercepts `Content-Disposition: attachment` and downloadable file URLs, saves to Documents/Downloads
- **Start page** — clock, favorites grid, recently visited
- **Find on page** — uses native WKWebView find API (iOS 16+)
- **Pull to refresh** — standard iOS pattern
- **Share sheet** — share current URL/page
- **Settings** — search engine picker, popup blocking toggle, privacy controls, cookie clearing
- **DOM Bridge** — ready-made hook system for DOM manipulation (see below)

## Project Structure

```
SafariClone/
├── SafariCloneApp.swift          — App entry point
├── ContentView.swift             — Root browser UI with address bar + toolbar
├── Models/
│   ├── Tab.swift                 — Tab model (owns WKWebView)
│   ├── Bookmark.swift            — Bookmark + BookmarkFolder
│   ├── HistoryItem.swift         — History entry
│   └── DownloadItem.swift        — Download task
├── ViewModels/
│   └── BrowserViewModel.swift    — Central state, navigation logic
├── Managers/
│   ├── TabManager.swift          — Tab lifecycle
│   ├── BookmarkManager.swift     — Bookmark CRUD + persistence
│   ├── HistoryManager.swift      — History recording + persistence
│   ├── DownloadManager.swift     — URLSession download engine
│   └── DOMBridge.swift           — ⭐ DOM hook system (see below)
├── Views/
│   ├── WebView.swift             — UIViewRepresentable WKWebView wrapper
│   ├── AddressBarView.swift      — URL/search bar with progress
│   ├── ToolbarView.swift         — Bottom nav (back/fwd/share/bookmark/tabs)
│   ├── TabGridView.swift         — Card-based tab switcher
│   ├── BookmarksView.swift       — Bookmark browser with folders
│   ├── HistoryView.swift         — History browser
│   ├── DownloadsView.swift       — Download manager
│   ├── StartPageView.swift       — New tab start page
│   └── SettingsView.swift        — App settings
└── Extensions/
    └── Extensions.swift          — UIKit/SwiftUI helpers
```

## Setup in Xcode

1. Open `SafariClone.xcodeproj` in Xcode 15+
2. In the project settings, change **Team** to your Apple Developer account
3. Change **Bundle Identifier** from `com.yourname.SafariClone` to something unique (e.g. `com.yourname.SafariClone`)
4. Connect your iPhone/iPad and select it as the build target
5. **Product → Run** (⌘R)

> **No paid developer account required** — a free Apple ID works for personal device deployment (apps expire after 7 days, re-run to refresh).

### Info.plist / Entitlements

Xcode auto-generates the Info.plist via build settings. The key setting that allows arbitrary HTTP is:

```
INFOPLIST_KEY_NSAppTransportSecurity = "<dict><key>NSAllowsArbitraryLoads</key><true/></dict>"
```

This is already set in `project.pbxproj`.

---

## DOM Bridge — How to Use

`DOMBridge.swift` provides a clean hook system. Attach your logic in `SafariCloneApp.swift` or anywhere before navigation starts.

### Lifecycle hooks

```swift
// Called every time a page finishes loading
DOMBridge.shared.onPageLoaded = { webView, url in
    // Example: remove cookie banners
    webView.evaluateJavaScript("""
        document.querySelectorAll('[id*="cookie"], [class*="cookie-banner"]').forEach(e => e.remove())
    """)
}

// Called when navigation to a new URL starts
DOMBridge.shared.onNavigationStarted = { webView, url in
    print("Navigating to: \(url)")
}

// Inject JS at document-start (before page renders)
DOMBridge.shared.documentStartScript = { webView, url in
    return "window.__myFlag = true;"
}

// Inject JS at document-end (after page loads)
DOMBridge.shared.documentEndScript = { webView, url in
    guard url.host?.contains("example.com") == true else { return nil }
    return "document.body.style.background = 'lightyellow';"
}
```

### Receiving messages from JavaScript

```swift
DOMBridge.shared.onMessageReceived = { message in
    if let body = message.body as? [String: Any],
       let type = body["type"] as? String {
        print("JS message: \(type)", body["data"] ?? "")
    }
}
```

From the page's JavaScript side:
```javascript
window.__domBridge.postMessage('myEvent', { someKey: 'someValue' });
```

### Convenience helpers

```swift
// Inject CSS
DOMBridge.shared.injectCSS("body { font-size: 18px !important; }", in: webView)

// Remove elements
DOMBridge.shared.removeElements(matching: ".ad-banner", in: webView)

// Get page text
DOMBridge.shared.getTextContent(from: webView) { text in
    print(text ?? "")
}

// Get full HTML
DOMBridge.shared.getHTML(from: webView) { html in
    print(html ?? "")
}
```

### Adding persistent user scripts (run on every page)

```swift
let script = WKUserScript(
    source: "window.myHelper = function() { ... };",
    injectionTime: .atDocumentEnd,
    forMainFrameOnly: true
)
DOMBridge.shared.userScripts.append(script)
```

---

## Customization

- **Default search engine**: Change the URL template in `BrowserViewModel.resolveURL(from:)` 
- **Download file types**: Extend the `downloadExtensions` array in `WebView.swift`
- **Blocked content rules**: Set `DOMBridge.shared.contentRules` with WKContentRuleList JSON

## Requirements

- iOS 17.0+
- Xcode 15+
- Swift 5.9+
