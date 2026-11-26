import Foundation

/// Names a wine from its label text alone by finding it in our wine list, before any Claude call (scanning "option 3").
/// Tested on real scans (tools/label_match_test.py): 7 of 32 labels found from an 8-word signature, no wrong pick.
///
/// A list wine is (producer words, its own name's words, its place's words). It matches a label when
/// - more than half of the producer's words are on the label (place words and Château/Bodegas… do not count),
/// - every word of its own name is on the label (shop extras such as Magnum, Trento DOC or (Italy) are not required; colour and
///   tier words are: Maximum Rosé is not Maximum Blanc de Blancs),
/// - a name made only of common words (Grand, Réserve, Vieilles Vignes…) also has its appellation on the label.
/// The most specific wine wins; another wine that fits just as well means the label cannot tell them apart -> nil (Claude decides).
/// A label word one letter off a list word (OCR slips: "Haltett" for Hallett) counts, for words of 6+ letters, when only one word fits.
struct LabelMatcher {
    struct Wine { let producer: Set<String>; let own: Set<String>; let place: Set<String>; let name: String; let maker: String
                  /// the list row it came from (its details: grapes, region, aromas…)
                  let row: Int32 }

    private(set) var wines: [Wine] = []
    private var index: [String: [Int32]] = [:]     // own-name word -> wines
    private var words = Set<String>()              // every word the list knows (for OCR slips)
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
        let p = Self.core(producer, drop: placeWords, generic: Self.generic)
        let own = Self.core(name, drop: PriceBook.tokens(producer).union(placeWords), generic: Self.nameGeneric)
        guard !p.isEmpty, !own.isEmpty else { return }
        let key = p.sorted().joined(separator: " ") + "|" + own.sorted().joined(separator: " ") + "|" + appWords.sorted().joined(separator: " ")
        guard seen.insert(key).inserted else { return }
        let i = Int32(wines.count)
        wines.append(Wine(producer: p, own: own, place: appWords, name: name, maker: producer, row: row))
        for w in own { index[w, default: []].append(i) }
        words.formUnion(own); words.formUnion(p)
    }

    /// The wine this label names, or nil when it is not in the list or the label cannot tell two wines apart.
    func match(lines: [String]) -> Wine? {
        var label = PriceBook.tokens(lines.joined(separator: " "))
        label.formUnion(corrections(label))
        var cands: [Int32] = []
        var looked = Set<Int32>()
        for w in label {
            for i in index[w] ?? [] where looked.insert(i).inserted {
                let x = wines[Int(i)]
                guard x.own.isSubset(of: label), 2 * x.producer.intersection(label).count > x.producer.count else { continue }
                if x.own.isSubset(of: Self.weak) && !(!x.place.isEmpty && x.place.isSubset(of: label)) { continue }
                cands.append(i)
            }
        }
        func score(_ x: Wine) -> Int { x.own.count + x.place.intersection(label).count }
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

    /// The vintage printed on the label: a year between 1900 and next year, standing on its own (not part of a longer number).
    static func vintage(_ lines: [String]) -> String {
        let next = Calendar.current.component(.year, from: Date()) + 1
        for l in lines {
            var run = ""
            for ch in l + " " {
                if ch.isASCII && ch.isNumber { run.append(ch); continue }
                if run.count == 4, let y = Int(run), y >= 1900, y <= next { return run }
                run = ""
            }
        }
        return ""
    }
}
