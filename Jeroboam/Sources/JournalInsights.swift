import SwiftUI
import Charts

/// A wine you have tried, boiled down to what the journal's maps and charts need.
struct InsightWine: Identifiable {
    let id = UUID()
    var country: String
    var region: String
    var style: String        // red, white, rosé, sparkling, sweet
    var grapes: [String]
    var price: Double?
    var body: Int            // 1 light … 5 full
    var rating: Int?
    var date: Date
    /// In the cellar, or tasted in the journal (the map can show either, or both).
    var tasted = false
    var title = ""
}

/// Which wines the Journal's world map shows.
enum MapFilter: Int, CaseIterable, Hashable {
    case all, cellar, tasted
    var title: String { ["All", "In my cellar", "Tasted"][rawValue] }
    func keeps(_ w: InsightWine) -> Bool { self == .all || (self == .tasted) == w.tasted }
}

/// How the Journal's world map shows your wines. Dots by default; TestFlight can switch to compare the other two.
enum WineMapStyle: Int, CaseIterable {
    case dots, glow, countries
    var title: String { ["Dots", "Glow", "Countries"][rawValue] }
}

/// A place on the Journal's world map.
struct MapDot: Identifiable {
    let id: String
    let point: CGPoint
    let name: String
    let count: Int
    let color: Color
    var titles: [String] = []
    var map = ""
    var highlight: Set<String> = []
}

/// A country shaded by how many of your wines come from it ("Countries" style).
struct CountryShade {
    let path: Path
    let count: Int
}

/// Country outlines on the world map's grid (tools/build_world_countries.py, Natural Earth), for the "Countries" style.
enum WorldCountries {
    private struct File: Decodable { struct C: Decodable { let n: String; let a: [String]; let p: [[Double]] }; let countries: [C] }
    private struct Country { let names: Set<String>; let path: Path }
    private static let aliases = ["usa": "united states of america", "united states": "united states of america", "us": "united states of america",
                                  "uk": "united kingdom", "england": "united kingdom", "scotland": "united kingdom", "wales": "united kingdom",
                                  "czechia": "czech republic", "macedonia": "north macedonia", "holland": "netherlands"]
    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().trimmingCharacters(in: .whitespaces)
    }
    /// Read once (thread-safe), the first time a "Countries" map is drawn.
    private static let all: [Country] = {
        guard let url = Bundle.main.url(forResource: "world-countries", withExtension: "json", subdirectory: "Maps")
                ?? Bundle.main.url(forResource: "world-countries", withExtension: "json"),
              let data = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return f.countries.map { c in
            var path = Path()
            for r in c.p where r.count >= 6 {
                path.move(to: CGPoint(x: r[0], y: r[1]))
                var i = 2
                while i + 1 < r.count { path.addLine(to: CGPoint(x: r[i], y: r[i + 1])); i += 2 }
                path.closeSubpath()
            }
            return Country(names: Set(([c.n] + c.a).map(norm)), path: path)
        }
    }()
    static func shape(for country: String) -> Path? {
        let n = norm(country)
        let k = aliases[n] ?? n
        return all.first { $0.names.contains(k) }?.path
    }
}

/// The Journal's closing section: a map of everywhere you have tasted, and a few charts about what you drink.
/// Until you have a few wines of your own it shows an example, clearly marked, so you can see how it will look.
struct JournalInsights: View {
    @Environment(JournalStore.self) private var journal
    /// Which tab the charts belong to: the wines you have tasted, or the bottles in your cellar.
    var tasted: Bool
    /// Worked out once, away from the main thread, and again only when the bottles or tastings change
    /// (matching every wine's region against the atlas used to make the Journal tab hesitate when it opened).
    @State private var snap: Snapshot? = nil

    private struct Snapshot {
        var real: [InsightWine]
    }

    /// Changes whenever a bottle or tasting is added, removed or gets a different country, region or style.
    private var signature: Int {
        var h = Hasher()
        for b in journal.cellar { h.combine(b.id); h.combine(b.wine.country); h.combine(b.wine.region); h.combine(b.wine.style); h.combine(b.price?.average) }
        for e in journal.entries { h.combine(e.id); h.combine(e.wine.country); h.combine(e.wine.region); h.combine(e.rating) }
        return h.finalize()
    }

