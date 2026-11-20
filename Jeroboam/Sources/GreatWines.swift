import SwiftUI

/// An icon wine to try, 25 per area (content/greatwines_more.txt + greatwines.yaml).
struct GreatWine: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let producer: String
    let region: String
    let zone: String
    let grapes: [String]
    let color: String
    let price: [Int]
    let scores: String
    let vintages: [String]
    let what: String
    let why: String
    var area: String = ""
    /// Real figures from Wine-Searcher when looked up: average price per bottle and aggregated critic score.
    var avgPrice: Int? = nil
    var criticScore: Int? = nil
    var source: String? = nil
    /// Grapes without their own page in the app, by name.
    var also: [String]? = nil
    /// A real photo of the bottle (Wikimedia Commons), shown on the detail page when there is one.
    var snapshot: String? = nil
    /// A real bottle photo (Wikimedia Commons) when one was found.
    var bottle: String? = nil

    static func == (a: GreatWine, b: GreatWine) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var regionInfo: Region? { ContentStore.shared.library.regions.first { $0.id == region } }
    var grapeInfos: [Grape] { grapes.compactMap { ContentStore.shared.grape($0) } }
    var verified: Bool { source != nil }
    /// A single number to sort and filter by: the real average when known, else the middle of the estimate.
    var priceValue: Int { avgPrice ?? (price.count == 2 ? (price[0] + price[1]) / 2 : 0) }
    /// The critic score to sort and filter by: the real score, else the top of the estimated range.
    var scoreValue: Int {
        if let c = criticScore { return c }
        let nums = scores.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return nums.max() ?? 0
    }
    /// "$920" when looked up, else the estimated range.
    var priceText: String {
        if let a = avgPrice { return a >= 1000 ? "$\(a / 1000),\(String(format: "%03d", a % 1000))" : "$\(a)" }
        guard price.count == 2 else { return "" }
        func f(_ v: Int) -> String { v >= 1000 ? "$\(v / 1000),\(String(format: "%03d", v % 1000))" : "$\(v)" }
        return "\(f(price[0]))–\(f(price[1]))"
    }
    var scoreText: String { criticScore.map { "\($0)" } ?? scores }

    var tint: Color {
        switch color {
        case "white": return Color(hex: "#E2CC72")
        case "sparkling": return Color(hex: "#E8D98E")
        case "sweet": return Color(hex: "#C98A2B")
        case "rose": return Color(hex: "#E79AA6")
        case "fortified": return Color(hex: "#D9B25C")
        default: return Color(hex: "#5E1023")
        }
    }
}

// MARK: - Studio packshot, drawn: the same white ground, framing and light for every bottle

enum BottleKind { case bordeaux, burgundy, champagne, flute }

/// A wine bottle outline in a unit rect (neck at the top).
struct WineBottleShape: Shape {
    let kind: BottleKind
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        // proportions per bottle type: neck width, where the shoulder starts and ends, body width
        let (neck, s0, s1, body): (CGFloat, CGFloat, CGFloat, CGFloat) = {
            switch kind {
            case .bordeaux: return (0.30, 0.30, 0.40, 1.0)
            case .burgundy: return (0.30, 0.22, 0.47, 1.0)
            case .champagne: return (0.30, 0.20, 0.48, 1.0)
            case .flute: return (0.36, 0.25, 0.56, 1.0)
            }
        }()
        let cx = r.midX, nh = w * neck / 2, bh = w * body / 2
        var p = Path()
        p.move(to: CGPoint(x: cx - nh * 1.08, y: r.minY))
        p.addLine(to: CGPoint(x: cx + nh * 1.08, y: r.minY))
        p.addLine(to: CGPoint(x: cx + nh * 1.08, y: r.minY + h * 0.025))
        p.addLine(to: CGPoint(x: cx + nh, y: r.minY + h * 0.035))
        p.addLine(to: CGPoint(x: cx + nh, y: r.minY + h * s0))
        if kind == .bordeaux {
            p.addCurve(to: CGPoint(x: cx + bh, y: r.minY + h * s1),
                       control1: CGPoint(x: cx + nh, y: r.minY + h * (s0 + 0.06)), control2: CGPoint(x: cx + bh, y: r.minY + h * (s1 - 0.05)))
        } else {
            p.addCurve(to: CGPoint(x: cx + bh, y: r.minY + h * s1),
                       control1: CGPoint(x: cx + nh, y: r.minY + h * (s0 + (s1 - s0) * 0.45)), control2: CGPoint(x: cx + bh, y: r.minY + h * (s1 - (s1 - s0) * 0.35)))
        }
        p.addLine(to: CGPoint(x: cx + bh, y: r.maxY - w * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx + bh - w * 0.06, y: r.maxY), control: CGPoint(x: cx + bh, y: r.maxY))
        p.addLine(to: CGPoint(x: cx - bh + w * 0.06, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: cx - bh, y: r.maxY - w * 0.06), control: CGPoint(x: cx - bh, y: r.maxY))
        p.addLine(to: CGPoint(x: cx - bh, y: r.minY + h * s1))
        if kind == .bordeaux {
            p.addCurve(to: CGPoint(x: cx - nh, y: r.minY + h * s0),
                       control1: CGPoint(x: cx - bh, y: r.minY + h * (s1 - 0.05)), control2: CGPoint(x: cx - nh, y: r.minY + h * (s0 + 0.06)))
        } else {
            p.addCurve(to: CGPoint(x: cx - nh, y: r.minY + h * s0),
                       control1: CGPoint(x: cx - bh, y: r.minY + h * (s1 - (s1 - s0) * 0.35)), control2: CGPoint(x: cx - nh, y: r.minY + h * (s0 + (s1 - s0) * 0.45)))
        }
        p.addLine(to: CGPoint(x: cx - nh, y: r.minY + h * 0.035))
        p.addLine(to: CGPoint(x: cx - nh * 1.08, y: r.minY + h * 0.025))
        p.closeSubpath()
        return p
    }
}

