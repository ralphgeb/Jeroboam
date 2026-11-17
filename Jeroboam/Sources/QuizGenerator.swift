import Foundation

/// Builds practice sessions from the library (endless, generated questions) and from past mistakes.
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
            case .terms: return "Wine vocabulary"
            }
        }
        var subtitle: String {
            switch self {
            case .mixed: return "A blend of everything you have learned"
            case .grapes: return "Profiles, aromas and homelands"
            case .regions: return "Where wines come from and what they are made of"
            case .maps: return "Spot regions on the map"
            case .colors: return "Name the color in the glass"
            case .aromas: return "Primary, secondary and tertiary notes"
            case .terms: return "The language of wine"
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

    static func session(_ kind: Kind, count: Int = 10, maxLevel: Int = 3) -> Session {
        var cards: [Card] = []
        var guardCount = 0
        while cards.count < count && guardCount < count * 6 {
            guardCount += 1
            let k: Kind = kind == .mixed ? [.grapes, .regions, .maps, .colors, .aromas, .terms, .grapes, .regions].randomElement()! : kind
            if let c = make(k, maxLevel: maxLevel), !cards.contains(where: { $0.question == c.question }) {
                cards.append(c)
            }
        }
        // Daily mix also includes questions from finished lessons.
        if kind == .mixed {
            let done = content.orderedLessons.filter { lessonCompleted($0.id) }
            let pool = done.flatMap { $0.cards.filter(\.isQuestion) }.shuffled().prefix(4)
            cards = Array(cards.prefix(count - pool.count)) + pool
            cards.shuffle()
        }
        return Session(title: kind.title, lessonID: nil, cards: cards)
    }

    static func mistakes(_ ids: [String]) -> Session {
        var byID: [String: Card] = [:]
        for l in content.orderedLessons { for c in l.cards { byID[c.id] = c } }
        let cards = ids.reversed().compactMap { byID[$0] }.prefix(12)
        return Session(title: "Review mistakes", lessonID: nil, cards: Array(cards))
    }

    static var lessonCompleted: (String) -> Bool = { _ in false }

    private static func uid() -> String { "gen-" + UUID().uuidString }

    private static func choice(_ q: String, correct: String, wrong: [String], explain: String?, visual: String? = nil) -> Card? {
        let wrongs = Array(Set(wrong.filter { $0 != correct })).shuffled().prefix(3)
        guard wrongs.count >= 2 else { return nil }
        var opts = Array(wrongs)
        let pos = Int.random(in: 0...opts.count)
        opts.insert(correct, at: pos)
        return Card(id: uid(), kind: .choice, question: q, options: opts, answer: pos, explain: explain, visual: visual)
    }

    private static func make(_ kind: Kind, maxLevel: Int) -> Card? {
        let grapes = content.library.grapes.filter { $0.level <= maxLevel }
        let regions = content.library.regions.filter { $0.level <= maxLevel && $0.kind != "country" }
        switch kind {
        case .grapes:
            guard let g = grapes.randomElement() else { return nil }
            switch Int.random(in: 0..<5) {
            case 0:
                let notes = g.aromas.prefix(3).joined(separator: ", ").lowercased()
                return choice("Which grape is often described with aromas of **\(notes)**?", correct: g.name,
                              wrong: grapes.filter { $0.berry == g.berry }.map(\.name), explain: g.summary, visual: "grape:\(g.id)")
            case 1:
                guard let r = content.regions(forGrape: g).randomElement() else { return nil }
                let others = grapes.filter { !$0.regions.contains(r.id) && $0.berry == g.berry }.map(\.name)
                return choice("Which grape is a key variety in **\(r.name)**?", correct: g.name, wrong: others,
                              explain: "\(r.name): \(r.summary)")
            case 2:
                return Card(id: uid(), kind: .tf, question: "\(g.name) is a \(g.berry == .white ? "white" : "black") grape.",
                            truth: true, explain: g.summary, visual: "grape:\(g.id)")
            case 3:
                let lie: BerryColor = g.berry == .white ? .black : .white
                return Card(id: uid(), kind: .tf, question: "\(g.name) is a \(lie == .white ? "white" : "black") grape.",
                            truth: false, explain: "\(g.name) is a \(g.berry == .white ? "white" : (g.berry == .pink ? "pink-skinned" : "black")) grape. \(g.summary)",
                            visual: "grape:\(g.id)")
            default:
                let origin = g.origin
                return choice("Where does **\(g.name)** originally come from?", correct: origin,
                              wrong: grapes.map(\.origin), explain: g.fact ?? g.summary)
            }
        case .regions:
            guard let r = regions.randomElement() else { return nil }
            if Int.random(in: 0..<2) == 0 {
                return choice("**\(r.name)** is a wine region in…", correct: r.country,
                              wrong: content.library.regions.map(\.country), explain: r.summary,
                              visual: r.map.map { "map:\($0):\((r.highlight ?? [r.id]).joined(separator: ","))" })
            }
            guard let gid = r.grapes.first, let g = content.grape(gid) else { return nil }
            return choice("Which grape is most associated with **\(r.name)**?", correct: g.name,
                          wrong: grapes.filter { !r.grapes.contains($0.id) }.map(\.name), explain: r.summary)
        case .maps:
            let candidates = regions.filter { $0.map != nil && ($0.highlight?.count ?? 1) == 1 }
            guard let r = candidates.randomElement(), let mapID = r.map, let geo = MapGeometry.get(mapID) else { return nil }
            let target = r.highlight?.first ?? r.id
            guard let area = geo.areas.first(where: { $0.id == target }) else { return nil }
            let others = geo.areas.filter { $0.id != target }.map(\.name)
            return choice("Which region is highlighted on this map?", correct: area.name, wrong: others,
                          explain: r.summary, visual: "map:\(mapID):\(target)")
        case .colors:
            guard let c = content.library.colors.randomElement() else { return nil }
            let same = content.library.colors.filter { $0.family == c.family }.map(\.name)
            return choice("Which color best describes this wine?", correct: c.name, wrong: same, explain: c.note, visual: "glassonly:\(c.id)")
        case .aromas:
            let cats = content.allAromaCategories()
            guard let cat = cats.randomElement(), let item = cat.items.randomElement() else { return nil }
            if Int.random(in: 0..<2) == 0 {
                guard let group = content.library.aromas.first(where: { $0.categories.contains(cat) }) else { return nil }
                let opts = content.library.aromas.map(\.name)
                return choice("**\(item)** is classed as which type of aroma?", correct: group.name, wrong: opts,
                              explain: "\(item) belongs to **\(cat.name)**, a \(group.name.lowercased()) aroma. \(group.summary)")
            }
            let others = cats.filter { $0.id != cat.id }.map(\.name)
            return choice("In the aroma lexicon, **\(item)** belongs to…", correct: cat.name, wrong: others,
                          explain: cat.note ?? "\(cat.name): \(cat.items.prefix(6).joined(separator: ", ")).")
        case .terms:
            let terms = content.library.glossary.filter { ($0.level ?? 1) <= maxLevel }
            guard let t = terms.randomElement() else { return nil }
            if Int.random(in: 0..<2) == 0 {
                return choice("What does **\(t.term)** mean?", correct: t.def, wrong: terms.map(\.def), explain: nil)
            }
            return choice("Which term means: “\(t.def)”", correct: t.term, wrong: terms.map(\.term), explain: nil)
        case .mixed:
            return nil
        }
    }
}
