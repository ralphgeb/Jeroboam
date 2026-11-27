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
        let color: Int8      // 0 unknown, 1 red, 2 white, 3 rosé
        let detail: Detail?
    }
    /// What the wine database knows about a bottle besides its price (only in the downloaded list).
    struct Detail { let colour: String, country: String, region: String, appellation: String, grapes: [String], aromas: [String], score: Int?, scoreLink: String?, percents: [Int]
                    var critics: [String] = [], criticLinks: [String] = [] }
    struct WineDetails { let colour: String, country: String, region: String, appellation: String, grapes: [String], aromas: [String], score: Int?, scoreLink: String?, percents: [Int]
                         var critics: [String] = [], criticLinks: [String] = [] }
    private var rows: [Row] = []
    private var index: [String: [Int32]] = [:]
    private var labels = LabelMatcher()   // names a wine from its label text (LabelMatcher.swift)
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

    /// A wine whose name is only short words ("EL", "Z") leaves nothing but the producer to match on, so any wine of the house would win
    /// (El Ixsir was priced as Ixsir Altitudes). For such names the shop page's address must contain the short word.
    static func shortNameWords(_ w: WineIdentity) -> [String] {
        guard tokens(w.name).subtracting(tokens(w.producer)).isEmpty else { return [] }
        let folded = w.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        return folded.split { !$0.isLetter }.map(String.init).filter { $0.count <= 2 }
    }
    private static func linkHas(_ row: Row, _ words: [String]) -> Bool {
        if words.isEmpty { return true }
        let have = Set(row.link.lowercased().split { !$0.isLetter }.map(String.init))
        return words.allSatisfy { have.contains($0) }
    }

    // Words that name the color outright beat words that only suggest it (a "Rioja Reserva Blanco" is white even though Rioja is red country).
    private static let whiteSure: Set<String> = ["white", "blanc", "bianco", "blanco", "branco", "weiss", "weisswein", "blancs"]
    private static let redSure: Set<String> = ["red", "rouge", "rosso", "tinto", "rot", "rotwein", "tinta", "nero", "noir"]
    private static let roseSure: Set<String> = ["rose", "rosato", "rosado", "rosat"]
    private static let whiteHint: Set<String> = ["chardonnay", "riesling", "chenin", "viognier", "albarino", "gruner", "veltliner", "vermentino", "muscadet", "semillon", "gewurztraminer", "grigio", "gris", "verdejo", "fiano", "greco", "soave", "chablis", "sancerre", "muscat", "moscato", "trebbiano", "garganega", "cortese", "arneis", "godello", "assyrtiko", "marsanne", "roussanne", "sauternes", "meursault", "montrachet", "sauvignon"]
    private static let redHint: Set<String> = ["cabernet", "merlot", "syrah", "shiraz", "malbec", "nebbiolo", "sangiovese", "tempranillo", "zinfandel", "barolo", "barbaresco", "chianti", "brunello", "pomerol", "pauillac", "margaux", "medoc", "montepulciano", "primitivo", "mourvedre", "carmenere", "pinotage", "tannat", "aglianico", "amarone", "valpolicella", "priorat"]

    /// Quality-tier words: a different tier is a different wine.
    private static let topTierWords: Set<String> = ["gran", "grand", "grande", "premier", "superiore", "crianza", "joven", "selezione"]
    private static let tierWords: Set<String> = topTierWords.union(["reserva", "riserva", "reserve", "cru"])

    /// red (1) / white (2) / rosé (3) from the words of a name; 0 when it cannot tell.
    static func color(of text: String) -> Int8 {
        let t = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var words = Set<String>()
        var cur = ""
        for ch in t { if ch.isLetter { cur.append(ch) } else { if !cur.isEmpty { words.insert(cur) }; cur = "" } }
        if !cur.isEmpty { words.insert(cur) }
        if t.contains("blanc de") { return 2 }
        func pick(_ w: Set<String>, _ r: Set<String>, _ ro: Set<String>) -> Int8 {
            let hw = !words.isDisjoint(with: w), hr = !words.isDisjoint(with: r), hro = !words.isDisjoint(with: ro)
            if hro && !hw && !hr { return 3 }
            if hw && !hr && !hro { return 2 }
            if hr && !hw && !hro { return 1 }
            return 0
        }
        let sure = pick(whiteSure, redSure, roseSure)
        if sure != 0 { return sure }
        return pick(whiteHint, redHint, [])
    }
    /// The color the scanned wine is meant to be: the identified style first, then the words in its name.
    static func color(of w: WineIdentity) -> Int8 {
        let st = w.style.lowercased()
        if st.contains("ros") { return 3 }
        if st.contains("white") { return 2 }
        if st.contains("red") { return 1 }
        return color(of: w.producer + " " + w.name)
    }

    /// Strictest possible match: the same producer and name words (nothing missing, at most three extra), the same vintage, the same
    /// quality tier and a colour that does not disagree. Returns what the database knows, or nil when it is not certainly this bottle.
    func details(for w: WineIdentity) -> WineDetails? {
        loadIfNeeded()
        let q = Self.tokens(w.producer + " " + w.name)
        guard q.count >= 2, !rows.isEmpty else { return nil }
        let want = Int(w.vintage.trimmingCharacters(in: .whitespaces))
        let wineColor = Self.color(of: w)
        let qTier = q.intersection(Self.tierWords)
        let rare = q.compactMap { t in index[t].map { (t, $0) } }.sorted { $0.1.count < $1.1.count }.prefix(2)
        guard rare.count >= 1 else { return nil }
        let short = Self.shortNameWords(w)
        var seen = Set<Int32>()
        var best: [(extra: Int, row: Row, same: Bool)] = []
        for (_, posting) in rare where posting.count < 12_000 {
            for i in posting where seen.insert(i).inserted {
                let r = rows[Int(i)]
                guard let d = r.detail, q.isSubset(of: r.tokens), r.tokens.count - q.count <= 3, Self.linkHas(r, short) else { continue }
                // the same wine of another vintage still tells grapes, place and aromas (the list shares them between vintages); its score is not used
                guard r.tokens.intersection(Self.tierWords) == qTier else { continue }
                let dc: Int8 = d.colour == "r" ? 1 : (d.colour == "w" ? 2 : (d.colour == "p" ? 3 : 0))
                if wineColor != 0, dc != 0, dc != wineColor { continue }
                best.append((r.tokens.count - q.count, r, Int(r.vintage) == want))
            }
        }
        // the same vintage first, then the cleanest name match
        guard let pick = best.min(by: { a, b in
            if a.same != b.same { return a.same }
            if a.extra != b.extra { return a.extra < b.extra }
            return a.row.detail?.score != nil && b.row.detail?.score == nil
        }), let top = pick.row.detail else { return nil }
        // every near-equal candidate must agree on the country, or it is not certainly this bottle
        let near = best.filter { $0.same == pick.same && $0.extra == pick.extra }.compactMap { $0.row.detail }
        if near.contains(where: { !$0.country.isEmpty && !top.country.isEmpty && $0.country != top.country }) { return nil }
        let scored = pick.same ? near.first { $0.score != nil } : nil
        return WineDetails(colour: top.colour, country: top.country, region: top.region, appellation: top.appellation, grapes: top.grapes,
                           aromas: top.aromas, score: pick.same ? (scored?.score ?? top.score) : nil, scoreLink: pick.same ? (scored?.scoreLink ?? top.scoreLink) : nil,
                           percents: top.percents,
                           critics: pick.same ? (scored?.critics ?? top.critics) : [], criticLinks: pick.same ? (scored?.criticLinks ?? top.criticLinks) : [])
    }

    /// Puts what the database knows over what the model guessed, when (and only when) it is certainly this bottle.
    func overlay(_ w: WineIdentity) -> WineIdentity {
        guard let d = details(for: w) else { return w }
        var o = w
        if !d.country.isEmpty { o.country = d.country }
        let place = [d.appellation, d.region].filter { !$0.isEmpty }
        if !place.isEmpty { o.region = place.count == 2 && !place[0].localizedCaseInsensitiveContains(place[1]) ? place.joined(separator: ", ") : place[0] }
        if !d.grapes.isEmpty { o.grapes = d.grapes; o.grapePercent = d.percents.count == d.grapes.count ? d.percents : nil }
        if !d.aromas.isEmpty { o.tastingNotes = Array(d.aromas.prefix(6)) }
        switch d.colour { case "r": o.style = "red"; case "w": o.style = "white"; case "p": o.style = "rose"; case "s": o.style = "sparkling"
                          case "o": o.style = "orange"; case "f": o.style = "fortified"; case "d": o.style = "sweet"; default: break }
        o.dbScore = d.score; o.dbScoreLink = d.scoreLink; o.confidence = "high"; o.fromDatabase = true
        o.dbCritics = d.critics.isEmpty ? nil : d.critics; o.dbCriticLinks = d.criticLinks.isEmpty ? nil : d.criticLinks
        return o
    }

    /// Reads the list and builds its search index now (in the background at launch), so the first scan does not wait for it.
    func warm() { loadIfNeeded() }

    /// Throws the loaded list away so the next lookup reads the newly downloaded file.
    func reload() {
        lock.lock(); defer { lock.unlock() }
        rows = []; index = [:]; labels = LabelMatcher(); loaded = false
    }

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        // the list is not in the app (it would add 29 MB to the download): PriceUpdater fetches it, compressed, after install.
        // Until it arrives, lookups fall back to the shared online list and the estimate; reload() reads it once it is here.
        guard let url = PriceUpdater.downloaded
                ?? Bundle.main.url(forResource: "prices", withExtension: "tsv", subdirectory: "Prices"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { loaded = false; return }
        rows.reserveCapacity(200_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 8, let usd = Double(f[4]), usd > 0 else { continue }
            let toks = Self.tokens(f[0] + " " + f[1])
            guard !toks.isEmpty else { continue }
            let i = Int32(rows.count)
            var detail: Detail? = nil
            if f.count >= 17, !(f[9].isEmpty && f[10].isEmpty && f[11].isEmpty && f[13].isEmpty) {
                detail = Detail(colour: f[9], country: f[10], region: f[11], appellation: f[12],
                                grapes: f[13].split(separator: ";").map(String.init), aromas: f[14].split(separator: ";").map(String.init),
                                score: Int(f[15]), scoreLink: f[16].isEmpty ? nil : f[16],
                                percents: f.count > 17 ? f[17].split(separator: ";").compactMap { Int($0) } : [],
                                critics: f.count > 18 ? f[18].split(separator: ";").map(String.init) : [],
                                criticLinks: f.count > 19 ? f[19].split(separator: ";", omittingEmptySubsequences: false).map(String.init) : [])
            }
            rows.append(Row(usd: usd, low: Double(f[5]) ?? 0, high: Double(f[6]) ?? 0, vintage: f[2], size: Int(f[3]) ?? 750, shops: Int(f[7]) ?? 1, link: f.count > 8 ? f[8] : "", tokens: toks, color: Self.color(of: f[0] + " " + f[1] + " " + (f.count > 8 ? f[8].replacingOccurrences(of: "-", with: " ") : "")), detail: detail))
            for t in toks { index[t, default: []].append(i) }
            labels.add(name: f[0], producer: f[1], place: f.count > 12 ? f[11] + " " + f[12] : "", appellation: f.count > 12 ? f[12] : "", row: i)
        }
    }

    /// The cheapest price for this wine in the list. Among the rows that match the name, the vintage decides first (the same
    /// year, else the closest year), then 750 ml, then the lowest price; the price shown is that cheapest shop's price and the
    /// link goes to the same shop.
    func price(for w: WineIdentity) -> PriceInfo? {
        loadIfNeeded()
        let q = Self.tokens(w.producer + " " + w.name)
        let wineColor = Self.color(of: w)
        guard !q.isEmpty, !rows.isEmpty else { return nil }
        let producerWords = Self.tokens(w.producer).subtracting(LabelMatcher.generic)
        let rare = q.compactMap { t in index[t].map { (t, $0) } }.sorted { $0.1.count < $1.1.count }.prefix(3)
        guard !rare.isEmpty else { return nil }
        let short = Self.shortNameWords(w)
        var seen = Set<Int32>()
        var cands: [(score: Double, row: Row)] = []
        for (_, posting) in rare where posting.count < 12_000 {
            for i in posting where seen.insert(i).inserted {
                let r = rows[Int(i)]
                // the producer's own words must be there: classification words alone ("Premier Grand Cru Classé") fit many
                // châteaux (a misread "Château Nâteau" was priced as Château Canon)
                if !producerWords.isEmpty && producerWords.isDisjoint(with: r.tokens) { continue }
                let matched = q.intersection(r.tokens).count
                let coverage = Double(matched) / Double(q.count)
                guard coverage >= 0.75, matched >= min(2, q.count), Self.linkHas(r, short) else { continue }
                // a Reserva and a Gran Reserva (or a Grand Cru and a plain village wine) are different wines, whatever the price
                let qTier = q.intersection(Self.tierWords), rTier = r.tokens.intersection(Self.tierWords)
                if qTier.isEmpty ? !rTier.isDisjoint(with: Self.topTierWords) : qTier != rTier { continue }
                // a white and a red of the same name are different wines: never take the other color's price
                if wineColor != 0, r.color != 0, r.color != wineColor { continue }
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

    /// Whether the list knows this producer: every real word of its name (not Château/Domaine…, not places) is a word the list's
    /// producers use. A misread name ("Nâteau") is unknown; so is a small producer the list doesn't carry (then the photo decides).
    /// Before the list has been downloaded every producer counts as known.
    func knowsProducer(_ producer: String) -> Bool {
        loadIfNeeded()
        guard !rows.isEmpty else { return true }
        let words = PriceBook.tokens(producer).subtracting(LabelMatcher.generic).subtracting(LabelMatcher.noise)
        return !words.isEmpty && labels.knowsMaker(words)
    }

    /// The wine a label names, found in the list from the label's text alone (no Claude call), with what the list knows about it.
    /// nil when the list does not have it or the label could be two of its wines.
    func wine(fromLabel lines: [String]) -> WineIdentity? {
        loadIfNeeded()
        guard !rows.isEmpty, let m = labels.match(lines: lines) else { return nil }
        return identity(of: m, lines: lines)
    }

    /// Up to 10 wines of the list this label might be (sent to Claude as a help, never as the answer).
    func shortlist(lines: [String]) -> [LabelMatcher.Wine] {
        loadIfNeeded()
        return rows.isEmpty ? [] : labels.shortlist(lines: lines)
    }

    /// The shortlisted wine Claude picked, if the label supports it (else nil: Claude's own answer stands).
    func wine(fromPick m: LabelMatcher.Wine, lines: [String]) -> WineIdentity? {
        guard labels.supports(m, lines: lines) else { return nil }
        return identity(of: m, lines: lines)
    }

    private func identity(of m: LabelMatcher.Wine, lines: [String]) -> WineIdentity {
        var w = WineIdentity.empty
        w.found = true; w.confidence = "high"; w.fromDatabase = true
        w.producer = m.maker
        w.name = LabelMatcher.displayName(m)
        w.vintage = LabelMatcher.vintage(lines)
        let r = rows[Int(m.row)]
        if let d = r.detail {
            if !d.country.isEmpty { w.country = d.country }
            let place = [d.appellation, d.region].filter { !$0.isEmpty }
            if !place.isEmpty { w.region = place.count == 2 && !place[0].localizedCaseInsensitiveContains(place[1]) ? place.joined(separator: ", ") : place[0] }
            w.grapes = d.grapes; w.grapePercent = d.percents.count == d.grapes.count && !d.grapes.isEmpty ? d.percents : nil
            w.tastingNotes = Array(d.aromas.prefix(6))
            switch d.colour { case "r": w.style = "red"; case "w": w.style = "white"; case "p": w.style = "rose"; case "s": w.style = "sparkling"
                              case "o": w.style = "orange"; case "f": w.style = "fortified"; case "d": w.style = "sweet"; default: break }
        }
        if w.style.isEmpty { w.style = ["", "red", "white", "rose"][Int(r.color)] }
        // a better-matching row of the same wine (its vintage, its critic scores) when there is one
        let o = overlay(w)
        if o.fromDatabase == true { w.dbScore = o.dbScore; w.dbScoreLink = o.dbScoreLink; w.dbCritics = o.dbCritics; w.dbCriticLinks = o.dbCriticLinks }
        // without grapes it is not settled: the usual check runs after it is shown
        if w.grapes.isEmpty { w.fromDatabase = nil }
        return w
    }
}