struct BottleShot: View {
    let wine: GreatWine
    var corner: CGFloat = 16

    private var kind: BottleKind {
        if wine.color == "sparkling" { return .champagne }
        if ["Germany", "Alsace", "Austria"].contains(wine.area) && wine.color != "red" { return .flute }
        if wine.grapes.first == "riesling" || wine.grapes.first == "gewurztraminer" { return .flute }
        switch wine.area {
        case "Burgundy", "Rhône", "Loire", "Piedmont", "Beaujolais", "Jura & Savoie", "Oregon & Washington": return .burgundy
        default:
            if wine.grapes.first == "pinot-noir" || wine.grapes.first == "chardonnay" { return .burgundy }
            return .bordeaux
        }
    }

    /// Glass color: dark green-black for reds, green for most whites, clear for Bordeaux whites, sweet wines and rosé, brown for some Rieslings.
    private var glass: Color {
        switch wine.color {
        case "red", "fortified": return Color(hex: "#18201A")
        case "sparkling": return Color(hex: "#24361F")
        case "rose": return wine.tint.opacity(0.85)
        case "sweet": return wine.tint
        default:
            if wine.area == "Germany" && ["rheingau", "pfalz"].contains(wine.region) { return Color(hex: "#5A3417") }
            if wine.area == "Bordeaux" || wine.area == "Spain" { return wine.tint }
            return Color(hex: "#56702E")
        }
    }

