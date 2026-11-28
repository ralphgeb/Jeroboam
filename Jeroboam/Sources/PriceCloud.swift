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

    /// A call to Claude through Jero's server (route /claude), which adds the Anthropic key and keeps each phone to its daily
    /// allowance. nil when the server is not set up in this build.
    static func claudeRequest() -> URLRequest? {
        guard setting("JeroClaudeProxy") == "1", var r = request("claude", method: "POST") else { return nil }
        r.setValue(installID, forHTTPHeaderField: "x-jero-device")
        return r
    }

    /// A random number made on this phone the first time it is needed: it only lets the server count each phone's daily
    /// allowance. It says nothing about the person and is not linked to anything else.
    static var installID: String {
        let d = UserDefaults.standard
        if let id = d.string(forKey: "jero.installID") { return id }
        let id = UUID().uuidString
        d.set(id, forKey: "jero.installID")
        return id
    }

    /// The wine's key plus its color, so a white and a red of the same name never share a price.
    private static func cloudKey(_ w: WineIdentity) -> String { WineDB.key(w) + "|" + w.style.lowercased() }

    /// A price someone has already found for this wine.
    static func price(for w: WineIdentity) async -> PriceInfo? {
        guard let req = request("price", query: [URLQueryItem(name: "key", value: cloudKey(w))]) else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let usd = (o["usd"] as? NSNumber)?.doubleValue, usd > 0 else { return nil }
        let low = (o["low"] as? NSNumber)?.doubleValue ?? usd * 0.85, high = (o["high"] as? NSNumber)?.doubleValue ?? usd * 1.2
        return PriceInfo(average: usd, low: low, high: high, currency: "USD", source: (o["source"] as? String) ?? "Estimate", url: nil)
    }

    /// Adds (or improves) the shared entry. Fire and forget.
    static func share(_ w: WineIdentity, price p: PriceInfo) {
        guard p.currency == "USD" || p.currency.isEmpty, p.average > 0 else { return }
        let body: [String: Any] = ["key": cloudKey(w), "name": w.name, "producer": w.producer, "vintage": w.vintage,
                                   "usd": p.average, "low": p.low, "high": p.high, "source": p.source]
        guard let data = try? JSONSerialization.data(withJSONObject: body), let req = request("price", method: "POST", body: data) else { return }
        Task.detached(priority: .background) { _ = try? await URLSession.shared.data(for: req) }
    }

    /// Once per phone: every price this phone already knows goes into the shared list (sent slowly, a few at a time).
    static func seedOnce() async {
        guard isOn, !UserDefaults.standard.bool(forKey: "priceCloudSeeded"), UserDefaults.standard.bool(forKey: "jero.cellarColorFix2") else { return }
        let items = WineDB.shared.allEntries().compactMap { e -> (WineIdentity, PriceInfo)? in
            guard let p = e.price, p.source != "Estimate", p.currency == "USD" || p.currency.isEmpty else { return nil }
            return (e.identity, p)
        }
        for (w, p) in items.prefix(500) {
            share(w, price: p)
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        UserDefaults.standard.set(true, forKey: "priceCloudSeeded")
    }

    // MARK: wines (every scan is counted, and what Claude found out is kept so nobody pays for it twice)

    /// The wine's details as already found for a label with this signature (or this wine key).
    static func wine(sig: String?, key: String? = nil) async -> WineIdentity? {
        var q: [URLQueryItem] = []
        if let sig { q.append(URLQueryItem(name: "sig", value: sig)) } else if let key { q.append(URLQueryItem(name: "key", value: key)) } else { return nil }
        guard let req = request("wine", query: q),
              let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let j = o["json"] as? String,
              let w = try? JSONDecoder().decode(WineIdentity.self, from: Data(j.utf8)), !w.name.isEmpty else { return nil }
        return w
    }

    /// Counts one more scan of this wine and keeps its details. Only the wine itself goes out: no photo, no name, no device or account.
    /// `count`: true only for the one call per scan (`WineDB.noteScan`); the same wine sent again after its check updates it without
    /// counting a second scan.
    static func shareWine(_ w: WineIdentity, sig: String? = nil, count: Bool = false) {
        guard w.found, !w.name.isEmpty, let json = (try? JSONEncoder().encode(w)).flatMap({ String(data: $0, encoding: .utf8) }) else { return }
        var body: [String: Any] = ["key": WineDB.key(w), "json": json, "name": w.name, "producer": w.producer, "vintage": w.vintage,
                                   "region": w.region, "country": w.country, "style": w.style, "count": count]
        if let sig { body["sig"] = sig }
        guard let data = try? JSONSerialization.data(withJSONObject: body), var req = request("wine", method: "POST", body: data) else { return }
        // a counted scan carries the phone's random install number, so the server can count how many phones scan each day
        // (never linked to a person; the same number as the Claude allowance uses)
        if count { req.setValue(installID, forHTTPHeaderField: "x-jero-device") }
        Task.detached(priority: .background) { _ = try? await URLSession.shared.data(for: req) }
    }

    /// A label's visual fingerprint for the wine it turned out to be (`LabelPrint`). Anonymous: the wine's key and numbers only.
    static func sharePrint(key: String, print: Data, revision: Int, count: Int) {
        let body: [String: Any] = ["key": key, "rev": revision, "dims": count, "vec": print.base64EncodedString()]
        guard let data = try? JSONSerialization.data(withJSONObject: body), let req = request("print", method: "POST", body: data) else { return }
        Task.detached(priority: .background) { _ = try? await URLSession.shared.data(for: req) }
    }

    /// TestFlight: the fingerprint checks GitHub made for recent scans (`FingerprintCheckView`). Raw rows; empty when unreachable.
    static func printChecks() async -> [[String: Any]] {
        guard let req = request("prints/checks", query: [URLQueryItem(name: "limit", value: "40")]),
              let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return obj["rows"] as? [[String: Any]] ?? []
    }

    /// A wine corrected by hand: the online wine list drops the wrong wine and gives its label signature, label fingerprints and
    /// fingerprint checks to the corrected one (worker `POST /wine/correct`), so the next scan of that label finds the right wine.
    /// A correction every phone takes in (see WineFixes): the wrong wine's key and the right wine.
    struct Fix { let id: Int; let from: String; let to: String; let wine: WineIdentity? }

    static func fixes(since: Int) async -> [Fix] {
        guard let req = request("wine/fixes", query: [URLQueryItem(name: "since", value: String(since))]),
              let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let list = o["fixes"] as? [[String: Any]] else { return [] }
        return list.compactMap { f in
            guard let id = (f["id"] as? NSNumber)?.intValue, let from = f["from"] as? String, let to = f["to"] as? String else { return nil }
            let w = (f["json"] as? String).flatMap { try? JSONDecoder().decode(WineIdentity.self, from: Data($0.utf8)) }
            return Fix(id: id, from: from, to: to, wine: w)
        }
    }

    static func correctWine(from oldKey: String, to newKey: String) {
        let body: [String: Any] = ["from": oldKey, "to": newKey]
        guard let data = try? JSONSerialization.data(withJSONObject: body), let req = request("wine/correct", method: "POST", body: data) else { return }
        Task.detached(priority: .background) { _ = try? await URLSession.shared.data(for: req) }
    }
}
