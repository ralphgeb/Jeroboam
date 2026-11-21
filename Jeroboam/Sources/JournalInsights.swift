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

    private var mapCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            let list = mapCountries
            Text("\(list.count) \(list.count == 1 ? "country" : "countries") · \(list.reduce(0) { $0 + $1.hl.count }) places tried")
                .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(list, id: \.country) { c in
                        Button { explore = MapRef(id: c.map, hl: c.hl) } label: {
                            ZStack(alignment: .bottomLeading) {
                                WineMapView(mapID: c.map, highlight: c.hl, showLabels: false, showCities: false, fill: true, solo: true)
                                    .frame(width: 250, height: 190).allowsHitTesting(false)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.country).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                                    Text("\(c.bottles) \(c.bottles == 1 ? "wine" : "wines") · \(c.hl.count) \(c.hl.count == 1 ? "place" : "places")")
                                        .font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(10)
                            }
                            .background(Palette.card)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    // MARK: charts

    private var chartGrid: some View {
        VStack(spacing: 14) {
            stylesCard
            bodyCard
            grapesCard
            ratingsCard
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
            Chart(top, id: \.0) { g, n in
                BarMark(x: .value("Wines", n), y: .value("Grape", g)).foregroundStyle(Palette.wine.opacity(0.85)).cornerRadius(5)
                    .annotation(position: .trailing) { Text("\(n)").font(.system(size: 11).monospacedDigit()).foregroundStyle(Palette.inkSoft) }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(1, top.count)) * 32 + 8)
        }
    }

    private var ratingsCard: some View {
        let pts = wines.compactMap { w in w.rating.map { (w.date, $0) } }.sorted { $0.0 < $1.0 }
        let avg = pts.isEmpty ? 0 : pts.map(\.1).reduce(0, +) / pts.count
        return card("Scores over time", pts.isEmpty ? "Taste a wine to start the line" : "Average \(avg) out of 100") {
            Chart(pts, id: \.0) { d, r in
                LineMark(x: .value("Date", d), y: .value("Score", r)).foregroundStyle(Palette.wine).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", d), y: .value("Score", r)).foregroundStyle(Palette.wine.opacity(0.12)).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", d), y: .value("Score", r)).foregroundStyle(Palette.wine).symbolSize(26)
            }
            .chartYScale(domain: 70...100)
            .frame(height: 130)
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
