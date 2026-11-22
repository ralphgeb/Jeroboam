import Foundation

/// The shared price list online (backend/cloudflare): asked first, and told about every price this phone had to find.
/// Quiet when it is not set up (no address in the build) or offline. Only a wine's name, producer, vintage and price go out.
enum PriceCloud {
    private static func setting(_ key: String) -> String? {
        let v = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return v.isEmpty || v.hasPrefix("$(") ? nil : v
    }
    private static var base: URL? { setting("JeroPriceURL").flatMap { URL(string: $0) } }
    private static var key: String? { setting("JeroPriceKey") }
    static var isOn: Bool { base != nil && key != nil }

    private static func request(_ path: String, query: [URLQueryItem] = [], method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let base, let key, var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
        if !query.isEmpty { c.queryItems = query }
        guard let url = c.url else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 5
        r.setValue(key, forHTTPHeaderField: "x-jero-key")
        if let body { r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "content-type") }
        return r
    }

    /// A price someone has already found for this wine.
    static func price(for w: WineIdentity) async -> PriceInfo? {
        guard let req = request("price", query: [URLQueryItem(name: "key", value: WineDB.key(w))]) else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let usd = (o["usd"] as? NSNumber)?.doubleValue, usd > 0 else { return nil }
        let low = (o["low"] as? NSNumber)?.doubleValue ?? usd * 0.85, high = (o["high"] as? NSNumber)?.doubleValue ?? usd * 1.2
        return PriceInfo(average: usd, low: low, high: high, currency: "USD", source: (o["source"] as? String) ?? "Estimate", url: nil)
    }

    /// Adds (or improves) the shared entry. Fire and forget.
    static func share(_ w: WineIdentity, price p: PriceInfo) {
        guard p.currency == "USD" || p.currency.isEmpty, p.average > 0 else { return }
        let body: [String: Any] = ["key": WineDB.key(w), "name": w.name, "producer": w.producer, "vintage": w.vintage,
                                   "usd": p.average, "low": p.low, "high": p.high, "source": p.source]
        guard let data = try? JSONSerialization.data(withJSONObject: body), let req = request("price", method: "POST", body: data) else { return }
        Task.detached(priority: .background) { _ = try? await URLSession.shared.data(for: req) }
    }
}
