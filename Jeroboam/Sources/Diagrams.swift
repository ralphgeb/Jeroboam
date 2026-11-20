import SwiftUI

// MARK: - Visual dispatcher

/// Renders a visual from a compact spec string used in the content, e.g. "map:bordeaux:medoc,pauillac".
struct VisualView: View {
    let spec: String
    var compact = false
    /// Question cards: show the picture but never the name that would give the answer away.
    var hideAnswers = false
    @State private var showMap: String? = nil

    var body: some View {
        let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
        let kind = parts.first ?? ""
        let arg = parts.count > 1 ? parts[1] : ""
        let extra = parts.count > 2 ? parts[2] : ""
        Group {
            switch kind {
            case "mapsolo":
                // one area kept on the map, everything else faded away: which one is it?
                WineMapView(mapID: arg, highlight: Set(extra.split(separator: ",").map(String.init)), showLabels: false, showCities: false,
                            fill: true, autoCallout: false, solo: true)
                    .frame(height: hideAnswers ? 220 : 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case "map" where !hideAnswers:
                LessonMap(mapID: arg, highlight: Set(extra.split(separator: ",").map(String.init)), compact: compact)
            case "map":
                let hl = Set(extra.split(separator: ",").map(String.init))
                WineMapView(mapID: arg, highlight: hl, showCities: !compact && !hideAnswers, labelScale: compact ? 0.9 : 1,
                            fill: true, autoCallout: !hideAnswers)
                    .frame(height: hideAnswers ? 200 : (compact ? 230 : 280))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if !hideAnswers {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft)
                                .padding(7)
                                .background(Circle().fill(Palette.card.opacity(0.9)))
                                .padding(8)
                        }
                    }
                    .onTapGesture { if !hideAnswers { showMap = arg } }
                    .fullScreenCover(item: Binding(get: { showMap.map { MapRef(id: $0, hl: hl) } }, set: { showMap = $0?.id })) { ref in
                        MapExplorer(mapID: ref.id, highlight: ref.hl)
                    }
            case "photo":
                PhotoView(id: arg, height: hideAnswers ? 170 : (compact ? 200 : 230))
            case "grape":
                if let g = ContentStore.shared.grape(arg), hideAnswers {
                    GrapeBadge(grape: g, size: 120, disc: false).frame(maxWidth: .infinity)
                } else if let g = ContentStore.shared.grape(arg) {
                  VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 18) {
                        GrapeBadge(grape: g, size: compact ? 96 : 128, disc: false)
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(g.berry == .white ? "White grape" : (g.berry == .pink ? "Pink-skinned grape" : "Black grape"))
                            Text(g.name).font(.serif(24)).foregroundStyle(Palette.ink)
                            FlowLayout(spacing: 6, lineSpacing: 6) {
                                ForEach(g.aromas.prefix(3), id: \.self) { AromaChip(text: $0, compact: true) }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if !compact { GrapeHomeMap(grape: g) }
                  }
                }
            case "glass":
                if let c = ContentStore.shared.color(arg), hideAnswers {
                    WineGlass(color: Color(hex: c.hex), rim: Color(hex: c.rim)).frame(height: 130).frame(maxWidth: .infinity)
                } else if let c = ContentStore.shared.color(arg) {
                    HStack(spacing: 18) {
                        WineGlass(color: Color(hex: c.hex), rim: Color(hex: c.rim)).frame(height: compact ? 110 : 150)
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(c.family == "rose" ? "Rosé" : c.family.capitalized)
                            Text(c.name).font(.serif(22)).foregroundStyle(Palette.ink)
                            Text(c.note).font(.system(size: 14)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            case "glassonly":
                if let c = ContentStore.shared.color(arg) {
                    WineGlass(color: Color(hex: c.hex), rim: Color(hex: c.rim)).frame(height: 170)
                }
            case "colors":
                ColorLadder(family: arg)
            case "profile":
                if let g = ContentStore.shared.grape(arg) { StructureBars(grape: g) }
            case "aromas":
                if let g = ContentStore.shared.grape(arg) {
                    FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(g.aromas, id: \.self) { AromaChip(text: $0) } }
                }
            case "wheel":
                AromaWheel(compact: true)
            case "label":
                if let l = ContentStore.shared.label(arg) {
                    WineLabelView(label: l, numbered: false).padding(.horizontal, 20).padding(.vertical, 6)
                }
            case "flow":
                if let f = ContentStore.shared.flow(arg) { FlowDiagram(flow: f, compact: compact) }
            case "diagram":
                diagram(arg)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder private func diagram(_ id: String) -> some View {
        switch id {
        case "vine-cycle": VineCycleDiagram()
        case "climate": ClimateDiagram()
        case "grape-anatomy": GrapeAnatomyDiagram()
        case "bottle-sizes": BottleSizesDiagram(compact: compact)
        case "serving-temps": ServingTempsDiagram()
        case "sweetness": SweetnessScale()
        case "solera": SoleraDiagram()
        case "wine-belt": WineBeltDiagram()
        case "glass-shapes": GlassShapesDiagram()
        case "three-colors": ThreeColorsDiagram()
        case "tannin-acid": TanninAcidDiagram()
        default: EmptyView()
        }
    }
}

struct MapRef: Identifiable { let id: String; let hl: Set<String> }

// MARK: - Color ladder

struct ColorLadder: View {
    let family: String
    var body: some View {
        let colors = ContentStore.shared.library.colors.filter { $0.family == family && $0.chart != true }
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(colors) { c in
                VStack(spacing: 8) {
                    WineGlass(color: Color(hex: c.hex), rim: Color(hex: c.rim), fill: 0.6).frame(height: 84)
                    Text(c.name).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Flow (process) diagram

struct FlowDiagram: View {
    let flow: Flow
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(flow.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(Palette.wineSoft).frame(width: 34, height: 34)
                            Image(systemName: step.icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.wine)
                        }
                        if i < flow.steps.count - 1 {
                            Rectangle().fill(Palette.line).frame(width: 1).frame(minHeight: 18, maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        if !compact || flow.steps.count <= 5 {
                            Text(rich(step.text)).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

// MARK: - Vine cycle

struct VineCycleDiagram: View {
    private let stages: [(String, String, Double, Double, String)] = [
        ("Dormancy", "Nov–Feb", 10.0, 2.0, "moon.zzz"),
        ("Budburst", "Mar–Apr", 2.0, 4.0, "leaf"),
        ("Flowering", "May–Jun", 4.0, 6.0, "camera.macro"),
        ("Fruit set", "Jun", 5.6, 6.6, "circle.grid.2x2"),
        ("Véraison", "Jul–Aug", 6.6, 8.0, "drop"),
        ("Harvest", "Sep–Oct", 8.0, 10.0, "basket"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2 - 30
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Palette.line), lineWidth: 10)
                    let tones: [Color] = [Palette.inkFaint, Palette.sage, Palette.sage.mix(with: Palette.brass, 0.5), Palette.brass, Palette.wine.opacity(0.7), Palette.wine]
                    for (i, st) in stages.enumerated() {
                        var a0 = st.2 / 12 * 360 - 90, a1 = st.3 / 12 * 360 - 90
                        if a1 < a0 { a1 += 360 }
                        a0 += 1.5; a1 -= 1.5
                        var p = Path()
                        p.addArc(center: c, radius: r, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
                        ctx.stroke(p, with: .color(tones[i]), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    }
                    let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
                    for (i, m) in months.enumerated() {
                        let a = (Double(i) + 0.5) / 12 * 2 * Double.pi - Double.pi / 2
                        let p = CGPoint(x: c.x + CGFloat(cos(a)) * (r + 20), y: c.y + CGFloat(sin(a)) * (r + 20))
                        ctx.draw(Text(m).font(.system(size: 10, weight: .medium)).foregroundColor(Palette.inkSoft), at: p)
                    }
                }
                VStack(spacing: 3) {
                    Text("NORTHERN HEMISPHERE").font(.system(size: 9.5, weight: .semibold)).kerning(0.8)
                        .foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
                    Text("The vine’s year").font(.serif(19)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text("South: shift six months").font(.system(size: 11)).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(width: 150)
            }
            .frame(height: 270)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                ForEach(stages, id: \.0) { st in
                    HStack(spacing: 8) {
                        Image(systemName: st.4).font(.system(size: 12)).foregroundStyle(Palette.wine).frame(width: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(st.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(st.1).font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Climate

struct ClimateDiagram: View {
    var body: some View {
        HStack(spacing: 12) {
            column("Cool climate", icon: "cloud.sun", tint: Palette.slate,
                   photos: ["grape-riesling", "grape-pinot-noir"],
                   rows: ["Higher acidity", "Lower alcohol", "Lighter body", "Green & citrus fruit", "Red fruit in reds"])
            column("Warm climate", icon: "sun.max", tint: Palette.brass,
                   photos: ["grape-grenache", "grape-syrah"],
                   rows: ["Lower acidity", "Higher alcohol", "Fuller body", "Stone & tropical fruit", "Black fruit in reds"])
        }
    }

    private func column(_ title: String, icon: String, tint: Color, photos: [String], rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(tint)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            HStack(spacing: 8) {
                ForEach(photos, id: \.self) { id in
                    if let img = Photos.image(id) {
                        Color.clear.frame(height: 78)
                            .overlay(Image(uiImage: img).resizable().scaledToFill())
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            ForEach(rows, id: \.self) { r in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(tint).frame(width: 4, height: 4).padding(.top, 6)
                    Text(r).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.08)))
    }
}

// MARK: - Grape anatomy

struct GrapeAnatomyDiagram: View {
    private let skin = Color(hex: "#4A2446"), pulp = Color(hex: "#E7E3B8"), seed = Color(hex: "#8A6A3C"), stem = Color(hex: "#7A6650")

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2 + 8)
                let rx: CGFloat = 62, ry: CGFloat = 70
                // stem and cap
                var st = Path(); st.move(to: CGPoint(x: c.x, y: c.y - ry + 2)); st.addQuadCurve(to: CGPoint(x: c.x + 16, y: c.y - ry - 26), control: CGPoint(x: c.x + 2, y: c.y - ry - 14))
                ctx.stroke(st, with: .color(stem), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                // skin
                let outer = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
                ctx.fill(outer, with: .radialGradient(Gradient(colors: [skin.opacity(0.9), skin]), center: c, startRadius: 10, endRadius: 80))
                // pulp
                let inner = Path(ellipseIn: CGRect(x: c.x - rx + 7, y: c.y - ry + 7, width: (rx - 7) * 2, height: (ry - 7) * 2))
                ctx.fill(inner, with: .radialGradient(Gradient(colors: [Color(hex: "#F4F1D2"), pulp, Color(hex: "#CFC88F")]), center: CGPoint(x: c.x - 8, y: c.y - 14), startRadius: 4, endRadius: 78))
                // seeds
                for (dx, dy, rot) in [(-16.0, 14.0, -24.0), (16.0, 14.0, 24.0), (0.0, -14.0, 0.0)] {
                    var t = ctx
                    t.translateBy(x: c.x + dx, y: c.y + dy); t.rotate(by: .degrees(rot))
                    var d = Path()
                    d.move(to: CGPoint(x: 0, y: -13)); d.addQuadCurve(to: CGPoint(x: 0, y: 13), control: CGPoint(x: 11, y: 3)); d.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: -11, y: 3))
                    t.fill(d, with: .linearGradient(Gradient(colors: [Color(hex: "#B38B4E"), seed]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 14)))
                }
                // highlight
                var h = Path(); h.addArc(center: c, radius: rx - 6, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
                ctx.stroke(h, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            .frame(width: 150, height: 190)
            VStack(alignment: .leading, spacing: 13) {
                part("Skin", "Color, tannin and aroma", skin)
                part("Pulp", "Water, sugar, acid", Color(hex: "#CFC88F"))
                part("Seeds", "Bitter, harsh tannin", seed)
                part("Stem", "Green, astringent tannin", stem)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private func part(_ name: String, _ text: String, _ c: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Capsule().fill(c).frame(width: 4, height: 30).padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(text).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
            }
        }
    }
}

// MARK: - Bottle sizes

struct BottleSizesDiagram: View {
    var compact = false
    private let sizes: [(String, String, Double)] = [
        ("Half", "0.375 L", 0.375), ("Standard", "0.75 L", 0.75), ("Magnum", "1.5 L", 1.5),
        ("Jeroboam", "3 L", 3), ("Rehoboam", "4.5 L", 4.5), ("Methuselah", "6 L", 6),
        ("Salmanazar", "9 L", 9), ("Balthazar", "12 L", 12), ("Nebuchadnezzar", "15 L", 15)
    ]
    var body: some View {
        let shown = compact ? Array(sizes.prefix(6)) : sizes
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(shown, id: \.0) { s in
                    let h = 34 + 112 * CGFloat(pow(s.2 / 15, 0.42))
                    VStack(spacing: 6) {
                        BottleShape(neck: 0.3)
                            .fill(s.0 == "Jeroboam" ? Palette.wine : Palette.ink.opacity(0.78))
                            .frame(width: h * 0.33, height: h)
                        Text(s.0).font(.system(size: 10.5, weight: s.0 == "Jeroboam" ? .bold : .medium))
                            .foregroundStyle(s.0 == "Jeroboam" ? Palette.wine : Palette.ink)
                        Text(s.1).font(.system(size: 10)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Serving temperatures

struct ServingTempsDiagram: View {
    private let rows: [(String, String, Double, Color)] = [
        ("Sweet wines", "6–8 °C", 7, Color(hex: "#D9B24C")),
        ("Sparkling", "6–10 °C", 8, Color(hex: "#E6DDA8")),
        ("Light whites & rosé", "7–10 °C", 8.5, Color(hex: "#DCD58F")),
        ("Fuller whites", "10–13 °C", 11.5, Color(hex: "#D7BE63")),
        ("Light reds", "13 °C", 13, Color(hex: "#A33A4C")),
        ("Medium & full reds", "15–18 °C", 16.5, Color(hex: "#5C1A33")),
    ]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.0) { r in
                HStack(spacing: 12) {
                    Text(r.0).font(.system(size: 13.5)).foregroundStyle(Palette.ink).frame(width: 128, alignment: .leading)
                    GeometryReader { geo in
                        let x = geo.size.width * CGFloat((r.2 - 4) / 16)
                        ZStack(alignment: .leading) {
                            Capsule().fill(LinearGradient(colors: [Palette.slate.opacity(0.35), Palette.flame.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 4)
                            Circle().fill(r.3).frame(width: 12, height: 12).overlay(Circle().stroke(Palette.card, lineWidth: 2)).offset(x: x - 6)
                        }
                        .frame(height: 12)
                    }
                    .frame(height: 12)
                    Text(r.1).font(.numeric(12, .medium)).foregroundStyle(Palette.inkSoft).frame(width: 58, alignment: .trailing)
                }
            }
            HStack {
                Text("Colder").font(.system(size: 11)).foregroundStyle(Palette.slate)
                Spacer()
                Text("Warmer").font(.system(size: 11)).foregroundStyle(Palette.flame)
            }
            .padding(.leading, 140).padding(.trailing, 70)
        }
    }
}

// MARK: - Sweetness

struct SweetnessScale: View {
    private let steps: [(String, String)] = [("Dry", "< 4 g/L"), ("Off-dry", "4–12"), ("Medium", "12–45"), ("Sweet", "45+")]
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.brass.opacity(0.2 + 0.25 * Double(i)))
                            .frame(height: 10)
                        Text(s.0).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(s.1).font(.system(size: 10.5)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            Text("Residual sugar: grape sugar left unfermented. Approximate guide for still wines.")
                .font(.system(size: 11.5)).foregroundStyle(Palette.inkFaint).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Solera

struct SoleraDiagram: View {
    var body: some View {
        VStack(spacing: 14) {
            Canvas { ctx, size in
                let rows = 3, cols = 4
                let bw = size.width / CGFloat(cols) - 8, bh: CGFloat = 30
                for r in 0..<rows {
                    for c in 0..<cols {
                        let x = CGFloat(c) * (bw + 8) + 4, y = CGFloat(r) * (bh + 12) + 4
                        let rect = CGRect(x: x, y: y, width: bw, height: bh)
                        let barrel = Path(roundedRect: rect, cornerRadius: bh / 2)
                        let tone = [Palette.brass.opacity(0.35), Palette.brass.opacity(0.55), Palette.brass.opacity(0.8)][r]
                        ctx.fill(barrel, with: .color(tone))
                        for f in [0.25, 0.75] {
                            var hoop = Path()
                            hoop.move(to: CGPoint(x: x + bw * CGFloat(f), y: y + 2))
                            hoop.addLine(to: CGPoint(x: x + bw * CGFloat(f), y: y + bh - 2))
                            ctx.stroke(hoop, with: .color(Palette.ink.opacity(0.25)), lineWidth: 1)
                        }
                    }
                    let label = ["Criadera 2 · youngest", "Criadera 1", "Solera · oldest"][r]
                    ctx.draw(Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(Palette.ink),
                             at: CGPoint(x: size.width / 2, y: CGFloat(r) * (bh + 12) + 4 + bh / 2))
                }
            }
            .frame(height: 3 * 42 + 4)
            HStack(spacing: 18) {
                label("arrow.down", "Wine moves down a tier as each one is part-emptied")
                label("arrow.up.right", "Bottled only from the bottom (solera) row")
            }
        }
    }
    private func label(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.wine)
            Text(text).font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Glass shapes

/// Distinct glass silhouettes drawn at the same height and line weight.
enum GlassKind { case red, white, flute

    /// (top width, widest width, widest at y, bowl bottom y) as fractions of the frame.
    var bowl: (CGFloat, CGFloat, CGFloat, CGFloat) {
        switch self {
        case .red: return (0.56, 0.92, 0.30, 0.56)
        case .white: return (0.46, 0.62, 0.26, 0.50)
        case .flute: return (0.30, 0.34, 0.22, 0.60)
        }
    }

    func bowlPath(in r: CGRect) -> Path {
        let (top, widest, wy, by) = bowl
        let cx = r.midX
        let y0 = r.minY + r.height * 0.02, ym = r.minY + r.height * wy, yb = r.minY + r.height * by
        let tw = r.width * top / 2, mw = r.width * widest / 2
        var p = Path()
        p.move(to: CGPoint(x: cx - tw, y: y0))
        p.addCurve(to: CGPoint(x: cx, y: yb), control1: CGPoint(x: cx - mw * 1.02, y: ym - (ym - y0) * 0.1),
                   control2: CGPoint(x: cx - mw * 0.95, y: yb))
        p.addCurve(to: CGPoint(x: cx + tw, y: y0), control1: CGPoint(x: cx + mw * 0.95, y: yb),
                   control2: CGPoint(x: cx + mw * 1.02, y: ym - (ym - y0) * 0.1))
        return p
    }
}

struct ShapedGlass: View {
    let kind: GlassKind
    var color: Color
    var fill: CGFloat = 0.45
    var sparkling = false

    var body: some View {
        SilhouetteGlass(shape: kind == .red ? .red : (kind == .white ? .white : .flute), color: color, fill: fill, sparkling: sparkling)
    }
}

struct GlassShapesDiagram: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 26) {
            item("Red", .red, Color(hex: "#7A1E3A"))
            item("White", .white, Color(hex: "#E1D58E"))
            item("Sparkling", .flute, Color(hex: "#EADFA6"), sparkling: true)
        }
        .frame(maxWidth: .infinity)
    }
    private func item(_ name: String, _ k: GlassKind, _ c: Color, sparkling: Bool = false) -> some View {
        VStack(spacing: 8) {
            ShapedGlass(kind: k, color: c, fill: sparkling ? 0.72 : 0.42, sparkling: sparkling).frame(height: 130)
            Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft)
        }
    }
}

/// White, rosé and red, each in its usual glass.
struct ThreeColorsDiagram: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 26) {
            item("White", .white, Color(hex: "#E3D48A"))
            item("Rosé", .white, Color(hex: "#EBA3A0"))
            item("Red", .red, Color(hex: "#7A1E3A"))
        }
        .frame(maxWidth: .infinity)
    }
    private func item(_ name: String, _ k: GlassKind, _ c: Color) -> some View {
        VStack(spacing: 8) {
            ShapedGlass(kind: k, color: c, fill: 0.42).frame(height: 130)
            Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft)
        }
    }
}

// MARK: - Tannin vs acidity sensation

struct TanninAcidDiagram: View {
    var body: some View {
        HStack(spacing: 12) {
            item("Acidity", "mouth.fill", "Makes your mouth water; a sharp, fresh tingle on the sides of the tongue.")
            item("Tannin", "hand.raised.fill", "Dries and grips the gums and teeth, like strong black tea.")
        }
    }
    private func item(_ t: String, _ icon: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Palette.wine)
            Text(t).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(d).font(.system(size: 13)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardAlt))
    }
}

// MARK: - Photos (openly licensed, bundled in Resources/Photos with credits.json)

enum Photos {
    struct Credit: Decodable { let title: String; let license: String; let artist: String }
    private static var cache: [String: UIImage] = [:]
    static let credits: [String: Credit] = {
        guard let url = Bundle.main.url(forResource: "credits", withExtension: "json", subdirectory: "Photos"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Credit].self, from: data)) ?? [:]
    }()
    static func image(_ id: String) -> UIImage? {
        if let i = cache[id] { return i }
        guard let url = Bundle.main.url(forResource: id, withExtension: "jpg", subdirectory: "Photos"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[id] = img
        return img
    }
    static func creditLine(_ id: String) -> String? {
        guard let c = credits[id] else { return nil }
        let who = c.artist.isEmpty ? "Wikimedia Commons" : c.artist
        return "Photo: \(who) · \(c.license)"
    }
}

struct PhotoView: View {
    let id: String
    var height: CGFloat = 220
    var body: some View {
        if let img = Photos.image(id) {
            VStack(alignment: .leading, spacing: 5) {
                Color.clear
                    .frame(height: height)
                    .overlay(Image(uiImage: img).resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if let c = Photos.creditLine(id) {
                    Text(c).font(.system(size: 10)).foregroundStyle(Palette.inkFaint).lineLimit(1)
                }
            }
        }
    }
}