    private var capsule: Color {
        if wine.color == "sparkling" { return Color(hex: "#C9A54A") }
        let palette = ["#7A1328", "#1C1C1E", "#C9A54A", "#6B0F1A", "#2E3B2A", "#ECE6DA", "#8B1538", "#3A2A55"]
        let i = abs(wine.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }) % palette.count
        return Color(hex: palette[i])
    }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height * 0.84
            let W = H * (kind == .flute ? 0.24 : (kind == .champagne ? 0.30 : 0.28))
            let top = geo.size.height * 0.065
            let rect = CGRect(x: (geo.size.width - W) / 2, y: top, width: W, height: H)
            let capH = H * (kind == .champagne ? 0.36 : 0.17)
            ZStack(alignment: .topLeading) {
                // studio sweep: white wall, soft grey floor, a pool of light behind the bottle
                LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(hex: "#FAFAF9"), location: 0.62),
                                       .init(color: Color(hex: "#EFEEEC"), location: 1)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.white, .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.42),
                               startRadius: 0, endRadius: geo.size.width * 0.55)
                // ambient + contact shadows
                Ellipse().fill(Color.black.opacity(0.10))
                    .frame(width: W * 1.7, height: W * 0.22).blur(radius: W * 0.12)
                    .position(x: geo.size.width / 2, y: rect.maxY + W * 0.03)
                Ellipse().fill(Color.black.opacity(0.32))
                    .frame(width: W * 0.98, height: W * 0.07).blur(radius: W * 0.025)
                    .position(x: geo.size.width / 2, y: rect.maxY - W * 0.005)
                // glass body: dark edges, a soft core, a crisp key highlight on the left and a rim light on the right
                WineBottleShape(kind: kind)
                    .fill(LinearGradient(stops: [
                        .init(color: glass.mix(with: .black, 0.55), location: 0),
                        .init(color: glass.mix(with: .black, 0.15), location: 0.10),
                        .init(color: glass, location: 0.30),
                        .init(color: glass.mix(with: .black, 0.10), location: 0.55),
                        .init(color: glass.mix(with: .white, 0.10), location: 0.84),
                        .init(color: glass.mix(with: .black, 0.60), location: 1)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                // depth: the base and shoulder a touch darker
                WineBottleShape(kind: kind)
                    .fill(LinearGradient(stops: [.init(color: .black.opacity(0.0), location: 0.45),
                                                 .init(color: .black.opacity(0.22), location: 1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                // capsule / foil
                WineBottleShape(kind: kind)
                    .fill(LinearGradient(stops: [.init(color: capsule.mix(with: .black, 0.45), location: 0),
                                                 .init(color: capsule.mix(with: .white, 0.30), location: 0.24),
                                                 .init(color: capsule, location: 0.45),
                                                 .init(color: capsule.mix(with: .white, 0.12), location: 0.80),
                                                 .init(color: capsule.mix(with: .black, 0.50), location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: rect.width, height: rect.height)
                    .mask(alignment: .top) { Rectangle().frame(height: capH) }
                    .offset(x: rect.minX, y: rect.minY)
                // foil band at the bottom of the capsule
                Rectangle().fill(capsule.mix(with: .black, 0.35))
                    .frame(width: W * (kind == .champagne ? 0.62 : 0.31), height: max(0.6, H * 0.006))
                    .position(x: geo.size.width / 2, y: top + capH - H * 0.004)
                // label
                label(width: W)
                    .frame(width: W * (kind == .flute ? 0.86 : 0.84), height: H * (kind == .flute ? 0.24 : 0.30))
                    .position(x: geo.size.width / 2, y: top + H * (kind == .flute ? 0.73 : 0.70))
                // key highlight: a crisp narrow strip plus a soft glow beside it
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.55), .white.opacity(0.35), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(1, W * 0.035), height: H * 0.62)
                    .position(x: rect.minX + W * 0.22, y: top + H * 0.62)
                    .blendMode(.screen)
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.18), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: W * 0.12, height: H * 0.66).blur(radius: W * 0.02)
                    .position(x: rect.minX + W * 0.24, y: top + H * 0.62)
                    .blendMode(.screen)
                // highlight on the neck
                Capsule().fill(Color.white.opacity(0.35))
                    .frame(width: max(1, W * 0.025), height: H * 0.12)
                    .position(x: geo.size.width / 2 - W * 0.07, y: top + H * (kind == .bordeaux ? 0.24 : 0.22))
                    .blendMode(.screen)
                // rim light on the right edge
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.22), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(0.8, W * 0.02), height: H * 0.5)
                    .position(x: rect.maxX - W * 0.07, y: top + H * 0.66)
                    .blendMode(.screen)
                // a fine outline so the bottle never melts into the light ground
                WineBottleShape(kind: kind)
                    .stroke(Color.black.opacity(0.25), lineWidth: max(0.4, W * 0.006))
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
        .environment(\.colorScheme, .light)
    }

    private func label(width W: CGFloat) -> some View {
        let paper = wine.color == "sparkling" ? Color(hex: "#F6F1E4") : Color(hex: "#FBF8F1")
        let ink = Color(hex: "#1E1512")
        return VStack(spacing: W * 0.03) {
            Text(wine.producer.uppercased())
                .font(.system(size: W * 0.06, weight: .semibold, design: .serif)).kerning(W * 0.006)
                .foregroundStyle(Color(hex: "#5A4A40"))
                .lineLimit(1).minimumScaleFactor(0.5)
            HStack(spacing: W * 0.03) {
                Rectangle().fill(capsule.opacity(0.7)).frame(width: W * 0.12, height: max(0.5, W * 0.006))
                Circle().fill(capsule.opacity(0.8)).frame(width: W * 0.025, height: W * 0.025)
                Rectangle().fill(capsule.opacity(0.7)).frame(width: W * 0.12, height: max(0.5, W * 0.006))
            }
            Text(wine.name)
                .font(.system(size: W * 0.105, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.45)
            Text(wine.zone.components(separatedBy: " · ").last ?? "")
                .font(.system(size: W * 0.052, weight: .regular, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#7A6A5E")).lineLimit(1).minimumScaleFactor(0.5)
        }
        .padding(.horizontal, W * 0.07).padding(.vertical, W * 0.05)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Rectangle().fill(paper))
        .overlay(Rectangle().strokeBorder(capsule.opacity(0.35), lineWidth: max(0.5, W * 0.007)).padding(W * 0.025))
        // the label wraps around a cylinder: shade both edges, catch the light on the left
        .overlay(LinearGradient(stops: [.init(color: .black.opacity(0.28), location: 0), .init(color: .black.opacity(0.0), location: 0.16),
                                        .init(color: .white.opacity(0.18), location: 0.26), .init(color: .black.opacity(0.0), location: 0.40),
                                        .init(color: .black.opacity(0.0), location: 0.72), .init(color: .black.opacity(0.32), location: 1)],
                                startPoint: .leading, endPoint: .trailing))
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.10)).frame(height: max(0.5, W * 0.006)) }
    }
}

/// The picture used everywhere for a great wine: a real photo of the bottle when one exists
/// (Wikimedia Commons, credited on the detail page), otherwise a plain typographic tile. Never a drawing.
struct GreatWineImage: View {
    let wine: GreatWine
    var corner: CGFloat = 16
    /// Fill the frame so the label is what you see (list thumbnails); otherwise the whole bottle is shown.
    var zoomLabel = false
    var body: some View {
        Group {
            if let b = wine.bottle, let img = Photos.image(b) {
                Color.white
                    .overlay {
                        if zoomLabel { Image(uiImage: img).resizable().scaledToFill().scaleEffect(1.15).offset(y: 6) }
                        else { Image(uiImage: img).resizable().scaledToFit().padding(5) }
                    }
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(colors: [Palette.cardAlt, Palette.card], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 6) {
                        Text(wine.producer.uppercased()).font(.system(size: 9.5, weight: .semibold)).kerning(1.1)
                            .foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).lineLimit(2)
                        Hairline().frame(width: 24)
                        Text(wine.name).font(.serif(17)).foregroundStyle(Palette.ink).multilineTextAlignment(.center).lineLimit(3)
                    }
                    .padding(14)
                }
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Palette.line.opacity(0.5), lineWidth: 0.5))
    }
}

