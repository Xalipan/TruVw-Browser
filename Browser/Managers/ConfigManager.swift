import Foundation
import Combine

class ConfigManager: ObservableObject {

    static let shared = ConfigManager()

    // ── Change this to your GitHub Pages URL ─────────────────────────────────
    static let remoteURL = URL(string: "https://xalipan.github.io/uninscripted/config.json")!

    @Published var config: TruVwConfig = .empty
    @Published var lastFetched: Date?
    @Published var fetchError: String?

    private let cacheKey = "truvw_config_cache_v1"
    private let cacheDateKey = "truvw_config_cache_date_v1"

    // Refresh at most once per session unless forced
    private var hasFetchedThisSession = false

    private init() {
        loadFromCache()
        // If nothing in cache (fresh install) or remote is still placeholder,
        // load the bundled config immediately so rules work out of the box.
        if config.rules.isEmpty {
            loadBundledConfig()
        }
    }

    // MARK: - Bundled config (loaded when no cache / no remote configured)

    private func loadBundledConfig() {
        guard let data = Self.bundledConfigJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TruVwConfig.self, from: data)
        else { return }
        config = decoded
    }

    // Keep this in sync with the config.json file in the project root.
    // It is the live source of truth when GitHub Pages is not configured.
    private static let bundledConfigJSON = #"""
    {
      "version": 2,
      "rules": [
        {
          "id": "graham-hancock-search-css",
          "enabled": true,
          "match": { "host": "google.com", "queryContains": "Graham+Hancock" },
          "inject": [
            {
              "type": "css",
              "cssInline": "body::after { content: ''; position: fixed; bottom: 24px; left: 24px; width: 72px; height: 72px; background-image: url('https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Blank_compass.svg/240px-Blank_compass.svg.png'); background-size: contain; background-repeat: no-repeat; opacity: 0.18; z-index: 999999; pointer-events: none; }"
            }
          ]
        },
        {
          "id": "graham-hancock-search-bold",
          "enabled": true,
          "match": { "host": "google.com", "queryContains": "Graham+Hancock" },
          "inject": [
            {
              "type": "script",
              "js": "(function() { var BOLD = ['author','ancient','civilization','mystery','consciousness','banned','lecture','evidence','forbidden','archaeology','pyramid','flood','myth','sacred','knowledge']; function boldTerms(root) { var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null); var nodes = []; var n; while(n = walker.nextNode()) nodes.push(n); nodes.forEach(function(node) { if (!node.parentNode || node.parentNode.nodeName === 'SCRIPT' || node.parentNode.nodeName === 'STYLE' || node.parentNode.nodeName === 'STRONG') return; var html = node.textContent; var changed = false; BOLD.forEach(function(term) { var re = new RegExp('\\\\b(' + term + ')\\\\b', 'gi'); if (re.test(html)) { html = html.replace(re, '<strong>$1</strong>'); changed = true; } }); if (changed) { var span = document.createElement('span'); span.innerHTML = html; node.parentNode.replaceChild(span, node); } }); } boldTerms(document.body); var obs = new MutationObserver(function(muts) { muts.forEach(function(m) { m.addedNodes.forEach(function(n) { if (n.nodeType === 1) boldTerms(n); }); }); }); obs.observe(document.body, {childList:true, subtree:true}); })();"
            }
          ]
        }
      ]
    }
    """#

    // MARK: - Public

    /// Call at app launch. Uses cache immediately, fetches fresh in background.
    func fetchIfNeeded() {
        loadFromCache()
        guard !hasFetchedThisSession else { return }
        fetch()
    }

    /// Force a fresh fetch regardless of session state.
    func fetch() {
        hasFetchedThisSession = true
        let url = Self.remoteURL

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.fetchError = error.localizedDescription
                }
                return
            }

            guard let data = data else { return }

            do {
                let decoded = try JSONDecoder().decode(TruVwConfig.self, from: data)
                DispatchQueue.main.async {
                    self.config = decoded
                    self.lastFetched = Date()
                    self.fetchError = nil
                }
                self.saveToCache(data: data)
            } catch {
                DispatchQueue.main.async {
                    self.fetchError = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    /// Returns all enabled rules that match the given URL.
    func matchingRules(for url: URL) -> [ConfigRule] {
        config.rules.filter { $0.enabled && $0.match.matches(url) }
    }

    // MARK: - Cache

    private func saveToCache(data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        if let decoded = try? JSONDecoder().decode(TruVwConfig.self, from: data) {
            config = decoded
            lastFetched = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
        }
    }
}
