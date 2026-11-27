import Foundation

/// Names a wine from its label text alone by finding it in our wine list, before any Claude call (scanning "option 3").
/// Tested on real scans (tools/label_match_test.py): 7 of 32 labels found from an 8-word signature, no wrong pick.
///
/// A list wine is (producer words, its own name's words, its place's words). It matches a label when
/// - more than half of the producer's words are on the label (place words and Château/Bodegas… do not count),
/// - every word of its own name is on the label (shop extras such as Magnum, Trento DOC or (Italy) are not required; colour and
///   tier words are: Maximum Rosé is not Maximum Blanc de Blancs),
/// - a name made only of common words (Grand, Réserve, Vieilles Vignes…) also has its appellation on the label;
///   words of the "bottled by" line count for the producer only (it names places: Guigal's Château d'Ampuis); a wine named only by producer
///   and appellation ("Guigal Côtes du Rhône") takes the appellation as its name.
/// The most specific wine wins; another wine that fits just as well means the label cannot tell them apart -> nil (Claude decides).
/// A label word one letter off a list word (OCR slips: "Haltett" for Hallett) counts, for words of 6+ letters, when only one word fits.
struct LabelMatcher {
    struct Wine { let producer: Set<String>; let own: Set<String>; let place: Set<String>; let name: String; let maker: String
                  /// the list row it came from (its details: grapes, region, aromas…)
                  let row: Int32
                  /// the producer's name is only its place ("Château Margaux" in Margaux): a weaker clue, since every label of
                  /// that appellation prints the word
                  var placeNamed = false }

    private(set) var wines: [Wine] = []
    private var index: [String: [Int32]] = [:]     // own-name word -> wines
    private var words = Set<String>()              // every word the list knows (for OCR slips)
    private var makerWords = Set<String>()         // the words of the list's producers' names
    private var seen = Set<String>()

    static let generic: Set<String> = ["chateau", "bodega", "bodegas", "weingut", "tenuta", "cantina", "estate", "winery", "vineyard",
        "vineyards", "cellars", "family", "maison", "casa", "vina", "vino", "vins", "wines", "red", "white", "rose", "rosso", "bianco",
        "rouge", "blanc", "tinto", "blanco", "reserve", "reserva", "riserva", "grand", "vin", "france", "italy", "spain", "doc", "docg",
        "aoc", "igt", "appellation", "controlee", "origine", "protegee", "denominazione", "product", "produit", "bottled", "san", "the"]
    static let nameGeneric: Set<String> = ["chateau", "bodega", "bodegas", "weingut", "tenuta", "cantina", "estate", "winery", "vineyard",
        "vineyards", "cellars", "family", "maison", "casa", "vina", "vino", "vins", "wines", "vin", "appellation", "controlee",
        "origine", "protegee", "denominazione", "product", "produit", "bottled", "the"]
    static let noise: Set<String> = ["magnum", "jeroboam", "half", "bottle", "bottles", "case", "gift", "box", "astuccio", "cassetta",
        "legno", "coffret", "etui", "italy", "france", "spain", "portugal", "germany", "austria", "usa", "california", "australia",
        "zealand", "chile", "argentina", "africa", "south", "lebanon", "greece", "hungary", "limited", "edition", "doc", "docg", "aoc",
        "aop", "igt", "igp", "dop", "freres", "fils", "pere", "sons", "brothers", "750ml", "375ml", "1500ml", "150cl", "75cl", "red", "wine"]
    /// Phrases of the "bottled by" line, in the label languages we meet most.
    static let bottler = ["mis en bouteille", "mise en bouteille", "bottled by", "bottled at", "produced and bottled", "imbottigliato",
                          "embotellado", "abgefullt", "erzeugerabfullung", "engarrafado", "eleve et mis", "elabore et mis",
                          "proprietaire a", "negociant a", "produced by", "prodotto da", "elaborado por"]
    static let weak: Set<String> = ["grand", "reserve", "reserva", "riserva", "vieilles", "vignes", "rouge", "blanc", "blancs", "rose",
        "rosso", "bianco", "tinto", "blanco", "brut", "classico", "superiore", "selection", "special", "cuvee", "premier", "villages",
        "crianza", "estate", "old", "vines", "red", "white", "dry", "sec", "cru"]

    private static func core(_ s: String, drop: Set<String> = [], generic: Set<String>) -> Set<String> {
        PriceBook.tokens(s).filter { !generic.contains($0) && !noise.contains($0) && !drop.contains($0) }
    }

