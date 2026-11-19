import Foundation

// MARK: - Course

struct Course: Decodable {
    let levels: [Level]
}

struct Level: Decodable, Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let color: String
    let units: [Unit]
    var courseUnits: [Unit] { units.filter { !$0.isStudy } }
    var studyUnits: [Unit] { units.filter(\.isStudy) }

    static func == (a: Level, b: Level) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Unit: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let lessons: [Lesson]
    var cover: String? = nil
    /// Generated study-guide units (grape files, appellations, vocabulary): open as soon as the level is.
    var study: Bool? = nil
    var isStudy: Bool { study == true }

    static func == (a: Unit, b: Unit) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Lesson: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String?
    let cards: [Card]

    static func == (a: Lesson, b: Lesson) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var questionCount: Int { cards.filter { $0.isQuestion }.count }
}

enum CardKind: String, Decodable {
    case learn, choice, blank, tf, match
}

struct Card: Decodable, Identifiable, Hashable {
    let id: String
    let kind: CardKind
    let title: String?
    let body: String?
    let question: String?
    let options: [String]?
    let answer: Int?
    let answers: [String]?
    let truth: Bool?
    let pairs: [[String]]?
    let explain: String?
    let visual: String?

    var isQuestion: Bool { kind != .learn }

    enum CodingKeys: String, CodingKey {
        case id, kind = "t", title, body, question = "q", options, answer = "a", answers, truth, pairs, explain, visual
    }

    init(id: String, kind: CardKind, title: String? = nil, body: String? = nil, question: String? = nil,
         options: [String]? = nil, answer: Int? = nil, answers: [String]? = nil, truth: Bool? = nil,
         pairs: [[String]]? = nil, explain: String? = nil, visual: String? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.body = body; self.question = question
        self.options = options; self.answer = answer; self.answers = answers; self.truth = truth
        self.pairs = pairs; self.explain = explain; self.visual = visual
    }

    static func == (a: Card, b: Card) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - Library

enum BerryColor: String, Decodable {
    case black, white, pink
}

struct Grape: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let berry: BerryColor
    let aka: [String]?
    let pronounce: String?
    let origin: String
    let summary: String
    let body: Int
    let acidity: Int
    let tannin: Int
    let alcohol: Int
    let sweetness: Int
    let aromas: [String]
    let cool: String?
    let warm: String?
    let regions: [String]
    let styles: String?
    let food: [String]
    let ageing: String?
    let glass: String
    let fact: String?
    let level: Int

    static func == (a: Grape, b: Grape) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Region: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let kind: String          // country, region, subregion
    let map: String?          // map file to show
    let highlight: [String]?  // region ids on that map to highlight
    let climate: String?
    let grapes: [String]
    let summary: String
    let styles: String?
    let classification: String?
    let facts: [String]?
    let sub: [String]?
    let level: Int

    static func == (a: Region, b: Region) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct AromaGroup: Decodable, Identifiable, Hashable {
    let id: String          // primary, secondary, tertiary
    let name: String
    let summary: String
    let categories: [AromaCategory]
}

struct AromaCategory: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let color: String
    let icon: String
    let note: String?
    let items: [String]
}

struct WineColor: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let family: String      // white, rose, red
    let hex: String
    let rim: String
    let note: String
    let chart: Bool?
    let examples: String?
}

struct GlossaryTerm: Decodable, Identifiable, Hashable {
    var id: String { term }
    let term: String
    let def: String
    let level: Int?
}

struct WineStyle: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let summary: String
    let how: String
    let taste: String?
    let examples: [String]
    let visual: String?
}

struct Flow: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let steps: [FlowStep]
}

struct FlowStep: Decodable, Hashable {
    let icon: String
    let title: String
    let text: String
}

struct SATSection: Decodable, Identifiable, Hashable {
    var id: String { title }
    let title: String
    let icon: String
    let items: [SATItem]
}

struct SATItem: Decodable, Hashable {
    let name: String
    let scale: [String]
    let tip: String
}

struct Pairing: Decodable, Identifiable, Hashable {
    var id: String { food }
    let food: String
    let icon: String
    let effect: String
    let tip: String
}

struct Library: Decodable {
    let wines: [Wine]?
    let grapes: [Grape]
    let regions: [Region]
    let aromas: [AromaGroup]
    let colors: [WineColor]
    let glossary: [GlossaryTerm]
    let styles: [WineStyle]
    let flows: [Flow]
    let sat: [SATSection]
    let pairings: [Pairing]
    let labels: [WineLabel]?
    var facts: [String]? = nil
}

struct WineLabel: Decodable, Identifiable, Hashable {
    struct Field: Decodable, Hashable {
        let kind: String
        let text: String
        let note: String
    }
    let id: String
    let title: String
    let region: String
    let style: String
    let summary: String
    let fields: [Field]
}

// MARK: - Maps

struct WineMap: Decodable {
    struct MapRegion: Decodable, Identifiable {
        let id: String
        let name: String
        let small: Bool
        let shapes: [[Int]]
        let lx: Int
        let ly: Int
    }
    struct City: Decodable { let n: String; let x: Int; let y: Int }
    struct Label: Decodable { let t: String; let x: Int; let y: Int; let k: String }
    struct River: Decodable { let w: Int; let p: [Int] }

    let id: String
    let title: String
    let w: Int
    let h: Int
    let land: [[Int]]
    let focus: [[Int]]
    let lakes: [[Int]]
    let rivers: [River]
    let regions: [MapRegion]
    let cities: [City]
    let labels: [Label]
    let belts: [Int]?
}
