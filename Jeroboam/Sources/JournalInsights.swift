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
    @State private var showWorld = false

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
        .railCover(isPresented: $showWorld) {
            let list = dots
            WorldMapFull(dots: list.map { ($0.id, $0.point, $0.name, $0.count) }) { id in
                showWorld = false
                if let d = list.first(where: { $0.id == id }) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { explore = MapRef(id: d.map, hl: d.highlight) } }
            }
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

    private struct Dot: Identifiable {
        let id: String
        let point: CGPoint
        let name: String
        let count: Int
        let map: String
        let highlight: Set<String>
    }

    /// One dot per place you have wine from, at the real centre of that place (the atlas and "beyond the atlas" maps know where
    /// every region is); a wine whose region is not known is not drawn rather than drawn in the wrong place.
    private var dots: [Dot] {
        var by: [String: (Region, Int)] = [:]
        for w in wines {
            var found = ContentStore.shared.regionMatching(w.region, country: w.country)
            if let f = found, ContentStore.shared.coordinate(of: f) == nil { found = ContentStore.shared.regionMatching("", country: w.country) }
            guard let r = found, ContentStore.shared.coordinate(of: r) != nil else { continue }
            by[r.id, default: (r, 0)].1 += 1
        }
        return by.values.compactMap { r, n -> Dot? in
            guard let c = ContentStore.shared.coordinate(of: r), let map = r.map else { return nil }
            return Dot(id: r.id, point: Self.mapPoint(lat: c.lat, lon: c.lon), name: r.name, count: n, map: map,
                       highlight: Set(r.highlight ?? (r.kind == "country" ? [] : [r.id])))
        }
        .sorted { $0.name < $1.name }
    }

    private var mapCards: some View {
        let list = dots
        return VStack(alignment: .leading, spacing: 10) {
            let countries = Set(wines.map { norm($0.country) }).count
            Text("\(countries) \(countries == 1 ? "country" : "countries") · \(list.count) \(list.count == 1 ? "place" : "places") tried. Tap the map to open it, zoom in and tap a place for its appellations.")
                .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            Button { showWorld = true } label: {
                WorldTriedMap(dots: list.map { ($0.id, $0.point, $0.name, $0.count) }, interactive: false, height: 190) { _ in }
                    .overlay(alignment: .bottomTrailing) {
                        Label("Open the map", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.wine)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule()).padding(10)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: charts

    private var chartGrid: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                stylesCard
                topGrapeCard
            }
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
        return card("Your grape", top == nil ? "Taste a wine to find it" : "The one you pick most") {
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
                // heat: soft glows that add up where bottles are close together, then a crisp dot at the exact place
                let heatScale = min(1 + (zoom - 1) * 0.25, 2.6)
                let hot = Color(hex: "#C21A4C"), warm = Color(hex: "#EA6A2E"), glow = Color(hex: "#F5B13D")
                for d in dots {
                    let p = CGPoint(x: origin.x + d.point.x * s, y: origin.y + d.point.y * s)
                    let rad = (15 + 8 * sqrt(CGFloat(d.count))) * heatScale
                    let grad = Gradient(stops: [.init(color: hot.opacity(0.78), location: 0), .init(color: warm.opacity(0.42), location: 0.42),
                                                .init(color: glow.opacity(0.14), location: 0.75), .init(color: glow.opacity(0), location: 1)])
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - rad, y: p.y - rad, width: 2 * rad, height: 2 * rad)),
                             with: .radialGradient(grad, center: p, startRadius: 0, endRadius: rad))
                }
                var taken: [CGRect] = []
                for d in dots.sorted(by: { $0.count > $1.count }) {
                    let p = CGPoint(x: origin.x + d.point.x * s, y: origin.y + d.point.y * s)
                    let r: CGFloat = 3.6
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(dot, with: .color(Palette.bordeaux))
                    ctx.stroke(dot, with: .color(.white), lineWidth: 1.2)
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
    let dots: [(id: String, point: CGPoint, name: String, count: Int)]
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismissEnv
    @Environment(\.coverClose) private var coverClose
    @State private var zoomCommand = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.sea.ignoresSafeArea()
            WorldTriedMap(dots: dots, interactive: true, height: nil, zoomCommand: zoomCommand, onOpen: onOpen).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("Your wine world", color: Palette.wine)
                Text("\(dots.count) \(dots.count == 1 ? "place" : "places") tried").font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Zoom in, then tap a place").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.focusLand.opacity(0.94)))
            .padding(.leading, 16).padding(.top, 10)
            VStack(spacing: 10) {
                button("xmark") { if let c = coverClose { c() } else { dismissEnv() } }
                Spacer().frame(height: 6)
                button("plus") { zoomCommand += 1 }
                button("minus") { zoomCommand -= 1 }
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 16).padding(.top, 10)
        }
    }

    private func button(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42).background(Circle().fill(Palette.card))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
    }
}
