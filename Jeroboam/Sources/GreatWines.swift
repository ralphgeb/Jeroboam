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
    /// Grapes without their own page in the app, by name.
    var also: [String]? = nil
    /// A real photo of the bottle (Wikimedia Commons), shown on the detail page when there is one.
    var snapshot: String? = nil

    static func == (a: GreatWine, b: GreatWine) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var regionInfo: Region? { ContentStore.shared.library.regions.first { $0.id == region } }
    var grapeInfos: [Grape] { grapes.compactMap { ContentStore.shared.grape($0) } }
    var priceText: String {
        guard price.count == 2 else { return "" }
        func f(_ v: Int) -> String { v >= 1000 ? "$\(v / 1000),\(String(format: "%03d", v % 1000))" : "$\(v)" }
        return "\(f(price[0]))–\(f(price[1]))"
    }
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
            let H = geo.size.height * 0.86
            let W = H * (kind == .flute ? 0.24 : (kind == .champagne ? 0.30 : 0.28))
            let top = geo.size.height * 0.07
            let rect = CGRect(x: (geo.size.width - W) / 2, y: top, width: W, height: H)
            ZStack(alignment: .topLeading) {
                Color.white
                // floor shadow
                Ellipse().fill(Color.black.opacity(0.13))
                    .frame(width: W * 1.15, height: W * 0.18)
                    .blur(radius: W * 0.06)
                    .position(x: geo.size.width / 2, y: rect.maxY + W * 0.02)
                // the glass
                WineBottleShape(kind: kind)
                    .fill(LinearGradient(stops: [.init(color: glass.mix(with: .black, 0.35), location: 0),
                                                 .init(color: glass, location: 0.28), .init(color: glass.mix(with: .white, 0.08), location: 0.45),
                                                 .init(color: glass.mix(with: .black, 0.45), location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                // capsule / foil
                WineBottleShape(kind: kind)
                    .fill(LinearGradient(colors: [capsule.mix(with: .black, 0.3), capsule.mix(with: .white, 0.25), capsule.mix(with: .black, 0.35)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: rect.width, height: rect.height)
                    .mask(alignment: .top) { Rectangle().frame(height: H * (kind == .champagne ? 0.36 : 0.17)) }
                    .offset(x: rect.minX, y: rect.minY)
                // label
                label(width: W)
                    .frame(width: W * (kind == .flute ? 0.86 : 0.84), height: H * (kind == .flute ? 0.24 : 0.30))
                    .position(x: geo.size.width / 2, y: top + H * (kind == .flute ? 0.73 : 0.70))
                // highlight
                RoundedRectangle(cornerRadius: W * 0.04)
                    .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.32), .white.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: W * 0.07, height: H * 0.7)
                    .position(x: rect.minX + W * 0.2, y: top + H * 0.6)
                    .blendMode(.screen)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
    }

    private func label(width W: CGFloat) -> some View {
        let paper = wine.color == "sparkling" ? Color(hex: "#F6F1E4") : Color(hex: "#FBF8F1")
        return VStack(spacing: W * 0.035) {
            Text(wine.producer.uppercased())
                .font(.system(size: W * 0.065, weight: .semibold, design: .serif)).kerning(W * 0.004)
                .foregroundStyle(Color(hex: "#5A4A40"))
                .lineLimit(1).minimumScaleFactor(0.5)
            Rectangle().fill(capsule.opacity(0.8)).frame(width: W * 0.28, height: max(0.5, W * 0.008))
            Text(wine.name)
                .font(.system(size: W * 0.11, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: "#1E1512"))
                .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.45)
            Text(wine.zone.components(separatedBy: " · ").last ?? "")
                .font(.system(size: W * 0.055, weight: .regular, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#7A6A5E")).lineLimit(1).minimumScaleFactor(0.5)
        }
        .padding(.horizontal, W * 0.06).padding(.vertical, W * 0.05)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Rectangle().fill(paper))
        .overlay(Rectangle().strokeBorder(capsule.opacity(0.35), lineWidth: max(0.5, W * 0.008)).padding(W * 0.025))
    }
}

/// The picture used everywhere for a great wine: the studio packshot.
struct GreatWineImage: View {
    let wine: GreatWine
    var corner: CGFloat = 16
    var body: some View { BottleShot(wine: wine, corner: corner) }
}

// MARK: - Screens

struct GreatWinesScreen: View {
    @State private var area: String = "Bordeaux"
    @State private var query = ""
    /// Areas grouped by country, France first.
    static let order = ["Bordeaux", "Burgundy", "Champagne", "Rhône", "Loire", "Alsace", "Beaujolais", "Southern France", "Jura & Savoie",
                        "Piedmont", "Tuscany", "Veneto & the North East", "Southern Italy & Islands", "Spain", "Portugal", "Germany",
                        "Austria", "Hungary", "Greece", "Lebanon", "California", "Oregon & Washington", "Chile & Argentina",
                        "Australia", "New Zealand", "South Africa"]
    var body: some View {
        let wines = ContentStore.shared.library.great ?? []
        let present = Set(wines.map(\.area))
        let areas = Self.order.filter(present.contains) + present.subtracting(Self.order).sorted()
        let q = query.trimmingCharacters(in: .whitespaces)
        let shown = q.isEmpty ? wines.filter { $0.area == area }
            : wines.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.producer.localizedCaseInsensitiveContains(q) || $0.zone.localizedCaseInsensitiveContains(q) }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "Atlas", title: "Great wines to try",
                             subtitle: "\(wines.count.formatted()) wines across \(areas.count) areas: what they are, why people love them, what they cost and how critics score them.")
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(areas, id: \.self) { a in
                                Button { withAnimation(.smooth(duration: 0.3)) { area = a } } label: {
                                    Text(a).font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(area == a ? Palette.onWine : Palette.ink)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(area == a ? Palette.wine : Palette.cardAlt))
                                }
                                .buttonStyle(.plain).id(a)
                            }
                        }
                        .padding(.horizontal, Metrics.margin)
                    }
                    .padding(.horizontal, -Metrics.margin)
                    .onChange(of: area) { _, a in withAnimation { proxy.scrollTo(a, anchor: .center) } }
                }
                HStack {
                    SectionTitle(text: q.isEmpty ? area : "Results")
                    Spacer()
                    Text("\(shown.count) wines").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)], spacing: 16) {
                    ForEach(shown) { w in
                        NavigationLink(value: w) { tile(w) }.buttonStyle(PressableStyle())
                    }
                }
                .id(area)
                .transition(.opacity)
                Text("Prices are a rough US retail guide for a recent release; scores are the usual range critics give recent vintages. Bottles are drawn illustrations, not the producers' labels.")
                    .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                Color.clear.frame(height: 10)
            }
            .padding(.horizontal, Metrics.margin)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: "great") } }
        .searchable(text: $query, prompt: "Search 1,000 wines or producers")
    }

    private func tile(_ w: GreatWine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            GreatWineImage(wine: w)
                .overlay(alignment: .topTrailing) {
                    Text(w.scores).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.white)
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
                    GreatWineImage(wine: w, corner: 20).frame(width: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(w.zone, color: Palette.wine)
                        Text(w.name).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(w.producer).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        Spacer(minLength: 4)
                        stat("Price", w.priceText, "tag")
                        stat("Critics", "\(w.scores) pts", "star.fill")
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