    /// Only this tab's wines: tastings on the Tastings tab, bottles on the Cellar tab.
    private var real: [InsightWine] { (snap?.real ?? []).filter { $0.tasted == tasted } }

    private static func makeReal(cellar: [CellarBottle], entries: [JournalEntry]) -> [InsightWine] {
        var out: [InsightWine] = []
        func family(_ s: String) -> String {
            let t = s.lowercased()
            if t.contains("spark") || t.contains("champ") || t.contains("cava") || t.contains("prosecco") { return "sparkling" }
            if t.contains("ros") { return "rosé" }
            if t.contains("sweet") || t.contains("dessert") || t.contains("port") || t.contains("sauternes") { return "sweet" }
            if t.contains("white") { return "white" }
            return "red"
        }
        func bodyOf(_ w: WineIdentity) -> Int { matchGrape(w.grapes.first)?.body ?? 3 }
        for b in cellar where !b.wine.country.isEmpty {
            out.append(InsightWine(country: b.wine.country, region: b.wine.region, style: family(b.wine.style), grapes: b.wine.grapes,
                                   price: b.price?.average, body: bodyOf(b.wine), rating: b.roughRating, date: b.added,
                                   tasted: false, title: b.title))
        }
        for e in entries where !e.wine.country.isEmpty {
            out.append(InsightWine(country: e.wine.country, region: e.wine.region, style: family(e.wine.style), grapes: e.wine.grapes,
                                   price: nil, body: e.body, rating: e.rating, date: e.date, tasted: true, title: e.title))
        }
        return out
    }

    private var useExample: Bool { real.count < 3 }
    private var wines: [InsightWine] { useExample ? Self.example.filter { $0.tasted == tasted } : real }

    var body: some View {
        Group {
            if snap != nil { content } else { placeholder }
        }
        .task(id: signature) {
            let cellar = journal.cellar, entries = journal.entries
            snap = await Task.detached(priority: .userInitiated) { () -> Snapshot in
                Snapshot(real: JournalInsights.makeReal(cellar: cellar, entries: entries))
            }.value
        }
    }

