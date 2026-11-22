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
            rows.append(Row(usd: usd, low: Double(f[5]) ?? 0, high: Double(f[6]) ?? 0, vintage: f[2], size: Int(f[3]) ?? 750, shops: Int(f[7]) ?? 1, tokens: toks))
            for t in toks { index[t, default: []].append(i) }
        }
    }

    /// The best matching wine in the list, as a price: same vintage preferred, 750 ml preferred.
    func price(for w: WineIdentity) -> PriceInfo? {
        loadIfNeeded()
        let q = Self.tokens(w.producer + " " + w.name)
        guard !q.isEmpty, !rows.isEmpty else { return nil }
        // candidates come from the rarest words of the query
        let rare = q.compactMap { t in index[t].map { (t, $0) } }.sorted { $0.1.count < $1.1.count }.prefix(3)
        guard !rare.isEmpty else { return nil }
        var seen = Set<Int32>()
        var best: (Double, Row)? = nil
        let vintage = w.vintage.trimmingCharacters(in: .whitespaces)
        for (_, posting) in rare where posting.count < 12_000 {
            for i in posting where seen.insert(i).inserted {
                let r = rows[Int(i)]
                let matched = q.intersection(r.tokens).count
                let coverage = Double(matched) / Double(q.count)
                guard coverage >= 0.75, matched >= min(2, q.count) else { continue }
                var rank = coverage * 10 - Double(r.tokens.count - matched) * 0.15
                if !vintage.isEmpty { rank += r.vintage == vintage ? 3 : (r.vintage.isEmpty ? 0.5 : 0) }
                if r.size == 750 { rank += 1 }
                if best == nil || rank > best!.0 { best = (rank, r) }
            }
        }
        guard let r = best?.1 else { return nil }
        return PriceInfo(average: r.usd, low: r.low > 0 ? r.low : r.usd * 0.9, high: r.high > 0 ? r.high : r.usd * 1.1, currency: "USD",
                         source: r.shops > 1 ? "Average of \(r.shops) shops" : "Shop price", url: nil)
    }
}