    /// One row of the list (rows of the same wine in other vintages or sizes are added once).
    /// `place`: region and appellation (left out of the name and producer words); `appellation`: the words a label of this wine prints.
    mutating func add(name: String, producer: String, place: String, appellation: String = "", row: Int32 = 0) {
        let placeWords = PriceBook.tokens(place)
        let appWords = PriceBook.tokens(appellation.isEmpty ? place : appellation).subtracting(Self.generic)
        var p = Self.core(producer, drop: placeWords, generic: Self.generic)
        // "Château Margaux" in Margaux: without its place the producer has no word left, so the place word is its name
        let placeNamed = p.isEmpty
        if placeNamed { p = Self.core(producer, generic: Self.generic) }
        var own = Self.core(name, drop: PriceBook.tokens(producer).union(placeWords), generic: Self.nameGeneric)
        // "Guigal Côtes du Rhône": a wine named only by its producer and appellation — the appellation is its name
        if own.isEmpty { own = appWords }
        guard !p.isEmpty, !own.isEmpty else { return }
        let key = p.sorted().joined(separator: " ") + "|" + own.sorted().joined(separator: " ") + "|" + appWords.sorted().joined(separator: " ")
        guard seen.insert(key).inserted else { return }
        let i = Int32(wines.count)
        wines.append(Wine(producer: p, own: own, place: appWords, name: name, maker: producer, row: row, placeNamed: placeNamed))
        for w in own { index[w, default: []].append(i) }
        words.formUnion(own); words.formUnion(p)
        if !placeNamed { makerWords.formUnion(p) }
    }

    /// The label's words, as `match` reads them (the "bottled by" line apart; one-letter OCR slips corrected).
    private func labelWords(_ lines: [String]) -> (name: Set<String>, producer: Set<String>) {
        let small = lines.filter { l in Self.bottler.contains { l.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().contains($0) } }
        var label = PriceBook.tokens(lines.filter { !small.contains($0) }.joined(separator: " "))
        label.formUnion(corrections(label))
        return (label, label.union(PriceBook.tokens(small.joined(separator: " "))))
    }

    /// The wines this label might be, best first (at most `limit`): a word of their own name on the label, plus their producer
    /// or another name word or their appellation. Only a help for Claude, so looser than `match`; empty when nothing fits well.
    func shortlist(lines: [String], limit: Int = 10) -> [Wine] {
        let (label, producerWords) = labelWords(lines)
        var score: [Int32: Double] = [:]
        for w in label where !Self.weak.contains(w) {
            for i in index[w] ?? [] where score[i] == nil {
                let x = wines[Int(i)]
                let own = Double(x.own.intersection(label).count)
                let prod = Double(x.producer.intersection(producerWords).count)
                let place = Double(x.place.intersection(label).count)
                // the share of its own name that is printed matters more than its length
                let s = own / Double(max(1, x.own.count)) * 2 + prod + place * 0.5 - Double(x.own.subtracting(label).count) * 0.5
                if own >= 1 && (prod >= 1 || own >= 2 || place >= 1) && s >= 2 { score[i] = s }
            }
        }
        // one entry per wine (the same producer + name in other vintages or sizes are one)
        var seen = Set<String>()
        var out: [Wine] = []
        for (i, _) in score.sorted(by: { $0.value > $1.value }) {
            let x = wines[Int(i)]
            if seen.insert(x.maker.lowercased() + "|" + x.own.sorted().joined()).inserted { out.append(x) }
            if out.count == limit { break }
        }
        return out
    }

    /// Whether the label supports this wine (for Claude's pick from the shortlist): all of its own name printed, or its producer
    /// and part of its name.
    func supports(_ x: Wine, lines: [String]) -> Bool {
        let (label, producerWords) = labelWords(lines)
        guard !x.own.intersection(label).isEmpty else { return false }
        return x.own.isSubset(of: label) || !x.producer.isDisjoint(with: producerWords)
    }

    /// True when every word is one the list's wines use (producers and names).
    func knows(_ ws: Set<String>) -> Bool { ws.isSubset(of: words) }
    /// True when every word is a word of a producer's name in the list ("El Cuyo": "cuyo" is a place, not a producer).
    func knowsMaker(_ ws: Set<String>) -> Bool { ws.isSubset(of: makerWords) }