// MARK: - Screens

struct GreatWinesScreen: View {
    @State private var query = ""
    @State private var sort = Sort.featured
    @State private var band = Band.all
    @State private var minScore = 0
    enum Sort: String, CaseIterable { case featured = "Featured", priceUp = "Price: low to high", priceDown = "Price: high to low", rating = "Rating" }
    enum Band: String, CaseIterable {
        case all = "Any price", under50 = "Under $50", mid = "$50–150", over150 = "$150+"
        func matches(_ v: Int) -> Bool {
            switch self { case .all: return true; case .under50: return v < 50; case .mid: return v >= 50 && v <= 150; case .over150: return v > 150 }
        }
    }
    /// Countries are the main tabs; the areas inside them are the second row.
    static let countries: [(name: String, areas: [String])] = [
        ("France", ["Bordeaux", "Burgundy", "Champagne", "Rhône", "Loire", "Alsace", "Beaujolais", "Southern France", "Jura & Savoie"]),
        ("Italy", ["Piedmont", "Tuscany", "Veneto & the North East", "Southern Italy & Islands"]),
        ("Spain", ["Spain"]), ("Portugal", ["Portugal"]), ("Germany", ["Germany"]), ("Austria", ["Austria"]),
        ("Hungary", ["Hungary"]), ("Greece", ["Greece"]), ("Lebanon", ["Lebanon"]),
        ("USA", ["California", "Oregon & Washington"]), ("Chile & Argentina", ["Chile & Argentina"]),
        ("Australia", ["Australia"]), ("New Zealand", ["New Zealand"]), ("South Africa", ["South Africa"]),
    ]
    @State private var country = "France"
    @State private var sub: String? = nil
    @State private var applied = ""
    @State private var showLimit = false

