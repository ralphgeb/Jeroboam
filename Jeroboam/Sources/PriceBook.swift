import Foundation

/// The shop price list (content/prices): about 70,000 wines with their average price across shops. Looked up by name words
/// and vintage when a bottle is scanned or typed in. Loaded the first time it is needed.
final class PriceBook {
    static let shared = PriceBook()

    private struct Row {
        let usd: Double, low: Double, high: Double
        let vintage: String
        let size: Int
        let shops: Int
        let link: String
        let tokens: Set<String>
    }
    private var rows: [Row] = []
    private var index: [String: [Int32]] = [:]
    private let lock = NSLock()
    private var loaded = false

    private static let skip: Set<String> = ["wine", "wines", "the", "and", "des", "les", "del", "della", "domaine", "cuvee", "vintage"]

    static func tokens(_ s: String) -> Set<String> {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var out = Set<String>()
        var cur = ""
        for ch in folded {
            if ch.isLetter || ch.isNumber { cur.append(ch) }
            else { if cur.count >= 3 && !skip.contains(cur) && !(cur.count == 4 && Int(cur) != nil) { out.insert(cur) }; cur = "" }
        }
        if cur.count >= 3 && !skip.contains(cur) && !(cur.count == 4 && Int(cur) != nil) { out.insert(cur) }
        return out
    }

    /// Throws the loaded list away so the next lookup reads the newly downloaded file.
    func reload() {
        lock.lock(); defer { lock.unlock() }
        rows = []; index = [:]; loaded = false
    }

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        // the list downloaded by PriceUpdater (newer than the one in the app) wins; the bundled one is the offline fallback
        guard let url = PriceUpdater.downloaded
                ?? Bundle.main.url(forResource: "prices", withExtension: "tsv", subdirectory: "Prices")
                ?? Bundle.main.url(forResource: "prices", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        rows.reserveCapacity(75_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 8, let usd = Double(f[4]), usd > 0 else { continue }
            let toks = Self.tokens(f[0] + " " + f[1])
            guard !toks.isEmpty else { continue }
            let i = Int32(rows.count)
            rows.append(Row(usd: usd, low: Double(f[5]) ?? 0, high: Double(f[6]) ?? 0, vintage: f[2], size: Int(f[3]) ?? 750, shops: Int(f[7]) ?? 1, link: f.count > 8 ? f[8] : "", tokens: toks))
            for t in toks { index[t, default: []].append(i) }
        }
    }

    /// The cheapest price for this wine in the list. Among the rows that match the name, the vintage decides first (the same
    /// year, else the closest year), then 750 ml, then the lowest price; the price shown is that cheapest shop's price and the
    /// link goes to the same shop.
    func price(for w: WineIdentity) -> PriceInfo? {
        loadIfNeeded()
        let q = Self.tokens(w.producer + " " + w.name)
        guard !q.isEmpty, !rows.isEmpty else { return nil }
        let rare = q.compactMap { t in index[t].map { (t, $0) } }.sorted { $0.1.count < $1.1.count }.prefix(3)
        guard !rare.isEmpty else { return nil }
        var seen = Set<Int32>()
        var cands: [(score: Double, row: Row)] = []
        for (_, posting) in rare where posting.count < 12_000 {
            for i in posting where seen.insert(i).inserted {
                let r = rows[Int(i)]
                let matched = q.intersection(r.tokens).count
                let coverage = Double(matched) / Double(q.count)
                guard coverage >= 0.75, matched >= min(2, q.count) else { continue }
                cands.append((coverage * 10 - Double(r.tokens.count - matched) * 0.15, r))
            }
        }
        guard let top = cands.map(\.score).max() else { return nil }
        // the best-matching names only (a different wine of the same house must not win on price)
        let pool = cands.filter { $0.score >= top - 0.35 }
        let want = Int(w.vintage.trimmingCharacters(in: .whitespaces))
        func gap(_ r: Row) -> Int {
            guard let want else { return 0 }
            guard let y = Int(r.vintage) else { return 40 }   // no vintage in the list: after any real year
            return abs(y - want)
        }
        /// A price per 750 ml bottle: a magnum or a 3 L bottle is divided down, a half bottle scaled up.
        func per750(_ r: Row, _ v: Double) -> Double { r.size > 0 && abs(r.size - 750) > 60 ? v * 750 / Double(r.size) : v }
        func lowest(_ r: Row) -> Double { per750(r, r.low > 0 ? r.low : r.usd) }
        func sizeGap(_ r: Row) -> Double { r.size > 0 ? abs(log(Double(r.size) / 750)) : 0 }
        // 1) the same vintage, else the closest; 2) the size closest to 750 ml; 3) the cleanest name match; 4) the lowest price
        guard let best = pool.min(by: { a, b in
            if gap(a.row) != gap(b.row) { return gap(a.row) < gap(b.row) }
            if abs(sizeGap(a.row) - sizeGap(b.row)) > 0.05 { return sizeGap(a.row) < sizeGap(b.row) }
            if abs(a.score - b.score) > 0.01 { return a.score > b.score }
            return lowest(a.row) < lowest(b.row)
        }) else { return nil }
        let r = best.row
        var src = r.shops > 1 ? "Cheapest of \(r.shops) shops" : "Shop price"
        if let want, let y = Int(r.vintage), y != want { src += " · \(r.vintage) vintage" }
        if r.size > 0 && abs(r.size - 750) > 60 {
            let l = Double(r.size) / 1000
            src += " · \(l == l.rounded() ? String(Int(l)) : String(format: "%.1f", l)) L bottle, per 750 ml"
        }
        return PriceInfo(average: lowest(r), low: lowest(r), high: max(per750(r, r.high), lowest(r)), currency: "USD",
                         source: src, url: r.link.isEmpty ? nil : "https://" + r.link)
    }
}