    /// For the moment the section takes to work out (it sits at the bottom of the page).
    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: heading)
            SkeletonBar(height: 120, radius: 16)
            SkeletonBar(height: 120, radius: 16)
        }
    }

    private var heading: String { tasted ? "Your tastings" : "Your cellar" }

    private var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(text: heading)
                if useExample {
                    Text("EXAMPLE").font(.system(size: 10, weight: .bold)).kerning(1)
                        .foregroundStyle(Palette.wine).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.wineSoft))
                }
            }
            if useExample {
                Text(tasted ? "This is how it will look. It fills in with the wines you taste."
                            : "This is how it will look. It fills in with the bottles you add to your cellar.")
                    .font(.system(size: 13)).foregroundStyle(Palette.inkSoft).padding(.top, -16)
            }
            countriesCard
            chartGrid
        }
    }

    // MARK: map

    private static let mapOf: [String: String] = [
        "france": "france", "italy": "italy", "spain": "spain", "portugal": "portugal", "germany": "germany", "austria": "austria",
        "hungary": "hungary", "greece": "greece", "united states": "california", "usa": "california", "chile": "chile",
        "argentina": "argentina", "australia": "australia", "new zealand": "new-zealand", "south africa": "south-africa", "lebanon": "lebanon",
    ]

    private func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            .replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Map areas (appellations) the wines come from, by name.
    private func tried(in mapID: String, regions: [String]) -> Set<String> {
        guard let g = MapGeometry.get(mapID) else { return [] }
        var out = Set<String>()
        for r in regions where !r.isEmpty {
            let n = norm(r)
            if let a = g.areas.filter({ norm($0.name) == n }).first ?? g.areas.filter({ norm($0.name).contains(n) || n.contains(norm($0.name)) }).max(by: { $0.level < $1.level }) {
                out.insert(a.id)
            }
        }
        return out
    }

    private var mapCountries: [(country: String, map: String, hl: Set<String>, bottles: Int)] {
        var groups: [String: [InsightWine]] = [:]
        for w in wines { groups[norm(w.country), default: []].append(w) }
        return groups.compactMap { key, ws in
            guard let m = Self.mapOf[key], MapGeometry.get(m) != nil else { return nil }
            let name = ws.first?.country ?? key
            return (name, m, tried(in: m, regions: ws.map(\.region)), ws.count)
        }
        .sorted { $0.bottles > $1.bottles }
    }

    // world coordinates: the world map is a plain lat/lon grid, 13.71 map units per degree, 0° east at x 2331 and 44.84° north at y 372
    private static func mapPoint(lat: Double, lon: Double) -> CGPoint { CGPoint(x: 2331 + 13.71 * lon, y: 372 - 13.74 * (lat - 44.84)) }

    private static func makeDots(_ wines: [InsightWine]) -> [MapDot] {
        var by: [String: (region: Region, wines: [InsightWine])] = [:]
        for w in wines {
            var found = ContentStore.shared.regionMatching(w.region, country: w.country)
            if let f = found, ContentStore.shared.coordinate(of: f) == nil { found = ContentStore.shared.regionMatching("", country: w.country) }
            guard let r = found, ContentStore.shared.coordinate(of: r) != nil else { continue }
            by[r.id, default: (r, [])].wines.append(w)
        }
        return by.values.compactMap { r, ws -> MapDot? in
            guard let c = ContentStore.shared.coordinate(of: r), let map = r.map else { return nil }
            // coloured by what you have most of there (red, white, rosé, sparkling, sweet)
            var tally: [String: Int] = [:]
            for w in ws { tally[w.style, default: 0] += 1 }
            let style = tally.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key ?? "red"
            return MapDot(id: r.id, point: Self.mapPoint(lat: c.lat, lon: c.lon), name: r.name, count: ws.count,
                          color: Self.styleColors[style] ?? Palette.wine, titles: ws.map(\.title).filter { !$0.isEmpty },
                          map: map, highlight: Set(r.highlight ?? (r.kind == "country" ? [] : [r.id])))
        }
        .sorted { $0.name < $1.name }
    }

    private static func makeShades(_ wines: [InsightWine]) -> [CountryShade] {
        var by: [String: (country: String, n: Int)] = [:]
        for w in wines { let k = WorldCountries.norm(w.country); by[k] = (w.country, (by[k]?.n ?? 0) + 1) }
        return by.values.compactMap { c, n in WorldCountries.shape(for: c).map { CountryShade(path: $0, count: n) } }
    }

    // MARK: countries (flags and bottle counts)

    private var countriesCard: some View {
        var tally: [String: (name: String, n: Int)] = [:]
        for w in wines { let k = norm(w.country); tally[k] = (tally[k]?.name ?? w.country, (tally[k]?.n ?? 0) + 1) }
        let rows = tally.values.sorted { $0.n > $1.n || ($0.n == $1.n && $0.name < $1.name) }
        let most = max(1, rows.first?.n ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Where your wines come from").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("\(rows.count) \(rows.count == 1 ? "country" : "countries")").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                }
                VStack(spacing: 10) {
                    ForEach(rows.prefix(8), id: \.name) { r in
                        HStack(spacing: 12) {
                            Text(Flag.emoji(for: r.name)).font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.name).font(.system(size: 14.5, weight: .medium)).foregroundStyle(Palette.ink)
                                GeometryReader { geo in
                                    Capsule().fill(Palette.wine.opacity(0.85)).frame(width: max(8, geo.size.width * CGFloat(r.n) / CGFloat(most)))
                                }
                                .frame(height: 6)
                            }
                            Text("\(r.n)").font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 16)
    }

    // MARK: charts

    private var chartGrid: some View {
        let tastings = journal.persist ? journal.entries : []
        let blind = tastings.filter { $0.isBlind && $0.score != nil }
        let cellar = journal.persist ? journal.cellar : []
        return VStack(spacing: 14) {
            if tasted, let line = TasteInsight.sentence(entries: tastings) { InsightSentenceCard(text: line) }
            HStack(alignment: .top, spacing: 12) {
                stylesCard
                topGrapeCard
            }
            if tasted {
                // what you have tasted: your palate, month by month, blind progress
                if !tastings.isEmpty { TasteFingerprintCard(entries: tastings) }
                MonthsCard(wines: wines)
                if blind.count >= 2 { BlindProgressCard(blind: blind) }
                GrapeRingCard(wines: wines)
                bodyCard
            } else {
                // what you keep: when it is ready, what it cost, how it grew
                if cellar.contains(where: { DrinkWindow.years($0.wine.drinkWindow) != nil }) { CellarReadinessCard(cellar: cellar) }
                GrapeRingCard(wines: wines)
                priceCard
                bodyCard
                MonthsCard(wines: wines)
            }
        }
    }

    private func card<C: View>(_ title: String, _ sub: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(sub).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private static let styleColors: [String: Color] = [
        "red": Color(hex: "#8B1538"), "white": Color(hex: "#D9C27A"), "rosé": Color(hex: "#E58BA2"),
        "sparkling": Color(hex: "#A9B8A0"), "sweet": Color(hex: "#C98B3C"),
    ]

    private var stylesCard: some View {
        let counts = ["red", "white", "rosé", "sparkling", "sweet"].map { s in (s, wines.filter { $0.style == s }.count) }.filter { $0.1 > 0 }
        let reds = wines.filter { $0.style == "red" }.count
        return card("Reds and whites", "\(reds) of \(wines.count) red") {
            VStack(alignment: .leading, spacing: 10) {
                Chart(counts, id: \.0) { s, n in
                    SectorMark(angle: .value("Wines", n), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Self.styleColors[s] ?? Palette.wine)
                }
                .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(counts, id: \.0) { s, n in
                        HStack(spacing: 6) {
                            Circle().fill(Self.styleColors[s] ?? Palette.wine).frame(width: 8, height: 8)
                            Text(s.capitalized).font(.system(size: 12.5)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 2)
                            Text("\(n)").font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
            }
        }
    }

    private var topGrapeCard: some View {
        var tally: [String: Int] = [:]
        for w in wines { for g in w.grapes.prefix(1) { tally[g, default: 0] += 1 } }
        let top = tally.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }
        let grape = matchGrape(top?.key)
        return card(tasted ? "Your grape" : "Your cellar's grape",
                    top == nil ? (tasted ? "Taste a wine to find it" : "Add a bottle to find it") : (tasted ? "The one you pick most" : "The one you keep most")) {
            VStack(alignment: .leading, spacing: 8) {
                if let g = grape { GrapeBadge(grape: g, size: 62) }
                Text(top?.key ?? "–").font(.system(size: 19, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(2).minimumScaleFactor(0.8)
                Text("\(top?.value ?? 0) \((top?.value ?? 0) == 1 ? "wine" : "wines")").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var bodyCard: some View {
        let names = ["Light", "Light+", "Medium", "Full", "Bold"]
        let bars = (1...5).map { b in (names[b - 1], wines.filter { $0.body == b }.count) }
        let avg = Double(wines.map(\.body).reduce(0, +)) / Double(max(1, wines.count))
        return card("Light or bold", avg >= 3.5 ? "You lean towards bold wines" : (avg <= 2.5 ? "You lean towards light wines" : "You like the middle: medium bodied")) {
            Chart(bars, id: \.0) { n, c in
                BarMark(x: .value("Body", n), y: .value("Wines", c)).foregroundStyle(Palette.wine.gradient).cornerRadius(5)
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }

    private var priceCard: some View {
        let ps = wines.compactMap(\.price)
        let r = Currency.round
        let tiers: [(String, Int)] = [("Under " + r(20), ps.filter { $0 < 20 }.count), (r(20) + "–" + r(50), ps.filter { $0 >= 20 && $0 < 50 }.count),
                                      (r(50) + "–" + r(100), ps.filter { $0 >= 50 && $0 < 100 }.count), (r(100) + "+", ps.filter { $0 >= 100 }.count)]
        return card("What you spend", ps.isEmpty ? "Scan a bottle to see its price" : "Typical bottle about " + Currency.format(ps.sorted()[ps.count / 2], from: "USD")) {
            Chart(tiers, id: \.0) { t, n in
                BarMark(x: .value("Tier", t), y: .value("Wines", n)).foregroundStyle(Palette.brass.gradient).cornerRadius(5)
            }
            .chartYAxis(.hidden)
            .frame(height: 100)
        }
    }

    // MARK: example data

    static let example: [InsightWine] = {
        let cal = Calendar.current
        func d(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: .now) ?? .now }
        func w(_ c: String, _ r: String, _ s: String, _ g: [String], _ p: Double?, _ b: Int, _ rt: Int?, _ day: Int) -> InsightWine {
            InsightWine(country: c, region: r, style: s, grapes: g, price: p, body: b, rating: rt, date: d(day),
                        tasted: day % 2 == 0, title: r + " " + (g.first ?? ""))
        }
        return [
            w("France", "Pauillac", "red", ["Cabernet Sauvignon", "Merlot"], 120, 5, 94, 3),
            w("France", "Saint-Émilion", "red", ["Merlot", "Cabernet Franc"], 85, 4, 91, 9),
            w("France", "Sancerre", "white", ["Sauvignon Blanc"], 38, 2, 89, 16),
            w("France", "Chablis", "white", ["Chardonnay"], 34, 2, 90, 24),
            w("France", "Champagne", "sparkling", ["Chardonnay", "Pinot Noir"], 65, 2, 92, 31),
            w("France", "Chateauneuf-du-Pape", "red", ["Grenache", "Syrah"], 60, 4, 90, 38),
            w("Italy", "Barolo", "red", ["Nebbiolo"], 75, 4, 93, 45),
            w("Italy", "Chianti Classico", "red", ["Sangiovese"], 28, 3, 88, 52),
            w("Italy", "Montalcino", "red", ["Sangiovese"], 70, 4, 91, 60),
            w("Spain", "Rioja", "red", ["Tempranillo"], 24, 3, 87, 66),
            w("Spain", "Priorat", "red", ["Grenache", "Carignan"], 45, 5, 92, 74),
            w("Portugal", "Douro", "red", ["Touriga Nacional"], 30, 4, 89, 80),
            w("Germany", "Mosel", "white", ["Riesling"], 26, 1, 91, 88),
            w("Austria", "Wachau", "white", ["Grüner Veltliner"], 32, 2, 90, 96),
            w("United States", "Napa Valley", "red", ["Cabernet Sauvignon"], 95, 5, 93, 104),
            w("New Zealand", "Marlborough", "white", ["Sauvignon Blanc"], 16, 2, 86, 112),
            w("Australia", "Barossa", "red", ["Shiraz"], 40, 5, 91, 120),
            w("Lebanon", "Bekaa Valley", "red", ["Cabernet Sauvignon", "Cinsault"], 58, 4, 92, 128),
            w("Argentina", "Mendoza", "red", ["Malbec"], 22, 4, 88, 136),
            w("South Africa", "Stellenbosch", "red", ["Pinotage"], 20, 4, 86, 144),
        ]
    }()
}


/// The whole world in blue water and pale land, with a dot for every place you have tasted. Pinch to zoom in, drag to move,
/// double-tap to reset, tap a dot to open that country's map.
struct WorldTriedMap: View {
    let dots: [MapDot]
    var shades: [CountryShade] = []
    var style: WineMapStyle = .dots
    var selected: String? = nil
    var interactive = true
    /// nil fills the space it is given (the full-screen map)
    var height: CGFloat? = 200
    var zoomCommand = 0
    let onOpen: (String) -> Void
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var fittedFor = ""
    @State private var pinching = false
    private let g = MapGeometry.get("world")

    /// Zooms so that the point of the map under `anchor` (a point in the view) stays under it: pinching or double-tapping
    /// anywhere zooms there, not into the middle. Works from the zoom and pan at the start of the gesture.
    private func zoomTo(_ target: CGFloat, anchor: CGPoint, size: CGSize) {
        let mw = CGFloat(g?.map.w ?? 4800), mh = CGFloat(g?.map.h ?? 1755)
        let base = size.width / mw
        let s0 = base * lastZoom
        let origin0 = CGPoint(x: (size.width - mw * s0) / 2 + lastPan.width, y: (size.height - mh * s0) / 2 + lastPan.height)
        let m = CGPoint(x: (anchor.x - origin0.x) / s0, y: (anchor.y - origin0.y) / s0)
        let z = min(40, max(1, target))
        let s1 = base * z
        zoom = z
        pan = CGSize(width: anchor.x - m.x * s1 - (size.width - mw * s1) / 2, height: anchor.y - m.y * s1 - (size.height - mh * s1) / 2)
    }

    /// Opens zoomed in on the places that have wine, instead of on the whole world.
    private func fit(_ size: CGSize) {
        let key = dots.map(\.id).joined(separator: ",") + "|\(Int(size.width))x\(Int(size.height))"
        guard size.width > 0, size.height > 0, !dots.isEmpty, key != fittedFor else { return }
        fittedFor = key
        let mw = CGFloat(g?.map.w ?? 4800), mh = CGFloat(g?.map.h ?? 1755)
        let xs = dots.map(\.point.x), ys = dots.map(\.point.y)
        let c = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
        let bw = max(xs.max()! - xs.min()!, 300), bh = max(ys.max()! - ys.min()!, 220)   // never tighter than about 22° by 16°
        let base = size.width / mw
        let z = min(30, max(1, min(size.width * 0.74 / bw, size.height * 0.68 / bh) / base))
        zoom = z; lastZoom = z
        let sNew = base * z
        pan = CGSize(width: size.width / 2 - c.x * sNew - (size.width - mw * sNew) / 2,
                     height: size.height / 2 - c.y * sNew - (size.height - mh * sNew) / 2)
        lastPan = pan
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let mw = CGFloat(g?.map.w ?? 4800), mh = CGFloat(g?.map.h ?? 1755)
            let base = size.width / mw
            let s = base * zoom
            let origin = CGPoint(x: (size.width - mw * s) / 2 + pan.width, y: (size.height - mh * s) / 2 + pan.height)
            Canvas { ctx, sz in
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Palette.sea))
                if let g {
                    var layer = ctx
                    layer.translateBy(x: origin.x, y: origin.y)
                    layer.scaleBy(x: s, y: s)
                    layer.fill(g.landMask, with: .color(Palette.focusLand))
                    layer.stroke(g.landMask, with: .color(Palette.border), lineWidth: 0.8 / s)
                }
                let pts = dots.map { (CGPoint(x: origin.x + $0.point.x * s, y: origin.y + $0.point.y * s), 1 + 0.7 * log(Double(max(1, $0.count)))) }
                switch style {
                case .countries:
                    // each country tinted by how many of your wines come from it
                    let most = Double(max(1, shades.map(\.count).max() ?? 1))
                    var layer = ctx
                    layer.translateBy(x: origin.x, y: origin.y)
                    layer.scaleBy(x: s, y: s)
                    for sh in shades {
                        layer.fill(sh.path, with: .color(Palette.wine.opacity(0.22 + 0.58 * sqrt(Double(sh.count) / most))))
                        layer.stroke(sh.path, with: .color(.white.opacity(0.9)), lineWidth: 0.7 / s)
                    }
                case .glow:
                    // one soft Bordeaux glow that deepens where places are close together
                    let heatScale = min(1 + (zoom - 1) * 0.25, 2.6)
                    if let img = HeatImage.make(points: pts, size: size, sigma: 9 * heatScale, mono: true) {
                        ctx.draw(ctx.resolve(Image(decorative: img, scale: 1).interpolation(.high)), in: CGRect(origin: .zero, size: size))
                    }
                case .dots:
                    break
                }
                var taken: [CGRect] = []
                let grow = min(1 + (zoom - 1) * 0.12, 1.7)
                for d in dots.sorted(by: { $0.count > $1.count }) {
                    let p = CGPoint(x: origin.x + d.point.x * s, y: origin.y + d.point.y * s)
                    // small dots, a little bigger for places with more wines; coloured by style in the Dots view
                    let r: CGFloat = style == .dots ? min(8, (2.4 + 1.3 * sqrt(CGFloat(d.count - 1))) * grow) : 2.0 * grow
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(dot, with: .color(style == .dots ? d.color : Palette.bordeaux))
                    ctx.stroke(dot, with: .color(.white), lineWidth: style == .dots ? 1 : 0.8)
                    if d.id == selected {
                        let ring = Path(ellipseIn: CGRect(x: p.x - r - 4, y: p.y - r - 4, width: 2 * r + 8, height: 2 * r + 8))
                        ctx.stroke(ring, with: .color(Palette.wine), lineWidth: 2)
                    }
                    if zoom >= 1.8 {
                        var t = ctx
                        let text = t.resolve(Text(d.name).font(.system(size: 10.5, weight: .semibold)).foregroundColor(Palette.ink))
                        let sz = text.measure(in: CGSize(width: 200, height: 30))
                        let rect = CGRect(x: p.x - sz.width / 2, y: p.y + 7, width: sz.width, height: sz.height)
                        if CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2).contains(rect), !taken.contains(where: { $0.insetBy(dx: -3, dy: -1).intersects(rect) }) {
                            taken.append(rect)
                            t.addFilter(.shadow(color: Palette.focusLand.opacity(0.95), radius: 2))
                            t.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
                        }
                    }
                }
            }
            .onAppear { fit(size) }
            .onChange(of: size) { _, new in fit(new) }
            .onChange(of: dots.count) { _, _ in fit(size) }
            .contentShape(Rectangle())
            .allowsHitTesting(interactive)
            .onChange(of: zoomCommand) { old, new in
                lastZoom = zoom; lastPan = pan
                withAnimation(.easeOut(duration: 0.2)) {
                    zoomTo(zoom * (new > old ? 1.8 : 1 / 1.8), anchor: CGPoint(x: size.width / 2, y: size.height / 2), size: size)
                }
                lastZoom = zoom; lastPan = pan
            }
            .gesture(
                SpatialTapGesture().onEnded { v in
                    let hit = dots.min { hypot(origin.x + $0.point.x * s - v.location.x, origin.y + $0.point.y * s - v.location.y)
                                         < hypot(origin.x + $1.point.x * s - v.location.x, origin.y + $1.point.y * s - v.location.y) }
                    if let h = hit, hypot(origin.x + h.point.x * s - v.location.x, origin.y + h.point.y * s - v.location.y) < 26 { onOpen(h.id) }
                }
            )
            .gesture(DragGesture(minimumDistance: 6)
                .onChanged { guard !pinching else { return }; pan = CGSize(width: lastPan.width + $0.translation.width, height: lastPan.height + $0.translation.height) }
                .onEnded { _ in if !pinching { lastPan = pan } })
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        pinching = true
                        zoomTo(lastZoom * v.magnification, anchor: CGPoint(x: v.startAnchor.x * size.width, y: v.startAnchor.y * size.height), size: size)
                    }
                    .onEnded { _ in lastZoom = zoom; lastPan = pan; pinching = false }
            )
            .onTapGesture(count: 2) { loc in
                lastZoom = zoom; lastPan = pan
                withAnimation(.easeOut(duration: 0.25)) { zoomTo(zoom * 2.2, anchor: loc, size: size) }
                lastZoom = zoom; lastPan = pan
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height == nil ? 0 : Metrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}


/// The Journal's world map, full screen: pinch or use the buttons to zoom in, tap a place to open that country's map
/// with its appellations.
struct WorldMapFull: View {
    let dots: [MapDot]
    var shades: [CountryShade] = []
    var style: WineMapStyle = .dots
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismissEnv
    @Environment(\.coverClose) private var coverClose
    @State private var zoomCommand = 0
    @State private var picked: MapDot? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.sea.ignoresSafeArea()
            WorldTriedMap(dots: dots, shades: shades, style: style, selected: picked?.id, interactive: true, height: nil, zoomCommand: zoomCommand) { id in
                Haptics.tap()
                withAnimation(.easeOut(duration: 0.2)) { picked = dots.first { $0.id == id } }
            }
            .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("Your wine world", color: Palette.wine)
                Text("\(dots.count) \(dots.count == 1 ? "place" : "places")").font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Zoom in, then tap a place").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.focusLand.opacity(0.94)))
            .padding(.leading, 16).padding(.top, 10)
            VStack(spacing: 10) {
                button("xmark", "Close") { if let c = coverClose { c() } else { dismissEnv() } }
                Spacer().frame(height: 6)
                button("plus", "Zoom in") { zoomCommand += 1 }
                button("minus", "Zoom out") { zoomCommand -= 1 }
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 16).padding(.top, 10)
        }
        .overlay(alignment: .bottom) {
            if let d = picked { placeCard(d).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
    }

    /// The place you tapped: what you have from there, and its map.
    private func placeCard(_ d: MapDot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(d.color).frame(width: 10, height: 10)
                Text(d.name).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.ink)
                Text("\(d.count) \(d.count == 1 ? "wine" : "wines")").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { picked = nil } } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSoft)
                        .frame(width: 28, height: 28).background(Circle().fill(Palette.cardAlt))
                }
                .accessibilityLabel("Close")
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(d.titles.prefix(5).enumerated()), id: \.offset) { _, t in
                    Text(t).font(.system(size: 14)).foregroundStyle(Palette.ink).lineLimit(1)
                }
                if d.titles.count > 5 {
                    Text("and \(d.titles.count - 5) more").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
            }
            Button { onOpen(d.id) } label: {
                Label("Open the map of \(d.name)", systemImage: "map").font(.system(size: 14.5, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .foregroundStyle(Palette.onWine).background(Capsule().fill(Palette.wine))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func button(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42).background(Circle().fill(Palette.card))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .accessibilityLabel(label)
    }
}


/// Builds the heat layer as a small picture (about one cell per 3 points) that is drawn smoothly over the map.
enum HeatImage {
    // alpha-premultiplied colour stops: density (0...1) -> color
    private static let stops: [(Double, (Double, Double, Double, Double))] = [
        (0.00, (255, 226, 140, 0.0)), (0.10, (255, 214, 110, 0.14)), (0.28, (250, 180, 80, 0.42)), (0.50, (240, 120, 52, 0.60)),
        (0.75, (210, 52, 72, 0.74)), (1.00, (150, 16, 60, 0.85)),
    ]
    private static func color(_ t: Double) -> (UInt8, UInt8, UInt8, UInt8) {
        var lo = stops[0], hi = stops[stops.count - 1]
        for i in 1..<stops.count where t <= stops[i].0 { lo = stops[i - 1]; hi = stops[i]; break }
        let k = hi.0 == lo.0 ? 0 : max(0, min(1, (t - lo.0) / (hi.0 - lo.0)))
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        let a = mix(lo.1.3, hi.1.3)
        return (UInt8(max(0, min(255, mix(lo.1.0, hi.1.0) * a))), UInt8(max(0, min(255, mix(lo.1.1, hi.1.1) * a))),
                UInt8(max(0, min(255, mix(lo.1.2, hi.1.2) * a))), UInt8(max(0, min(255, a * 255))))
    }
    private static let lut: [(UInt8, UInt8, UInt8, UInt8)] = (0...255).map { color(Double($0) / 255) }
    /// One colour, Bordeaux, from clear to about 60%: calmer than the yellow-to-red scale.
    private static let monoLUT: [(UInt8, UInt8, UInt8, UInt8)] = (0...255).map { i in
        let a = 0.62 * pow(Double(i) / 255, 0.85)
        return (UInt8(139 * a), UInt8(21 * a), UInt8(56 * a), UInt8(a * 255))
    }

    static func make(points: [(CGPoint, Double)], size: CGSize, sigma: CGFloat, mono: Bool = false) -> CGImage? {
        let cell: CGFloat = 3
        let w = max(8, Int(size.width / cell)), h = max(8, Int(size.height / cell))
        var field = [Double](repeating: 0, count: w * h)
        let sg = Double(sigma / cell), reach = Int((sg * 3).rounded(.up))
        for (p, weight) in points where p.x.isFinite && p.y.isFinite && weight.isFinite {
            let cx = Double(p.x / cell), cy = Double(p.y / cell)
            let x0 = max(0, Int(cx) - reach), x1 = min(w - 1, Int(cx) + reach), y0 = max(0, Int(cy) - reach), y1 = min(h - 1, Int(cy) + reach)
            if x0 > x1 || y0 > y1 { continue }
            for y in y0...y1 {
                let dy = Double(y) + 0.5 - cy
                for x in x0...x1 {
                    let dx = Double(x) + 0.5 - cx
                    field[y * w + x] += weight * exp(-(dx * dx + dy * dy) / (2 * sg * sg))
                }
            }
        }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            let v = field[i]
            if !v.isFinite || v < 0.01 { continue }
            let t = 1 - exp(-1.25 * v)
            let c = (mono ? monoLUT : lut)[min(255, Int(t * 255))]
            px[i * 4] = c.0; px[i * 4 + 1] = c.1; px[i * 4 + 2] = c.2; px[i * 4 + 3] = c.3
        }
        guard let provider = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
}