    private static var searchKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return "jero.greatSearches.\(c.year ?? 0)-\(c.month ?? 0)"
    }
    static let freeSearches = 5
    private var searchesUsed: Int { UserDefaults.standard.integer(forKey: Self.searchKey) }

    /// Second-row choices: the areas of a country, or (for one-area countries) its regions.
    private func subChoices(_ wines: [GreatWine]) -> [String] {
        let areas = Self.countries.first { $0.name == country }?.areas ?? []
        if areas.count > 1 { return areas }
        var count: [String: Int] = [:]
        for w in wines where areas.contains(w.area) {
            if let r = w.zone.components(separatedBy: " · ").last, r != w.area { count[r, default: 0] += 1 }
        }
        let list = count.filter { $0.value >= 2 }.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
        return list.count >= 2 ? list : []
    }

    private func inCountry(_ w: GreatWine) -> Bool { (Self.countries.first { $0.name == country }?.areas ?? []).contains(w.area) }
    private func inSub(_ w: GreatWine) -> Bool {
        guard let s = sub else { return true }
        return w.area == s || w.zone.components(separatedBy: " · ").last == s
    }

    var body: some View {
        let wines = ContentStore.shared.library.great ?? []
        let q = applied.trimmingCharacters(in: .whitespaces)
        let shown = q.isEmpty ? wines.filter { inCountry($0) && inSub($0) }
            : wines.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.producer.localizedCaseInsensitiveContains(q) || $0.zone.localizedCaseInsensitiveContains(q) }
        let subs = subChoices(wines)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Atlas", title: "Great wines to try",
                             subtitle: "\(wines.count.formatted()) wines, country by country: what they are, why people love them, what they cost and how critics score them.")
                chipRow(Self.countries.map(\.name), selected: country, bold: true) { c in
                    withAnimation(.smooth(duration: 0.3)) { country = c; sub = nil; applied = ""; query = "" }
                }
                if !subs.isEmpty {
                    chipRow(["All"] + subs, selected: sub ?? "All", bold: false) { c in
                        withAnimation(.smooth(duration: 0.3)) { sub = c == "All" ? nil : c }
                    }
                }
                HStack {
                    SectionTitle(text: q.isEmpty ? (sub ?? country) : "Results for \u{201C}\(q)\u{201D}")
                    Spacer()
                    Text("\(shown.count) wines").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
                filterBar
                let rows = ordered(shown)
                if rows.isEmpty {
                    Text("No wines match these filters.").font(.system(size: 14)).foregroundStyle(Palette.inkSoft).padding(.vertical, 30)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, w in
                            NavigationLink(value: w) { row(w, last: i == rows.count - 1) }.buttonStyle(PressableStyle())
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line.opacity(0.5), lineWidth: 0.5))
                    .id(listIdentity)
                }
                Text("Average prices (per 750 ml, before tax) and critic scores come from Wine-Searcher where shown; others are marked as estimates. Bottle photos are shown where available.")
                    .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                Color.clear.frame(height: 10)
            }
            .padding(.horizontal, Metrics.margin)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: "great") } }
        .searchable(text: $query, prompt: Plus.shared.active ? "Search wines or producers" : "Search (\(max(0, Self.freeSearches - searchesUsed)) free this month)")
        .onSubmit(of: .search) { runSearch() }
        .onChange(of: query) { _, v in if v.isEmpty { applied = "" } }
    }

    private var listIdentity: String {
        var parts: [String] = [country]
        parts.append(sub ?? "")
        parts.append(applied)
        parts.append(sort.rawValue)
        parts.append(band.rawValue)
        parts.append(String(minScore))
        return parts.joined(separator: "|")
    }

    /// Free players get five searches a month; each submitted search counts as one.
    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { applied = ""; return }
        if Plus.shared.active { applied = q; return }
        if searchesUsed >= Self.freeSearches {
            applied = ""
            PaywallPresenter.shared.show("You've used your 5 free searches this month. Jero Plus makes searching unlimited.")
            return
        }
        UserDefaults.standard.set(searchesUsed + 1, forKey: Self.searchKey)
        applied = q
    }

    private func chipRow(_ items: [String], selected: String, bold: Bool, _ pick: @escaping (String) -> Void) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { a in
                        Button { pick(a) } label: {
                            Text(a).font(.system(size: bold ? 14.5 : 13.5, weight: bold ? .semibold : .medium))
                                .foregroundStyle(selected == a ? Palette.onWine : Palette.ink)
                                .padding(.horizontal, bold ? 15 : 12).padding(.vertical, bold ? 9 : 7)
                                .background(Capsule().fill(selected == a ? Palette.wine : Palette.cardAlt))
                        }
                        .buttonStyle(.plain).id(a)
                    }
                }
                .padding(.horizontal, Metrics.margin)
            }
            .padding(.horizontal, -Metrics.margin)
            .onChange(of: selected) { _, a in withAnimation { proxy.scrollTo(a, anchor: .center) } }
        }
    }

    private func ordered(_ ws: [GreatWine]) -> [GreatWine] {
        var r = ws.filter { band.matches($0.priceValue) && $0.scoreValue >= minScore }
        switch sort {
        case .featured: break
        case .priceUp: r.sort { $0.priceValue < $1.priceValue }
        case .priceDown: r.sort { $0.priceValue > $1.priceValue }
        case .rating: r.sort { $0.scoreValue > $1.scoreValue }
        }
        return r
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                } label: { chip("arrow.up.arrow.down", sort.rawValue, on: sort != .featured) }
                Menu {
                    Picker("Price", selection: $band) { ForEach(Band.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                } label: { chip("dollarsign.circle", band.rawValue, on: band != .all) }
                Menu {
                    Picker("Rating", selection: $minScore) {
                        Text("Any rating").tag(0); Text("90 and up").tag(90); Text("95 and up").tag(95)
                    }
                } label: { chip("star", minScore == 0 ? "Any rating" : "\(minScore)+", on: minScore != 0) }
            }
            .padding(.horizontal, Metrics.margin)
        }
        .padding(.horizontal, -Metrics.margin)
    }

    private func chip(_ icon: String, _ text: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 13.5, weight: .medium))
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(on ? Palette.onWine : Palette.ink)
        .padding(.horizontal, 12).frame(height: 34)
        .background(Capsule().fill(on ? Palette.wine : Palette.cardAlt))
    }

    private func row(_ w: GreatWine, last: Bool) -> some View {
        HStack(spacing: 12) {
            GreatWineImage(wine: w, corner: 10, zoomLabel: true).frame(width: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(w.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(w.producer).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) {
                Text(w.priceText).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                Text(w.scoreText).font(.system(size: 11.5, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(height: 21).background(Capsule().fill(Palette.bordeaux.opacity(0.92)))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 84) } }
    }

    private func tile(_ w: GreatWine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            GreatWineImage(wine: w)
                .overlay(alignment: .topTrailing) {
                    Text(w.scoreText).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                        .padding(.horizontal, 7).frame(height: 22)
                        .background(Capsule().fill(Palette.bordeaux.opacity(0.92)))
                        .padding(8)
                }
            Text(w.name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
            Text(w.producer).font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            Text(w.priceText).font(.system(size: 12.5, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
        }
    }
}

struct GreatWineDetail: View {
    let wine: GreatWine
    var body: some View {
        let w = wine
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 4) {
                        GreatWineImage(wine: w, corner: 22).frame(width: 195)
                        if let b = w.bottle, let c = Photos.creditLine(b) {
                            Text(c).font(.system(size: 9.5)).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center).frame(width: 195)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(w.zone, color: Palette.wine)
                        Text(w.name).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(w.producer).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        Spacer(minLength: 4)
                        stat(w.verified && w.avgPrice != nil ? "Average price" : "Price (estimate)", w.priceText, "tag")
                        stat(w.criticScore != nil ? "Critics (average)" : "Critics (estimate)", "\(w.scoreText)/100", "star.fill")
                        if let src = w.source, let url = URL(string: src) {
                            Link(destination: url) {
                                Label("Wine-Searcher", systemImage: "arrow.up.right.square").font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.wine)
                            }
                        }
                    }
                }
                block("What it is", w.what)
                block("Why people love it", w.why)
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Vintages to know")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(w.vintages, id: \.self) { v in
                            Text(v).font(.system(size: 13.5, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                                .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Palette.wineSoft))
                        }
                    }
                }
                if let also = w.also, !also.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(w.grapeInfos.isEmpty ? "Grapes" : "Also in the blend")
                        Text(also.joined(separator: " · ")).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                    }
                }
                if !w.grapeInfos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Grapes")
                        HStack(spacing: 14) {
                            ForEach(w.grapeInfos) { g in
                                VStack(spacing: 4) {
                                    GrapeBadge(grape: g, size: 54)
                                    Text(g.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                if let r = w.regionInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Where it’s from")
                        WineLocationMap(region: r)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    }
                }
                if let p = w.snapshot, Photos.image(p) != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "In the wild")
                        PhotoView(id: p, height: 260)
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Palette.wine).frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(t).font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
                Text(v).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
            }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            Text(text).font(.system(size: 16)).foregroundStyle(Palette.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: 16)
    }
}
