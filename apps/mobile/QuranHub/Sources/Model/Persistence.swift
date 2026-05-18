import Foundation

/// Mirrors the PWA `usePersistentState` exactly: every value is JSON-encoded
/// under `quranaday.v1.<key>` in UserDefaults. Missing / corrupt → default.
enum Store {
    static let prefix = "quranaday.v1."
    private static let enc = JSONEncoder()
    private static let dec = JSONDecoder()

    static func get<T: Codable>(_ key: String, _ fallback: T) -> T {
        guard let data = UserDefaults.standard.string(forKey: prefix + key)?.data(using: .utf8)
        else { return fallback }
        return (try? dec.decode(T.self, from: data)) ?? fallback
    }

    static func set<T: Codable>(_ key: String, _ value: T) {
        guard let data = try? enc.encode(value),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: prefix + key)
    }
}
