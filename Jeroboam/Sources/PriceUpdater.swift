import Foundation

/// Keeps the shop price list and wine details live: the app checks a web address (JeroPriceListURL, by default the price file in the public
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
        let s = v.isEmpty || v.hasPrefix("$(") ? "https://raw.githubusercontent.com/ralphgeb/Jeroboam/main/content/prices/app_wines.tsv.z" : v
        return URL(string: s)
    }
    private static let etagKey = "wineListETag"

    /// At most once every 6 hours.
    /// `force`: pulling down in the cellar checks right away (a list that has not changed costs nothing: the ETag answers 304).
    static func refresh(force: Bool = false) async {
        let d = UserDefaults.standard
        // no list on the phone yet (a new install): fetch it now, whatever the clock says
        if !force, downloaded != nil, let last = d.object(forKey: "wineListChecked") as? Date, Date().timeIntervalSince(last) < 6 * 3600 { return }
        guard let src = source, let dest = fileURL else { return }
        var req = URLRequest(url: src)
        req.timeoutInterval = 60
        if downloaded != nil, let tag = d.string(forKey: etagKey) { req.setValue(tag, forHTTPHeaderField: "If-None-Match") }
        guard let (tmp, resp) = try? await URLSession.shared.download(for: req), let http = resp as? HTTPURLResponse else { return }
        d.set(Date(), forKey: "wineListChecked")
        guard http.statusCode == 200 else { return }
        // the list comes compressed (raw deflate): prices, and what the wine database knows about each bottle
        guard let packed = try? Data(contentsOf: tmp), packed.count > 1_000_000,
              let text = try? (packed as NSData).decompressed(using: .zlib) as Data, text.count > 5_000_000 else { return }   // a broken list never replaces a good one
        guard (try? text.write(to: dest, options: .atomic)) != nil else { return }
        if let tag = http.value(forHTTPHeaderField: "Etag") ?? http.value(forHTTPHeaderField: "ETag") { d.set(tag, forKey: etagKey) }
        PriceBook.shared.reload()
        PriceBook.shared.warm()     // the new list is indexed right away, not at the next scan
    }
}
