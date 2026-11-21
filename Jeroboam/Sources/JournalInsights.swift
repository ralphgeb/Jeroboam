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
}

/// The Journal's closing section: a map of everywhere you have tasted, and a few charts about what you drink.
/// Until you have a few wines of your own it shows an example, clearly marked, so you can see how it will look.
struct JournalInsights: View {
    @Environment(JournalStore.self) private var journal
    @State private var explore: MapRef? = nil

    private var real: [InsightWine] {
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
        for b in journal.cellar where !b.wine.country.isEmpty {
            out.append(InsightWine(country: b.wine.country, region: b.wine.region, style: family(b.wine.style), grapes: b.wine.grapes,
                                   price: b.price?.average, body: bodyOf(b.wine), rating: b.roughRating, date: b.added))
        }
        for e in journal.entries where !e.wine.country.isEmpty {
            out.append(InsightWine(country: e.wine.country, region: e.wine.region, style: family(e.wine.style), grapes: e.wine.grapes,
                                   price: nil, body: e.body, rating: e.rating, date: e.date))
        }
        return out
    }

    private var useExample: Bool { real.count < 3 }
    private var wines: [InsightWine] { useExample ? Self.example : real }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(text: "Your wine world")
                if useExample {
                    Text("EXAMPLE").font(.system(size: 10, weight: .bold)).kerning(1)
                        .foregroundStyle(Palette.wine).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.wineSoft))
                }
            }
            if useExample {
                Text("This is how it will look. It fills in with the bottles you scan and the wines you taste.")
                    .font(.system(size: 13)).foregroundStyle(Palette.inkSoft).padding(.top, -16)
            }
            mapCards
            chartGrid
        }
        .railCover(item: $explore) { ref in MapExplorer(mapID: ref.id, highlight: ref.hl) }
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

    private static let places: [String: (Double, Double)] = [
        "pauillac": (45.20, -0.75), "margaux": (45.04, -0.67), "saint estephe": (45.26, -0.77), "saint julien": (45.15, -0.74), "medoc": (45.3, -0.9),
        "haut medoc": (45.2, -0.8), "bordeaux": (44.84, -0.58), "saint emilion": (44.89, -0.15), "pomerol": (44.93, -0.2), "sauternes": (44.54, -0.35),
        "graves": (44.6, -0.45), "pessac leognan": (44.75, -0.65), "burgundy": (47.0, 4.8), "chablis": (47.8, 3.8), "cote d or": (47.1, 4.9),
        "champagne": (49.05, 4.0), "sancerre": (47.33, 2.84), "loire": (47.4, 0.7), "chinon": (47.16, 0.24), "vouvray": (47.41, 0.8), "alsace": (48.2, 7.3),
        "chateauneuf du pape": (44.06, 4.83), "rhone": (45.0, 4.8), "hermitage": (45.07, 4.84), "cote rotie": (45.48, 4.78), "beaujolais": (46.1, 4.6),
        "provence": (43.5, 6.0), "languedoc": (43.5, 3.0), "jura": (46.8, 5.7),
        "barolo": (44.61, 7.94), "barbaresco": (44.73, 8.08), "piedmont": (44.7, 8.0), "chianti": (43.5, 11.3), "chianti classico": (43.45, 11.3),
        "montalcino": (43.06, 11.49), "tuscany": (43.4, 11.2), "bolgheri": (43.23, 10.6), "veneto": (45.5, 11.5), "sicily": (37.6, 14.0), "etna": (37.75, 15.0),
        "rioja": (42.4, -2.5), "ribera del duero": (41.65, -3.7), "priorat": (41.2, 0.8), "rias baixas": (42.4, -8.7), "penedes": (41.4, 1.7), "jerez": (36.7, -6.1),
        "douro": (41.15, -7.8), "vinho verde": (41.6, -8.4), "alentejo": (38.5, -7.9), "dao": (40.5, -7.9),
        "mosel": (49.95, 7.0), "rheingau": (50.0, 8.0), "pfalz": (49.3, 8.1), "rheinhessen": (49.8, 8.2), "wachau": (48.37, 15.4), "tokaj": (48.1, 21.4),
        "santorini": (36.4, 25.4), "napa valley": (38.5, -122.3), "napa": (38.5, -122.3), "sonoma": (38.5, -122.9), "willamette": (45.2, -123.1),
        "willamette valley": (45.2, -123.1), "walla walla": (46.1, -118.3), "paso robles": (35.6, -120.7),
        "mendoza": (-33.0, -68.8), "uco valley": (-33.6, -69.2), "maipo": (-33.7, -70.7), "colchagua": (-34.6, -71.2), "casablanca": (-33.3, -71.4),
        "barossa": (-34.55, 138.95), "barossa valley": (-34.55, 138.95), "mclaren vale": (-35.2, 138.55), "coonawarra": (-37.3, 140.8), "margaret river": (-33.95, 115.05),
        "hunter valley": (-32.8, 151.3), "yarra valley": (-37.7, 145.5), "marlborough": (-41.5, 173.9), "central otago": (-45.0, 169.2), "hawkes bay": (-39.6, 176.8),
        "stellenbosch": (-33.9, 18.85), "swartland": (-33.3, 18.7), "constantia": (-34.03, 18.42), "bekaa valley": (33.8, 35.9), "bekaa": (33.8, 35.9), "batroun": (34.25, 35.65),
    ]
    private static let countryCentre: [String: (Double, Double)] = [
        "france": (46.6, 2.3), "italy": (42.8, 12.5), "spain": (40.2, -3.7), "portugal": (39.7, -8.0), "germany": (50.5, 9.0), "austria": (47.6, 14.5),
        "hungary": (47.1, 19.5), "greece": (38.6, 22.5), "united states": (38.0, -120.5), "usa": (38.0, -120.5), "chile": (-34.5, -71.0),
        "argentina": (-33.5, -68.8), "australia": (-33.5, 140.0), "new zealand": (-41.5, 173.0), "south africa": (-33.6, 19.0), "lebanon": (33.9, 35.8),
    ]

    private struct Dot: Identifiable {
        let id: String
        let point: CGPoint
        let name: String
        let count: Int
        let map: String
        let highlight: Set<String>
    }

    private var dots: [Dot] {
        var by: [String: (WineKey, Int)] = [:]
        for w in wines {
            let key = norm(w.region).isEmpty ? norm(w.country) : norm(w.region)
            by[key, default: (WineKey(country: w.country, region: w.region), 0)].1 += 1
        }
        return by.compactMap { key, v in
            let loc = Self.places[key] ?? Self.countryCentre[norm(v.0.country)]
            guard let (lat, lon) = loc, let map = Self.mapOf[norm(v.0.country)] else { return nil }
            let name = v.0.region.isEmpty ? v.0.country : v.0.region
            return Dot(id: key, point: Self.mapPoint(lat: lat, lon: lon), name: name, count: v.1, map: map, highlight: tried(in: map, regions: [v.0.region]))
        }
        .sorted { $0.name < $1.name }
    }
    private struct WineKey { let country: String; let region: String }

    private var mapCards: some View {
        let list = dots
        return VStack(alignment: .leading, spacing: 10) {
            let countries = Set(wines.map { norm($0.country) }).count
            Text("\(countries) \(countries == 1 ? "country" : "countries") · \(list.count) \(list.count == 1 ? "place" : "places") tried. Pinch to zoom, tap a place to open it.")
                .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            WorldTriedMap(dots: list.map { ($0.id, $0.point, $0.name, $0.count) }) { id in
                if let d = list.first(where: { $0.id == id }) { explore = MapRef(id: d.map, hl: d.highlight) }
            }
        }
    }

    // MARK: charts

    private var chartGrid: some View {
        VStack(spacing: 14) {
            stylesCard
            bodyCard
            grapesCard
            priceCard
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
        return card("Reds and whites", "\(reds) of \(wines.count) are red") {
            HStack(spacing: 18) {
                Chart(counts, id: \.0) { s, n in
                    SectorMark(angle: .value("Wines", n), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(Self.styleColors[s] ?? Palette.wine)
                }
                .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(counts, id: \.0) { s, n in
                        HStack(spacing: 8) {
                            Circle().fill(Self.styleColors[s] ?? Palette.wine).frame(width: 9, height: 9)
                            Text(s.capitalized).font(.system(size: 14)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(n)").font(.system(size: 14).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
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

    private var grapesCard: some View {
        var tally: [String: Int] = [:]
        for w in wines { for g in w.grapes.prefix(2) { tally[g, default: 0] += 1 } }
        let top = tally.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5).map { ($0.key, $0.value) }
        return card("Your grapes", "The ones you reach for most") {
            let most = max(1, top.map(\.1).max() ?? 1)
            VStack(spacing: 9) {
                ForEach(top, id: \.0) { g, n in
                    HStack(spacing: 10) {
                        Text(g).font(.system(size: 13.5)).foregroundStyle(Palette.ink).lineLimit(1).frame(width: 120, alignment: .leading)
                        GeometryReader { geo in
                            Capsule().fill(Palette.wine.opacity(0.85)).frame(width: max(8, geo.size.width * CGFloat(n) / CGFloat(most)))
                        }
                        .frame(height: 12)
                        Text("\(n)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSoft).frame(width: 20, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var priceCard: some View {
        let ps = wines.compactMap(\.price)
        let tiers: [(String, Int)] = [("Under $20", ps.filter { $0 < 20 }.count), ("$20–50", ps.filter { $0 >= 20 && $0 < 50 }.count),
                                      ("$50–100", ps.filter { $0 >= 50 && $0 < 100 }.count), ("$100+", ps.filter { $0 >= 100 }.count)]
        return card("What you spend", ps.isEmpty ? "Scan a bottle to see its price" : "Typical bottle about US$\(Int(ps.sorted()[ps.count / 2]))") {
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
            InsightWine(country: c, region: r, style: s, grapes: g, price: p, body: b, rating: rt, date: d(day))
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
    let dots: [(id: String, point: CGPoint, name: String, count: Int)]
    let onOpen: (String) -> Void
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    private let g = MapGeometry.get("world")

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let mw = CGFloat(g?.map.w ?? 4800), mh = CGFloat(g?.map.h ?? 1755)
            // the whole world to start with; pinch to zoom in on a region
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
                for d in dots {
                    let p = CGPoint(x: origin.x + d.point.x * s, y: origin.y + d.point.y * s)
                    let r: CGFloat = 5 + min(5, CGFloat(d.count))
                    let halo = Path(ellipseIn: CGRect(x: p.x - r - 4, y: p.y - r - 4, width: 2 * (r + 4), height: 2 * (r + 4)))
                    ctx.fill(halo, with: .color(Palette.bordeaux.opacity(0.22)))
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(dot, with: .color(Palette.bordeaux))
                    ctx.stroke(dot, with: .color(.white), lineWidth: 1.4)
                    if zoom >= 2.2 {
                        var t = ctx
                        t.addFilter(.shadow(color: .white.opacity(0.95), radius: 2))
                        t.draw(Text(d.name).font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.ink), at: CGPoint(x: p.x, y: p.y + r + 9), anchor: .center)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { v in
                    let hit = dots.min { hypot(origin.x + $0.point.x * s - v.location.x, origin.y + $0.point.y * s - v.location.y)
                                         < hypot(origin.x + $1.point.x * s - v.location.x, origin.y + $1.point.y * s - v.location.y) }
                    if let h = hit, hypot(origin.x + h.point.x * s - v.location.x, origin.y + h.point.y * s - v.location.y) < 26 { onOpen(h.id) }
                }
            )
            .gesture(DragGesture(minimumDistance: 6).onChanged { pan = CGSize(width: lastPan.width + $0.translation.width, height: lastPan.height + $0.translation.height) }
                .onEnded { _ in lastPan = pan })
            .simultaneousGesture(MagnifyGesture().onChanged { zoom = min(10, max(1, lastZoom * $0.magnification)) }.onEnded { _ in lastZoom = zoom })
            .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.25)) { zoom = 1; lastZoom = 1; pan = .zero; lastPan = .zero } }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}
