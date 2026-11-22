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

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "prices", withExtension: "tsv", subdirectory: "Prices")
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
        let pool = cands.filter { $0.score >= top - 0.8 }.map(\.row)
        let want = Int(w.vintage.trimmingCharacters(in: .whitespaces))
        func gap(_ r: Row) -> Int {
            guard let want else { return 0 }
            guard let y = Int(r.vintage) else { return 40 }   // no vintage in the list: after any real year
            return abs(y - want)
        }
        func lowest(_ r: Row) -> Double { r.low > 0 ? r.low : r.usd }
        guard let r = pool.min(by: { a, b in
            if gap(a) != gap(b) { return gap(a) < gap(b) }
            if (a.size == 750) != (b.size == 750) { return a.size == 750 }
            return lowest(a) < lowest(b)
        }) else { return nil }
        let off = want != nil && gap(r) > 0 && Int(r.vintage) != nil
        let src = (r.shops > 1 ? "Cheapest of \(r.shops) shops" : "Shop price") + (off ? " · \(r.vintage) vintage" : "")
        return PriceInfo(average: lowest(r), low: lowest(r), high: max(r.high, lowest(r)), currency: "USD",
                         source: src, url: r.link.isEmpty ? nil : "https://" + r.link)
    }
}
