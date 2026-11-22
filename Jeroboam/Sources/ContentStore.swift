import Foundation

/// All bundled content (course + library + maps), loaded once.
final class ContentStore {
    static let shared = ContentStore()

    let course: Course
    let library: Library
    /// Wine places that are not in the atlas: mapped for the Journal and shown from Settings.
    private(set) var extraRegions: [Region] = []
    private var extraSoils: [String: String] = [:]
    /// Latitude and longitude of every mapped place (and a centre for each country page).
    private var places: [String: [Double]] = [:]

    private(set) var grapesByID: [String: Grape] = [:]
    private(set) var regionsByID: [String: Region] = [:]
    private(set) var colorsByID: [String: WineColor] = [:]
    private(set) var flowsByID: [String: Flow] = [:]
    private(set) var stylesByID: [String: WineStyle] = [:]
    private(set) var lessonIndex: [String: (level: Level, unit: Unit, lesson: Lesson)] = [:]
    private(set) var orderedLessons: [Lesson] = []
    private var mapCache: [String: WineMap] = [:]
    private let lock = NSLock()

    private init() {
        course = Self.load("course", as: Course.self) ?? Course(levels: [])
        library = Self.load("library", as: Library.self)
            ?? Library(wines: [], grapes: [], regions: [], aromas: [], colors: [], glossary: [], styles: [], flows: [], sat: [], pairings: [], labels: [])
        for g in library.grapes { grapesByID[g.id] = g }
        for r in library.regions { regionsByID[r.id] = r }
        places = Self.load("places", as: [String: [Double]].self) ?? [:]
        if let x = Self.load("extra", as: ExtraLibrary.self) {
            extraRegions = x.regions
            extraSoils = x.soils ?? [:]
            for r in x.regions where regionsByID[r.id] == nil { regionsByID[r.id] = r }
        }
        for c in library.colors { colorsByID[c.id] = c }
        for f in library.flows { flowsByID[f.id] = f }
        for s in library.styles { stylesByID[s.id] = s }
        for level in course.levels {
            for unit in level.units {
                for lesson in unit.lessons {
                    lessonIndex[lesson.id] = (level, unit, lesson)
                    orderedLessons.append(lesson)
                }
            }
        }
    }

    private static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Content")
                ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            print("Content: missing \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Content: failed to decode \(name).json: \(error)")
            return nil
        }
    }

    func map(_ id: String) -> WineMap? {
        lock.lock(); defer { lock.unlock() }
        if let m = mapCache[id] { return m }
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Maps")
                ?? Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(WineMap.self, from: data) else { return nil }
        mapCache[id] = m
        return m
    }

    func grape(_ id: String) -> Grape? { grapesByID[id] }
    func region(_ id: String) -> Region? { regionsByID[id] }
    func soil(_ id: String) -> String? { library.soils?[id] ?? extraSoils[id] }
    func color(_ id: String) -> WineColor? { colorsByID[id] }
    func flow(_ id: String) -> Flow? { flowsByID[id] }
    func label(_ id: String) -> WineLabel? { library.labels?.first { $0.id == id } }
    func label(forRegion id: String) -> WineLabel? { library.labels?.first { $0.region == id } }

    /// Region entries that can be opened from a map region id (the map's own region ids match library ids).
    func regionForMapArea(_ id: String) -> Region? { regionsByID[id] }

    /// Where a place is on the earth: its own centre when it is a mapped area, else the centre of the country's wine areas.
    func coordinate(of r: Region) -> (lat: Double, lon: Double)? {
        for id in [r.highlight?.first, r.id].compactMap({ $0 }) {
            if let p = places[id], p.count == 2 { return (p[0], p[1]) }
        }
        return nil
    }

    /// The atlas page for a wine's region as written on a label or by the model ("Uco Valley, Mendoza", "Mendoza"…):
    /// the most specific place whose name appears in the text, else the page of the country.
    func regionMatching(_ text: String, country: String = "") -> Region? {
        func norm(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
                .replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "'", with: "")
        }
        let t = " " + norm(text).components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: " "))).joined(separator: " ") + " "
        var best: (Region, Int)? = nil
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            for r in library.regions + extraRegions where r.kind != "country" {
                let n = norm(r.name)
                guard n.count >= 3 else { continue }
                if t.contains(" " + n + " ") || (n.count >= 5 && t.contains(n)) {
                    let score = n.count + (r.kind == "subregion" ? 4 : 0)
                    if best == nil || score > best!.1 { best = (r, score) }
                }
            }
        }
        if let b = best { return b.0 }
        let c = norm(country).trimmingCharacters(in: .whitespaces)
        if !c.isEmpty {
            return (library.regions + extraRegions).first { $0.kind == "country" && norm($0.name) == c }
                ?? (library.regions + extraRegions).first { $0.kind == "country" && (norm($0.name).contains(c) || c.contains(norm($0.name))) }
        }
        return nil
    }

    func allAromaCategories() -> [AromaCategory] { library.aromas.flatMap { $0.categories } }

    func aromaCategory(forItem item: String) -> AromaCategory? {
        let key = item.lowercased()
        for c in allAromaCategories() where c.items.contains(where: { $0.lowercased() == key }) { return c }
        return nil
    }

    func grapes(inRegion id: String) -> [Grape] {
        guard let r = region(id) else { return [] }
        return r.grapes.compactMap { grape($0) }
    }

    func regions(forGrape g: Grape) -> [Region] { g.regions.compactMap { region($0) } }

    func level(ofLesson id: String) -> Level? { lessonIndex[id]?.level }
    func unit(ofLesson id: String) -> Unit? { lessonIndex[id]?.unit }
    func lesson(_ id: String) -> Lesson? { lessonIndex[id]?.lesson }

    var totalLessons: Int { orderedLessons.count }
}