    /// The wine this label names, or nil when it is not in the list or the label cannot tell two wines apart.
    func match(lines: [String]) -> Wine? {
        // the "bottled by" line names the producer's address ("mis en bouteille par E. Guigal, Château d'Ampuis"): its words may
        // confirm the producer but never a wine's own name (Château d'Ampuis is also the name of Guigal's Côte-Rôtie)
        let small = lines.filter { l in Self.bottler.contains { l.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().contains($0) } }
        var label = PriceBook.tokens(lines.filter { !small.contains($0) }.joined(separator: " "))
        label.formUnion(corrections(label))
        let producerWords = label.union(PriceBook.tokens(small.joined(separator: " ")))
        var cands: [Int32] = []
        var looked = Set<Int32>()
        for w in label {
            for i in index[w] ?? [] where looked.insert(i).inserted {
                let x = wines[Int(i)]
                guard x.own.isSubset(of: label), 2 * x.producer.intersection(producerWords).count > x.producer.count else { continue }
                if x.own.isSubset(of: Self.weak) && !(!x.place.isEmpty && x.place.isSubset(of: label)) { continue }
                cands.append(i)
            }
        }
        // A tier word misread by the camera ("RESENE" for RESERVE on Trivento Golden Reserve): when nothing matched in full, a wine
        // whose own name WITHOUT its common words (reserve, grand…) is printed, with its producer, still counts; never a tie.
        if cands.isEmpty {
            for w in label where !Self.weak.contains(w) {
                for i in index[w] ?? [] where !cands.contains(i) {
                    let x = wines[Int(i)]
                    let strong = x.own.subtracting(Self.weak)
                    guard !strong.isEmpty, strong != x.own, strong.isSubset(of: label),
                          2 * x.producer.intersection(producerWords).count > x.producer.count else { continue }
                    cands.append(i)
                }
            }
        }
        // Some labels never print the producer (Rayas's "La Pialade" says only La Pialade, Côtes du Rhône): when no producer was
        // found, a wine whose own name is a rare word that only ONE producer in the list uses, with its appellation on the label,
        // is that producer's wine.
        if cands.isEmpty {
            for w in label where w.count >= 5 && !Self.weak.contains(w) {
                guard let ids = index[w], Set(ids.map { wines[Int($0)].producer }).count == 1 else { continue }
                for i in ids {
                    let x = wines[Int(i)]
                    guard x.own.isSubset(of: label), !x.own.isSubset(of: Self.weak), x.own != x.place,
                          !x.place.isEmpty, x.place.isSubset(of: label) else { continue }
                    if !cands.contains(i) { cands.append(i) }
                }
            }
        }
        // a wine named only by its appellation counts its words once, so a named cuvée of the same place (La Landonne) beats it
        // a Château Palmer label prints "Margaux" too: a producer named only by its place never beats one named by its own words
        if cands.contains(where: { !wines[Int($0)].placeNamed }) { cands.removeAll { wines[Int($0)].placeNamed } }
        func score(_ x: Wine) -> Int { x.own == x.place ? x.own.count : x.own.count + x.place.intersection(label).count }
        let sorted = cands.map { wines[Int($0)] }.sorted {
            (score($0), $0.producer.intersection(label).count, -$0.producer.subtracting(label).count)
                > (score($1), $1.producer.intersection(label).count, -$1.producer.subtracting(label).count)
        }
        guard let best = sorted.first else { return nil }
        let rival = sorted.dropFirst().contains { score($0) == score(best) && ($0.own != best.own || $0.place.intersection(label) != best.place.intersection(label)) }
        return rival ? nil : best
    }

    /// For each 6+ letter label word the list does not know: the one list word a single letter away (changed, added or missing).
    private func corrections(_ label: Set<String>) -> Set<String> {
        var out = Set<String>()
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        for w in label where w.count >= 6 && !words.contains(w) && w.allSatisfy({ $0.isLetter }) {
            let a = Array(w)
            var found = Set<String>()
            for i in 0...a.count {
                if i < a.count {
                    var d = a; d.remove(at: i)
                    let s = String(d); if words.contains(s) { found.insert(s) }
                }
                for c in letters {
                    var ins = a; ins.insert(c, at: i)
                    let s = String(ins); if words.contains(s) { found.insert(s) }
                    if i < a.count, a[i] != c {
                        var sub = a; sub[i] = c
                        let s2 = String(sub); if words.contains(s2) { found.insert(s2) }
                    }
                }
                if found.count > 1 { break }
            }
            if found.count == 1 { out.formUnion(found) }
        }
        return out
    }

    /// The wine's name as a person would write it: the quoted part when the shop quotes it, without the producer, packaging,
    /// country or brackets ("Bread & Butter - Chardonnay - California" -> "Chardonnay").
    static func displayName(_ w: Wine) -> String {
        var s = w.name
        if let q = s.range(of: "\"[^\"]+\"", options: .regularExpression) { s = String(s[q]).replacingOccurrences(of: "\"", with: "") }
        s = s.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        if !w.maker.isEmpty { s = s.replacingOccurrences(of: w.maker, with: " ", options: [.caseInsensitive, .diacriticInsensitive]) }
        let parts = s.components(separatedBy: CharacterSet(charactersIn: ",:–—")).flatMap { $0.components(separatedBy: " - ") }
        let kept = parts.map { p -> String in
            p.split(separator: " ").filter { word in
                let t = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().filter { $0.isLetter || $0.isNumber }
                return !(noise.contains(t) || w.producer.contains(t))
            }.joined(separator: " ")
        }.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -'\u{2019}")) }
         .filter { part in !PriceBook.tokens(part).isDisjoint(with: w.own) }
        let out = kept.joined(separator: " ").replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        return out.isEmpty ? w.name : out
    }

    /// The vintage printed on the label: the LATEST year between 1900 and next year standing on its own ("Since 1928 … 2022" is 2022;
    /// a founding year is always older than the wine).
    static func vintage(_ lines: [String]) -> String {
        let next = Calendar.current.component(.year, from: Date()) + 1
        var best = 0
        for l in lines {
            var run = ""
            for ch in l + " " {
                if ch.isASCII && ch.isNumber { run.append(ch); continue }
                if run.count == 4, let y = Int(run), y >= 1900, y <= next { best = max(best, y) }
                run = ""
            }
        }
        return best > 0 ? String(best) : ""
    }
}
