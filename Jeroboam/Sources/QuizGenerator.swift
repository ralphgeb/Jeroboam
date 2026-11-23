import Foundation

/// Builds practice sessions from the library (endless, generated questions) and from past mistakes.
/// About thirty question templates draw on every part of the library; recently asked questions are remembered
/// so the same ones don't keep coming back.
enum QuizGenerator {
    static var content: ContentStore { .shared }

    enum Kind: String, CaseIterable, Identifiable {
        case mixed, grapes, regions, maps, colors, aromas, terms
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mixed: return "Daily mix"
            case .grapes: return "Grape varieties"
            case .regions: return "Regions & countries"
            case .maps: return "Map reading"
            case .colors: return "Wine colors"
            case .aromas: return "Aromas & tasting"
            case .terms: return "Styles, labels & vocabulary"
            }
        }
        var subtitle: String {
            switch self {
            case .mixed: return "A bit of everything"
            case .grapes: return "Profiles, aromas, synonyms and food"
            case .regions: return "Countries, appellations and their grapes"
            case .maps: return "Spot regions on the map"
            case .colors: return "Name the color in the glass"
            case .aromas: return "Primary, secondary and tertiary notes"
            case .terms: return "How wines are made, read and served"
            }
        }
        var icon: String {
            switch self {
            case .mixed: return "shuffle"
            case .grapes: return "leaf"
            case .regions: return "globe.europe.africa"
            case .maps: return "map"
            case .colors: return "drop"
            case .aromas: return "nose"
            case .terms: return "text.book.closed"
            }
        }
    }

    // MARK: Sessions

    static func session(_ kind: Kind, count: Int = 10, maxLevel: Int = 5) -> Session {
        var cards: [Card] = []
        var keys: [String] = []
        let recent = Set(QuizMemory.recent)
        var tries = 0
        while cards.count < count && tries < count * 14 {
            tries += 1
            let k: Kind = kind == .mixed ? [.grapes, .grapes, .regions, .regions, .colors, .aromas, .terms, .terms].randomElement()! : kind
            guard let (key, c) = make(k, maxLevel: maxLevel) else { continue }
            // avoid repeats within the session, and recent ones while there is plenty else to ask
            if keys.contains(key) || cards.contains(where: { $0.question == c.question }) { continue }
            if recent.contains(key) && tries < count * 10 { continue }
            keys.append(key)
            cards.append(c)
        }
        // Daily mix also revisits questions from finished lessons.
        if kind == .mixed {
            let done = content.orderedLessons.filter { lessonCompleted($0.id) }
            let pool = done.flatMap { $0.cards.filter(\.isQuestion) }.filter { !recent.contains("lesson:" + $0.id) }.shuffled().prefix(3)
            keys += pool.map { "lesson:" + $0.id }
            cards = Array(cards.prefix(count - pool.count)) + pool
            cards.shuffle()
        }
        QuizMemory.remember(keys)
        return Session(title: kind.title, lessonID: nil, cards: cards)
    }

    /// A mock exam for one level: questions from that level's lessons plus generated ones, 30 in all.
    /// `version` 1...4 gives four different exams (20 lesson questions each, none shared between versions, plus 10 freshly generated
    /// ones that change every time: 120 questions in all); version 0 is a random mix.
    static func exam(level: Int, count: Int = 30, version: Int = 0) -> Session {
        let lessons = content.course.levels.first { $0.number == level }?.courseUnits.flatMap(\.lessons) ?? []
        let pool = lessons.flatMap { $0.cards.filter(\.isQuestion) }
        let lessonQs: [Card]
        if version >= 1, pool.count >= 20 {
            // one fixed shuffle per level, cut into slices so the versions never share a question
            var rng = ExamShuffleRNG(seed: UInt64(level) &* 7919 &+ 17)
            let fixed = pool.sorted { $0.id < $1.id }.shuffled(using: &rng)
            let per = 20
            let start = ((version - 1) * per) % max(per, fixed.count)
            lessonQs = (0..<per).map { fixed[(start + $0) % fixed.count] }
        } else {
            lessonQs = Array(pool.shuffled().prefix(count * 2 / 3))
        }
        let generated = session(.mixed, count: count - lessonQs.count, maxLevel: level).cards
        let cards = (lessonQs + generated).shuffled()
        return Session(title: version == 0 ? "Level \(level) mock exam" : "Level \(level) mock exam · version \(version)", lessonID: nil, cards: cards)
    }

    static func mistakes(_ ids: [String]) -> Session {
        var byID: [String: Card] = [:]
        for l in content.orderedLessons { for c in l.cards { byID[c.id] = c } }
        let cards = ids.reversed().compactMap { byID[$0] }.prefix(12)
        return Session(title: "Review mistakes", lessonID: nil, cards: Array(cards))
    }

    static var lessonCompleted: (String) -> Bool = { _ in false }

    // MARK: Card helpers

    private static func uid() -> String { "gen-" + UUID().uuidString }

    private static func choice(_ q: String, correct: String, wrong: [String], explain: String?, visual: String? = nil) -> Card? {
        let pool = Array(Set(wrong.filter { $0 != correct && !$0.isEmpty }))
        let wrongs = pool.shuffled().prefix(3)
        guard wrongs.count >= 2 else { return nil }
        var opts = Array(wrongs)
        let pos = Int.random(in: 0...opts.count)
        opts.insert(correct, at: pos)
        return Card(id: uid(), kind: .choice, question: q, options: opts, answer: pos, explain: explain, visual: visual)
    }

    private static func tf(_ q: String, _ truth: Bool, explain: String?, visual: String? = nil) -> Card {
        Card(id: uid(), kind: .tf, question: q, truth: truth, explain: explain, visual: visual)
    }

    private static func blank(_ sentence: String, answer: String, distractors: [String], explain: String?) -> Card? {
        let d = Array(Set(distractors.filter { $0.lowercased() != answer.lowercased() })).shuffled().prefix(3)
        guard d.count >= 2, sentence.contains("___") else { return nil }
        return Card(id: uid(), kind: .blank, question: sentence, options: Array(d), answers: [answer], explain: explain)
    }

    private static func match(_ q: String, _ pairs: [[String]]) -> Card? {
        let lefts = Set(pairs.map { $0[0] }), rights = Set(pairs.map { $0[1] })
        guard pairs.count >= 3, lefts.count == pairs.count, rights.count == pairs.count, lefts.isDisjoint(with: rights) else { return nil }
        return Card(id: uid(), kind: .match, question: q, pairs: pairs)
    }

    private static func plain(_ s: String) -> String { s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "") }

    private static func level(_ v: Int) -> String {
        switch v { case ...1: return "low"; case 2: return "medium-low"; case 3: return "medium"; case 4: return "medium-high"; default: return "high" }
    }

    // MARK: Templates

    /// Returns a stable key (template + subject, for the repeat memory) and the card.
    private static func make(_ kind: Kind, maxLevel: Int) -> (String, Card)? {
        let lib = content.library
        let grapes = lib.grapes.filter { $0.level <= maxLevel }
        let regions = lib.regions.filter { $0.level <= maxLevel && $0.kind != "country" }
        func k(_ t: String, _ id: String) -> String { t + ":" + id }

        switch kind {
        case .grapes:
            guard let g = grapes.randomElement() else { return nil }
            let same = grapes.filter { $0.berry == g.berry && $0.id != g.id }
            switch Int.random(in: 0..<12) {
            case 0:
                let notes = g.aromas.prefix(3).joined(separator: ", ").lowercased()
                return choice("Which grape is often described with aromas of **\(notes)**?", correct: g.name,
                              wrong: same.map(\.name), explain: g.summary).map { (k("aromas", g.id), $0) }
            case 1:
                guard let r = content.regions(forGrape: g).randomElement() else { return nil }
                let others = same.filter { !$0.regions.contains(r.id) }.map(\.name)
                return choice("Which grape is a key variety in **\(r.name)**?", correct: g.name, wrong: others,
                              explain: "\(r.name): \(plain(r.summary))").map { (k("regiongrape", g.id + r.id), $0) }
            case 2:
                let truth = Bool.random()
                let said: String = truth ? (g.berry == .white ? "white" : "black") : (g.berry == .white ? "black" : "white")
                return (k("berry", g.id), tf("\(g.name) is a \(said) grape.", truth,
                                            explain: "\(g.name) is a \(g.berry == .white ? "white" : (g.berry == .pink ? "pink-skinned" : "black")) grape. \(plain(g.summary))"))
            case 3:
                return choice("Where does **\(g.name)** come from originally?", correct: g.origin,
                              wrong: grapes.map(\.origin), explain: g.fact ?? g.summary).map { (k("origin", g.id), $0) }
            case 4:
                // which aroma is typical
                guard let a = g.aromas.randomElement() else { return nil }
                let foreign = Set(grapes.filter { $0.berry != g.berry }.flatMap(\.aromas)).subtracting(g.aromas)
                return choice("Which aroma would you expect in a glass of **\(g.name)**?", correct: a, wrong: Array(foreign),
                              explain: "\(g.name) typically shows \(g.aromas.prefix(4).joined(separator: ", ").lowercased()).")
                    .map { (k("typical", g.id + a), $0) }
            case 5:
                // odd one out
                let foreign = Set(grapes.filter { $0.berry != g.berry }.flatMap(\.aromas)).subtracting(g.aromas)
                guard let odd = foreign.randomElement(), g.aromas.count >= 3 else { return nil }
                let opts = Array(g.aromas.shuffled().prefix(3))
                var all = opts; let pos = Int.random(in: 0...3); all.insert(odd, at: pos)
                return (k("notaroma", g.id), Card(id: uid(), kind: .choice, question: "Which aroma is **not** typical of \(g.name)?",
                                                   options: all, answer: pos,
                                                   explain: "\(g.name): \(g.aromas.joined(separator: ", ").lowercased()). \(odd) points elsewhere."))
            case 6:
                // structure: who has the most …
                let traits: [(String, (Grape) -> Int)] = g.berry == .black
                    ? [("tannin", { $0.tannin }), ("body", { $0.body }), ("acidity", { $0.acidity }), ("alcohol", { $0.alcohol })]
                    : [("acidity", { $0.acidity }), ("body", { $0.body }), ("alcohol", { $0.alcohol })]
                let (name, f) = traits.randomElement()!
                let pool = same + [g]
                guard let top = pool.filter({ f($0) == 5 || f($0) == 4 }).randomElement() else { return nil }
                let lows = pool.filter { f($0) <= f(top) - 2 }.map(\.name)
                return choice("Which of these grapes typically has the **highest \(name)**?", correct: top.name, wrong: lows,
                              explain: "\(top.name) usually shows \(level(f(top))) \(name). \(plain(top.summary))")
                    .map { (k("most" + name, top.id), $0) }
            case 7:
                // structure true/false
                let traits: [(String, Int)] = [("acidity", g.acidity), ("body", g.body), ("tannin", g.tannin)].filter { g.berry == .black || $0.0 != "tannin" }
                let (name, v) = traits.randomElement()!
                guard v != 3 else { return nil }
                let truth = Bool.random()
                let claim = truth == (v >= 4) ? "high" : "low"
                return (k("struct" + name, g.id), tf("\(g.name) is usually known for **\(claim) \(name)**.", truth,
                                                     explain: "\(g.name) typically has \(level(v)) \(name). \(plain(g.summary))"))
            case 8:
                guard let aka = g.aka?.randomElement() else { return nil }
                if Bool.random() {
                    return choice("**\(aka)** is another name for…", correct: g.name, wrong: same.map(\.name),
                                  explain: "\(g.name) is also called \(g.aka!.joined(separator: ", ")).").map { (k("aka", g.id), $0) }
                }
                return blank("In some countries \(g.name) is called ___.", answer: aka,
                             distractors: grapes.filter { $0.id != g.id }.compactMap { $0.aka?.first },
                             explain: "\(g.name) is also called \(g.aka!.joined(separator: ", ")).").map { (k("akab", g.id), $0) }
            case 9:
                guard let food = g.food.randomElement() else { return nil }
                let others = grapes.filter { $0.berry != g.berry }.flatMap(\.food)
                return choice("Which dish is a classic match for **\(g.name)**?", correct: food, wrong: Array(Set(others).subtracting(g.food)),
                              explain: "\(g.name) works with \(g.food.joined(separator: ", ").lowercased()).").map { (k("food", g.id + food), $0) }
            case 10:
                let rs = content.regions(forGrape: g)
                guard let r = rs.randomElement() else { return nil }
                let others = regions.filter { !g.regions.contains($0.id) && !$0.grapes.contains(g.id) }.map(\.name)
                return choice("Where would you find a lot of **\(g.name)**?", correct: r.name, wrong: others,
                              explain: "\(r.name): \(plain(r.summary))" + (rs.count > 1 ? " \(g.name) also thrives in \(rs.filter { $0.id != r.id }.prefix(3).map(\.name).joined(separator: ", "))." : "")).map { (k("whereg", g.id), $0) }
            default:
                // match grapes to a signature region
                let picks = grapes.filter { !content.regions(forGrape: $0).isEmpty }.shuffled().prefix(8)
                var pairs: [[String]] = []
                var used = Set<String>()
                for p in picks where pairs.count < 4 {
                    if let r = content.regions(forGrape: p).first(where: { !used.contains($0.name) }) {
                        used.insert(r.name); pairs.append([p.name, r.name])
                    }
                }
                return match("Match each grape to a region famous for it", pairs).map { (k("matchgr", pairs.map { $0[0] }.joined()), $0) }
            }

        case .regions:
            guard let r = regions.randomElement() else { return nil }
            let countries = Set(lib.regions.filter { $0.kind == "country" }.map(\.name))
            switch Int.random(in: 0..<7) {
            case 0:
                return choice("**\(r.name)** is a wine region in…", correct: r.country, wrong: Array(countries),
                              explain: "\(r.name) is in \(r.country). \(plain(r.summary))").map { (k("country", r.id), $0) }
            case 1:
                guard let gid = r.grapes.first, let g = content.grape(gid) else { return nil }
                return choice("Which grape is most associated with **\(r.name)**?", correct: g.name,
                              wrong: grapes.filter { !r.grapes.contains($0.id) && $0.berry == g.berry }.map(\.name),
                              explain: "\(g.name) and \(r.name): \(plain(r.summary))").map { (k("regiongr", r.id), $0) }
            case 2:
                // parent region
                guard let parent = lib.regions.first(where: { $0.kind != "country" && ($0.sub ?? []).contains(r.id) }) else { return nil }
                let others = lib.regions.filter { $0.kind != "country" && ($0.sub?.isEmpty == false) && $0.id != parent.id }.map(\.name)
                return choice("**\(r.name)** lies within which larger region?", correct: parent.name, wrong: others,
                              explain: "\(r.name) is part of \(parent.name). \(plain(parent.summary))").map { (k("parent", r.id), $0) }
            case 3:
                // fact with a bolded term → fill in the blank
                guard let fact = (r.facts ?? []).filter({ $0.components(separatedBy: "**").count == 3 }).randomElement() else { return nil }
                let parts = fact.components(separatedBy: "**")
                let answer = parts[1]
                guard answer.count <= 28 else { return nil }
                let others = lib.regions.flatMap { $0.facts ?? [] }.compactMap { f -> String? in
                    let p = f.components(separatedBy: "**"); return p.count >= 3 && p[1].count <= 28 ? p[1] : nil
                }
                return blank(plain(parts[0]) + "___" + plain(parts[2]), answer: answer, distractors: others,
                             explain: "\(r.name): \(plain(fact))").map { (k("fact", r.id + answer), $0) }
            case 4:
                // match regions to countries
                var pairs: [[String]] = []
                var usedC = Set<String>()
                for x in regions.shuffled() where pairs.count < 4 && !usedC.contains(x.country) {
                    usedC.insert(x.country); pairs.append([x.name, x.country])
                }
                return match("Match each region to its country", pairs).map { (k("matchrc", pairs.map { $0[0] }.joined()), $0) }
            case 5:
                guard let cl = r.climate else { return nil }
                let others = regions.filter { $0.id != r.id && $0.climate != nil && $0.country != r.country }.compactMap(\.climate)
                return choice("Which climate describes **\(r.name)**?", correct: plain(cl), wrong: others.map(plain),
                              explain: "\(r.name): \(plain(r.summary))").map { (k("climate", r.id), $0) }
            default:
                // country classification
                guard let c = lib.regions.filter({ $0.kind == "country" && $0.classification != nil }).randomElement(),
                      let cls = c.classification else { return nil }
                let others = lib.regions.filter { $0.kind == "country" && $0.id != c.id }.compactMap(\.classification)
                return choice("Which quality system belongs to **\(c.name)**?", correct: plain(cls), wrong: others.map(plain),
                              explain: "\(c.name): \(plain(cls)). \(plain(c.summary))").map { (k("class", c.id), $0) }
            }

        case .maps:
            let candidates = regions.filter { r in
                guard let m = r.map, let geo = MapGeometry.get(m) else { return false }
                return geo.areas.contains { $0.id == (r.highlight?.first ?? r.id) }
            }
            guard let r = candidates.randomElement(), let mapID = r.map, let geo = MapGeometry.get(mapID) else { return nil }
            let target = r.highlight?.first ?? r.id
            guard let area = geo.areas.first(where: { $0.id == target }) else { return nil }
            // one appellation kept on the map, everything else faded away: which one is it?
            if Int.random(in: 0..<3) == 0, let sub = geo.areas.filter({ $0.level >= 1 }).randomElement() {
                let sameLevel = geo.areas.filter { $0.id != sub.id && $0.level == sub.level }.map(\.name)
                let where_ = geo.map.title
                if let q = choice("Which appellation is the only one left on this map of \(where_)?", correct: sub.name, wrong: sameLevel,
                                  explain: "\(sub.name) in \(where_). Everything else on the map is faded out.", visual: "mapsolo:\(mapID):\(sub.id)") {
                    return (k("mapsolo", sub.id), q)
                }
            }
            if Bool.random() {
                let others = geo.areas.filter { $0.id != target && $0.level == area.level }.map(\.name)
                return choice("Which region is highlighted on this map?", correct: area.name, wrong: others,
                              explain: "\(area.name): \(plain(r.summary))", visual: "map:\(mapID):\(target)").map { (k("map", target), $0) }
            }
            // which grape grows in the highlighted area
            guard let gid = r.grapes.first, let g = content.grape(gid) else { return nil }
            return choice("The highlighted region is best known for which grape?", correct: g.name,
                          wrong: grapes.filter { !r.grapes.contains($0.id) }.map(\.name),
                          explain: "\(r.name): \(plain(r.summary))", visual: "map:\(mapID):\(target)").map { (k("mapgr", target), $0) }

        case .colors:
            let colors = lib.colors
            guard let c = colors.randomElement() else { return nil }
            switch Int.random(in: 0..<3) {
            case 0:
                return choice("Which color best describes this wine?", correct: c.name,
                              wrong: colors.filter { $0.family == c.family }.map(\.name), explain: c.note, visual: "glassonly:\(c.id)")
                    .map { (k("color", c.id), $0) }
            case 1:
                guard let ex = c.examples else { return nil }
                return choice("Which color would you expect from **\(ex.components(separatedBy: ",").first ?? ex)**?", correct: c.name,
                              wrong: colors.filter { $0.family == c.family && $0.id != c.id }.map(\.name), explain: c.note)
                    .map { (k("colorex", c.id), $0) }
            default:
                let fam = c.family == "rose" ? "rosé" : c.family
                return choice("**\(c.name)** is a color found in which kind of wine?", correct: fam.capitalized,
                              wrong: ["White", "Rosé", "Red"], explain: c.note).map { (k("colorfam", c.id), $0) }
            }

        case .aromas:
            let cats = content.allAromaCategories()
            guard let cat = cats.randomElement(), let item = cat.items.randomElement() else { return nil }
            switch Int.random(in: 0..<4) {
            case 0:
                guard let group = lib.aromas.first(where: { $0.categories.contains(cat) }) else { return nil }
                return choice("**\(item)** is classed as which type of aroma?", correct: group.name, wrong: lib.aromas.map(\.name),
                              explain: "\(item) belongs to **\(cat.name)**, a \(group.name.lowercased()) aroma. \(group.summary)")
                    .map { (k("aromatype", item), $0) }
            case 1:
                return choice("In the aroma lexicon, **\(item)** belongs to…", correct: cat.name,
                              wrong: cats.filter { $0.id != cat.id }.map(\.name),
                              explain: cat.note ?? "\(cat.name): \(cat.items.prefix(6).joined(separator: ", ")).").map { (k("aromacat", item), $0) }
            case 2:
                // which of these comes from oak / lees / age…
                let others = cats.filter { $0.id != cat.id }.flatMap(\.items)
                return choice("Which of these is a **\(cat.name.lowercased())** note?", correct: item, wrong: others,
                              explain: cat.note ?? "\(cat.name): \(cat.items.prefix(6).joined(separator: ", ")).").map { (k("aromaof", item), $0) }
            default:
                var pairs: [[String]] = []
                for c in cats.shuffled() where pairs.count < 4 {
                    if let it = c.items.randomElement() { pairs.append([it, c.name]) }
                }
                return match("Match each aroma to its family", pairs).map { (k("matcharoma", pairs.map { $0[0] }.joined()), $0) }
            }

        case .terms:
            // Styles and labels are taught from Level 2 on.
            switch Int.random(in: 0..<(maxLevel >= 2 ? 6 : 2)) {
            case 0, 1:
                let terms = lib.glossary.filter { ($0.level ?? 1) <= maxLevel }
                guard let t = terms.randomElement() else { return nil }
                let others = Array(terms.filter { $0.term != t.term }.shuffled().prefix(3))
                let contrast = others.map { "**\($0.term)**" }.joined(separator: ", ")
                if Bool.random() {
                    return choice("What does **\(t.term)** mean?", correct: t.def, wrong: others.map(\.def),
                                  explain: "**\(t.term)**: \(t.def) The other answers describe different terms: \(contrast).").map { (k("term", t.term), $0) }
                }
                return choice("Which term means: “\(t.def)”", correct: t.term, wrong: others.map(\.term),
                              explain: "**\(t.term)** means: \(t.def) Easy to mix up with \(contrast), which each mean something else.").map { (k("termr", t.term), $0) }
            case 2:
                guard let s = lib.styles.randomElement(), let ex = s.examples.randomElement() else { return nil }
                return choice("**\(ex)** is an example of which style?", correct: s.name,
                              wrong: lib.styles.filter { $0.category == s.category && $0.id != s.id }.map(\.name) + lib.styles.map(\.name),
                              explain: plain(s.summary)).map { (k("style", ex), $0) }
            case 3:
                guard let s = lib.styles.randomElement() else { return nil }
                return choice("How is **\(s.name)** made?", correct: plain(s.how), wrong: lib.styles.filter { $0.id != s.id }.map { plain($0.how) },
                              explain: plain(s.summary)).map { (k("stylehow", s.id), $0) }
            case 4:
                guard let p = lib.pairings.randomElement() else { return nil }
                return choice("What does **\(p.food.lowercased())** do to a wine?", correct: plain(p.effect),
                              wrong: lib.pairings.filter { $0.food != p.food }.map { plain($0.effect) },
                              explain: plain(p.tip)).map { (k("pair", p.food), $0) }
            default:
                guard let l = (lib.labels ?? []).randomElement(), let f = l.fields.filter({ $0.kind != "small" && $0.kind != "fine" }).randomElement() else { return nil }
                let others = (lib.labels ?? []).flatMap(\.fields).filter { $0.text != f.text }.map { plain($0.note) }
                return choice("On a \(l.title) label, what does “\(f.text)” tell you?", correct: plain(f.note), wrong: others,
                              explain: plain(l.summary)).map { (k("label", l.id + f.text), $0) }
            }

        case .mixed:
            return nil
        }
    }
}

/// Remembers recently asked generated questions so practice keeps moving on.
enum QuizMemory {
    private static let key = "jero.recentQuestions"
    static var recent: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
    static func remember(_ keys: [String]) {
        var r = recent + keys
        if r.count > 400 { r.removeFirst(r.count - 400) }
        UserDefaults.standard.set(r, forKey: key)
    }
}


/// A small repeatable random generator (so a numbered exam version always holds the same lesson questions).
struct ExamShuffleRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
