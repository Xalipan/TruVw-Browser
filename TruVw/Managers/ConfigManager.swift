import Foundation
import Combine

class ConfigManager: ObservableObject {

    static let shared = ConfigManager()

    // ── Change this to your GitHub Pages URL ─────────────────────────────────
    static let remoteURL = URL(string: "https://USERNAME.github.io/truvw-config/config.json")!

    @Published var config: TruVwConfig = .empty
    @Published var lastFetched: Date?
    @Published var fetchError: String?

    private let cacheKey = "truvw_config_cache_v1"
    private let cacheDateKey = "truvw_config_cache_date_v1"

    // Refresh at most once per session unless forced
    private var hasFetchedThisSession = false

    private init() {
        loadFromCache()
    }

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
