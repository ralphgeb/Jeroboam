import Foundation

/// Keeps the shop price list live: the app checks a web address (JeroPriceListURL, by default the price file in the public
/// repository) and downloads it when it changed (ETag), so updating the file updates every phone without a new build.
/// Quiet when offline. The bundled list is the fallback.
enum PriceUpdater {
    private static var fileURL: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("prices-live.tsv")
    }
    /// The downloaded list, if there is one.
    static var downloaded: URL? {
        guard let u = fileURL, FileManager.default.fileExists(atPath: u.path) else { return nil }
        return u
    }
    private static var source: URL? {
        let v = (Bundle.main.object(forInfoDictionaryKey: "JeroPriceListURL") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let s = v.isEmpty || v.hasPrefix("$(") ? "https://raw.githubusercontent.com/ralphgeb/Jeroboam/main/Jeroboam/Resources/Prices/prices.tsv" : v
        return URL(string: s)
    }
    private static let etagKey = "priceListETag"

    /// At most once every 6 hours.
    static func refresh() async {
        let d = UserDefaults.standard
        if let last = d.object(forKey: "priceListChecked") as? Date, Date().timeIntervalSince(last) < 6 * 3600 { return }
        guard let src = source, let dest = fileURL else { return }
        var req = URLRequest(url: src)
        req.timeoutInterval = 60
        if downloaded != nil, let tag = d.string(forKey: etagKey) { req.setValue(tag, forHTTPHeaderField: "If-None-Match") }
        guard let (tmp, resp) = try? await URLSession.shared.download(for: req), let http = resp as? HTTPURLResponse else { return }
        d.set(Date(), forKey: "priceListChecked")
        guard http.statusCode == 200 else { return }
        // a list that is clearly broken must never replace a good one
        guard let size = (try? FileManager.default.attributesOfItem(atPath: tmp.path)[.size] as? Int), size > 1_000_000 else { return }
        try? FileManager.default.removeItem(at: dest)
        guard (try? FileManager.default.moveItem(at: tmp, to: dest)) != nil else { return }
        if let tag = http.value(forHTTPHeaderField: "Etag") ?? http.value(forHTTPHeaderField: "ETag") { d.set(tag, forKey: etagKey) }
        PriceBook.shared.reload()
    }
}
