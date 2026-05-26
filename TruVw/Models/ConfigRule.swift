import Foundation

// ── Top-level config fetched from GitHub Pages ────────────────────────────────

struct TruVwConfig: Codable {
    var version: Int
    var rules: [ConfigRule]

    static let empty = TruVwConfig(version: 0, rules: [])
}

// ── A single rule: one URL match + one or more injections ─────────────────────

struct ConfigRule: Codable, Identifiable {
    var id: String
    var enabled: Bool
    var match: RuleMatch
    var inject: [Injection]
}

// ── URL matching — all non-nil fields must match (AND logic) ──────────────────

struct RuleMatch: Codable {
    /// e.g. "google.com" — matches host or any subdomain
    var host: String?
    /// substring match on the URL path
    var pathContains: String?
    /// substring match on the full query string (e.g. "q=area+51")
    var queryContains: String?
    /// exact full URL match
    var exactUrl: String?

    func matches(_ url: URL) -> Bool {
        if let host = host {
            let urlHost = url.host ?? ""
            let ok = urlHost == host || urlHost.hasSuffix(".\(host)")
            guard ok else { return false }
        }
        if let path = pathContains {
            guard url.path.contains(path) else { return false }
        }
        if let query = queryContains {
            guard (url.query ?? "").contains(query) else { return false }
        }
        if let exact = exactUrl {
            guard url.absoluteString == exact else { return false }
        }
        return true
    }
}

// ── Injection — polymorphic via type tag ──────────────────────────────────────

struct Injection: Codable {
    var type: InjectionType

    // banner
    var html: String?
    var position: BannerPosition?
    var dismissable: Bool?
    var style: String?           // extra inline CSS for the banner wrapper

    // css
    var cssUrl: String?          // remote .css file URL
    var cssInline: String?       // raw CSS string

    // searchResult
    var title: String?
    var displayUrl: String?
    var snippet: String?
    var targetUrl: String?
    var resultPosition: Int?     // 0 = top of results

    // videoSwap
    var replacementUrl: String?  // direct mp4/m3u8 URL
    var poster: String?          // thumbnail URL
    var videoSelector: String?   // CSS selector to target; default finds first <video>

    // elementReplace
    var selector: String?        // CSS selector of element to replace
    var replacementHtml: String? // HTML to swap in

    // script
    var js: String?              // raw JS to evaluate
    var jsUrl: String?           // remote .js file URL to fetch and eval
}

enum InjectionType: String, Codable {
    case banner
    case css
    case searchResult
    case videoSwap
    case elementReplace
    case script
}

enum BannerPosition: String, Codable {
    case top, bottom
}
