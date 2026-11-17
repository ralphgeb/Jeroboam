import SwiftUI

// MARK: - Brand mark: a grape cluster (six berries around one, plus one below)

struct GrapeMarkLayout {
    /// Centers in unit space where berry radius = 1; returns (center, toneIndex).
    static let berries: [(CGPoint, Int)] = {
        let g: CGFloat = 1.10
        var pts: [(CGPoint, Int)] = [(CGPoint(x: 0, y: 0), 0)]
        let tones = [1, 2, 1, 2, 1, 0]
        for (i, a) in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0].enumerated() {
            let r = a * Double.pi / 180
            pts.append((CGPoint(x: 2 * g * CGFloat(cos(r)), y: 2 * g * CGFloat(sin(r))), tones[i]))
        }
        pts.append((CGPoint(x: 0, y: 2 * g * CGFloat(3.0.squareRoot())), 0))
        return pts
    }()
    // bounds in unit space
    static let minX: CGFloat = -3.2, maxX: CGFloat = 3.2
    static let minY: CGFloat = -1.0 - 2 * 1.10 * 0.866 * 1, maxY: CGFloat = 1 + 2 * 1.10 * 1.7320508
}

struct GrapeMark: View {
    var tones: [Color] = [Color(hex: "#8B1538"), Color(hex: "#6A0F2B"), Color(hex: "#A82247")]
    /// Optional vertical gradient (top → bottom) instead of tones.
    var gradient: [Color]? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = GrapeMarkLayout.maxX - GrapeMarkLayout.minX
            let h = GrapeMarkLayout.maxY - GrapeMarkLayout.minY
            let s = min(size.width / w, size.height / h)
            let ox = size.width / 2
            let oy = (size.height - h * s) / 2 - GrapeMarkLayout.minY * s
            for (c, t) in GrapeMarkLayout.berries {
                let r = CGRect(x: ox + (c.x - 1) * s, y: oy + (c.y - 1) * s, width: 2 * s, height: 2 * s)
                var color = tones[t % tones.count]
                if let grad = gradient, grad.count >= 2 {
                    let f = Double((c.y - GrapeMarkLayout.minY - 1) / (GrapeMarkLayout.maxY - GrapeMarkLayout.minY - 2))
                    let x = max(0, min(1, f)) * Double(grad.count - 1)
                    let i = min(grad.count - 2, Int(x))
                    color = grad[i].mix(with: grad[i + 1], x - Double(i))
                }
                ctx.fill(Path(ellipseIn: r), with: .color(color))
            }
        }
        .aspectRatio((GrapeMarkLayout.maxX - GrapeMarkLayout.minX) / (GrapeMarkLayout.maxY - GrapeMarkLayout.minY), contentMode: .fit)
        .accessibilityHidden(true)
    }

    static func tones(for berry: BerryColor) -> [Color] {
        switch berry {
        case .black: return ["#4A1D3F", "#2F0F28", "#6B2D5C"].map { Color(hex: $0) }
        case .white: return ["#C7C25A", "#A9A43E", "#DCD77A"].map { Color(hex: $0) }
        case .pink: return ["#C46A82", "#A44E66", "#DB8EA2"].map { Color(hex: $0) }
        }
    }
}

/// App brand: grape mark (+ optional wordmark).
struct BrandDroplet: View {
    var size: CGFloat = 64
    var body: some View {
        GrapeMark(tones: [Palette.bordeaux, Color(hex: "#6A0F2B"), Color(hex: "#B0284F")])
            .frame(width: size * 0.62, height: size * 0.8)
    }
}

struct Wordmark: View {
    var size: CGFloat = 24
    var body: some View {
        HStack(spacing: size * 0.3) {
            BrandDroplet(size: size * 1.05)
            Text("JERO").font(.display(size, .black)).kerning(size * 0.06).foregroundStyle(Palette.ink)
        }
    }
}

/// Kept for the onboarding hero and older call sites.
struct DropletShape: Shape {
    func path(in r: CGRect) -> Path { Path(ellipseIn: r) }
}

// MARK: - Grape cluster illustration (same language as the logo)

struct GrapeCluster: View {
    var berry: BerryColor
    var tint: Color? = nil
    var leaf: Bool = false
    var seed: Int = 0

    var body: some View {
        if let t = tint {
            GrapeMark(tones: [t, t.mix(with: .black, 0.22), t.mix(with: .white, 0.18)])
        } else {
            GrapeMark(tones: GrapeMark.tones(for: berry))
        }
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) % 10_000) / 10_000
    }
}

/// Catmull-Rom smoothing through points (closed).
func smoothClosedPath(_ pts: [CGPoint], tension: CGFloat = 0.5) -> Path {
    var p = Path()
    guard pts.count > 2 else { return p }
    let n = pts.count
    p.move(to: pts[0])
    for i in 0..<n {
        let p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) * tension / 3, y: p1.y + (p2.y - p0.y) * tension / 3)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) * tension / 3, y: p2.y - (p3.y - p1.y) * tension / 3)
        p.addCurve(to: p2, control1: c1, control2: c2)
    }
    p.closeSubpath()
    return p
}

// MARK: - Wine glass (graphic: bold outline, straight stem, flat foot)

struct WineGlass: View {
    var color: Color
    var rim: Color? = nil
    var fill: CGFloat = 0.55
    var sparkling = false
    var outline: Color? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = min(size.width, size.height * 0.6)
            let h = w / 0.6
            let r = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            let lw = max(1.4, w * 0.055)
            let bowlBottom = r.minY + r.height * 0.6
            // bowl: straight-ish sides into a round bottom
            var bowl = Path()
            bowl.move(to: CGPoint(x: r.minX + w * 0.16, y: r.minY + lw / 2))
            bowl.addLine(to: CGPoint(x: r.maxX - w * 0.16, y: r.minY + lw / 2))
            bowl.addCurve(to: CGPoint(x: r.midX, y: bowlBottom),
                          control1: CGPoint(x: r.maxX - w * 0.02, y: r.minY + r.height * 0.36),
                          control2: CGPoint(x: r.maxX - w * 0.08, y: bowlBottom))
            bowl.addCurve(to: CGPoint(x: r.minX + w * 0.16, y: r.minY + lw / 2),
                          control1: CGPoint(x: r.minX + w * 0.08, y: bowlBottom),
                          control2: CGPoint(x: r.minX + w * 0.02, y: r.minY + r.height * 0.36))
            bowl.closeSubpath()
            ctx.fill(bowl, with: .color(Palette.card.opacity(0.6)))
            // wine with a gentle wave
            let top = bowlBottom - r.height * 0.56 * fill
            var clip = ctx
            clip.clip(to: bowl)
            var liquid = Path()
            liquid.move(to: CGPoint(x: r.minX - 4, y: top))
            liquid.addCurve(to: CGPoint(x: r.maxX + 4, y: top),
                            control1: CGPoint(x: r.minX + w * 0.35, y: top - r.height * 0.05),
                            control2: CGPoint(x: r.minX + w * 0.62, y: top + r.height * 0.05))
            liquid.addLine(to: CGPoint(x: r.maxX + 4, y: r.maxY))
            liquid.addLine(to: CGPoint(x: r.minX - 4, y: r.maxY))
            liquid.closeSubpath()
            clip.fill(liquid, with: .linearGradient(Gradient(colors: [rim ?? color.mix(with: .white, 0.15), color]),
                                                     startPoint: CGPoint(x: r.midX, y: top), endPoint: CGPoint(x: r.midX, y: bowlBottom)))
            if sparkling {
                var rng = SeededRandom(seed: 3)
                for _ in 0..<10 {
                    let bx = r.minX + w * (0.3 + 0.4 * CGFloat(rng.next()))
                    let by = top + CGFloat(rng.next()) * (bowlBottom - top) * 0.85 + 4
                    let br = w * 0.028 * CGFloat(0.6 + rng.next())
                    clip.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(.white.opacity(0.8)))
                }
            }
            let ink = outline ?? Palette.ink
            ctx.stroke(bowl, with: .color(ink), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            var stem = Path()
            stem.move(to: CGPoint(x: r.midX, y: bowlBottom))
            stem.addLine(to: CGPoint(x: r.midX, y: r.maxY - lw / 2))
            stem.move(to: CGPoint(x: r.midX - w * 0.28, y: r.maxY - lw / 2))
            stem.addLine(to: CGPoint(x: r.midX + w * 0.28, y: r.maxY - lw / 2))
            ctx.stroke(stem, with: .color(ink), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .aspectRatio(0.6, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Color-chart swatch: a rounded tile with a deep core fading to a paler rim.
struct ColorSwatch: View {
    let core: Color
    let rim: Color
    var corner: CGFloat = 14
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(RadialGradient(colors: [core, core.mix(with: rim, 0.55), rim], center: .center, startRadius: 2, endRadius: 70))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Palette.ink.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Bottles

enum BottleStyle { case bordeaux, burgundy, flute, sparkling, fortified }

struct BottleShape: Shape {
    var neck: CGFloat = 0.30
    var shoulder: CGFloat = 0.38
    var style: BottleStyle = .bordeaux

    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let nw = w * (style == .flute ? 0.36 : neck)
        let st = r.minY + h * shoulder
        let lipTop = r.minY
        p.move(to: CGPoint(x: r.midX - nw / 2, y: lipTop))
        p.addLine(to: CGPoint(x: r.midX + nw / 2, y: lipTop))
        switch style {
        case .bordeaux, .fortified:
            p.addLine(to: CGPoint(x: r.midX + nw / 2, y: st - h * 0.12))
            p.addCurve(to: CGPoint(x: r.maxX, y: st + h * 0.04),
                       control1: CGPoint(x: r.midX + nw / 2, y: st - h * 0.03),
                       control2: CGPoint(x: r.maxX, y: st - h * 0.04))
        case .burgundy, .sparkling:
            p.addLine(to: CGPoint(x: r.midX + nw / 2, y: st - h * 0.2))
            p.addCurve(to: CGPoint(x: r.maxX, y: st + h * 0.14),
                       control1: CGPoint(x: r.midX + nw / 2 + w * 0.08, y: st),
                       control2: CGPoint(x: r.maxX, y: st + h * 0.02))
        case .flute:
            p.addLine(to: CGPoint(x: r.midX + nw / 2, y: st - h * 0.14))
            p.addCurve(to: CGPoint(x: r.maxX, y: st + h * 0.2),
                       control1: CGPoint(x: r.midX + nw / 2 + w * 0.12, y: st + h * 0.04),
                       control2: CGPoint(x: r.maxX, y: st + h * 0.08))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - w * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.06, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.06, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - w * 0.06), control: CGPoint(x: r.minX, y: r.maxY))
        switch style {
        case .bordeaux, .fortified:
            p.addLine(to: CGPoint(x: r.minX, y: st + h * 0.04))
            p.addCurve(to: CGPoint(x: r.midX - nw / 2, y: st - h * 0.12),
                       control1: CGPoint(x: r.minX, y: st - h * 0.04),
                       control2: CGPoint(x: r.midX - nw / 2, y: st - h * 0.03))
        case .burgundy, .sparkling:
            p.addLine(to: CGPoint(x: r.minX, y: st + h * 0.14))
            p.addCurve(to: CGPoint(x: r.midX - nw / 2, y: st - h * 0.2),
                       control1: CGPoint(x: r.minX, y: st + h * 0.02),
                       control2: CGPoint(x: r.midX - nw / 2 - w * 0.08, y: st))
        case .flute:
            p.addLine(to: CGPoint(x: r.minX, y: st + h * 0.2))
            p.addCurve(to: CGPoint(x: r.midX - nw / 2, y: st - h * 0.14),
                       control1: CGPoint(x: r.minX, y: st + h * 0.08),
                       control2: CGPoint(x: r.midX - nw / 2 - w * 0.12, y: st + h * 0.04))
        }
        p.closeSubpath()
        return p
    }
}

/// A styled bottle with glass color and a minimal label.
struct BottleView: View {
    var style: BottleStyle
    var glass: Color
    var label: String
    var labelTint: Color = Palette.bordeaux

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                BottleShape(style: style)
                    .fill(LinearGradient(colors: [glass.mix(with: .white, 0.12), glass, glass.mix(with: .black, 0.25)],
                                         startPoint: .leading, endPoint: .trailing))
                // foil / capsule
                Rectangle().fill(style == .sparkling ? Color(hex: "#C9A54A") : labelTint)
                    .frame(width: w * 0.32, height: h * (style == .sparkling ? 0.2 : 0.12))
                    .position(x: w / 2, y: h * (style == .sparkling ? 0.1 : 0.06))
                // label
                VStack(spacing: h * 0.012) {
                    GrapeMark(tones: [labelTint, labelTint.mix(with: .black, 0.2), labelTint.mix(with: .white, 0.2)])
                        .frame(height: h * 0.07)
                    Text(label.uppercased())
                        .font(.system(size: max(6, w * 0.085), weight: .heavy).width(.condensed))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(hex: "#1A0A10"))
                        .lineLimit(3).minimumScaleFactor(0.6)
                        .padding(.horizontal, w * 0.06)
                    Rectangle().fill(labelTint).frame(width: w * 0.3, height: max(1, h * 0.004))
                }
                .frame(width: w * 0.86, height: h * 0.3)
                .background(Rectangle().fill(Color(hex: "#FBF7F2")))
                .position(x: w / 2, y: h * 0.66)
                // highlight
                Capsule().fill(.white.opacity(0.22)).frame(width: w * 0.06, height: h * 0.34).position(x: w * 0.18, y: h * 0.62)
            }
        }
        .aspectRatio(0.3, contentMode: .fit)
        .accessibilityHidden(true)
    }

    static func style(for g: Grape) -> BottleStyle {
        switch g.id {
        case "pinot-noir", "chardonnay", "gamay", "syrah", "grenache", "viognier", "nebbiolo", "chenin-blanc", "marsanne": return .burgundy
        case "riesling", "gewurztraminer", "pinot-blanc", "silvaner", "gruner-veltliner", "muscat", "pinot-grigio": return .flute
        case "glera", "meunier": return .sparkling
        case "palomino", "pedro-ximenez", "touriga-nacional": return .fortified
        default: return .bordeaux
        }
    }

    static func glass(for g: Grape) -> Color {
        switch g.berry {
        case .black: return Color(hex: "#241018")
        case .white: return g.sweetness >= 4 ? Color(hex: "#C9902E") : Color(hex: "#B9B66A")
        case .pink: return Color(hex: "#E8A5AE")
        }
    }
}

// MARK: - Taste profile bars (Wine Folly-style, animated fill)

struct ProfileBar: View {
    let title: String
    let value: Int          // 1...5
    let tint: Color
    var delay: Double = 0
    @State private var shown: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkSoft)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(height: 5)
                    Capsule().fill(tint).frame(width: max(5, w * shown), height: 5)
                    ForEach(1..<5, id: \.self) { i in
                        Rectangle().fill(Palette.card).frame(width: 2.5, height: 7).offset(x: w * CGFloat(i) / 5 - 1.25)
                    }
                }
            }
            .frame(height: 7)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(delay)) { shown = CGFloat(value) / 5 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)")
    }
}

/// Structure profile with Wine Folly-style wording and animated bars.
struct StructureBars: View {
    let grape: Grape

    var body: some View {
        let tint = WineCardView.tint(for: grape)
        VStack(alignment: .leading, spacing: 14) {
            ProfileBar(title: Self.sweetWord(grape.sweetness), value: grape.sweetness, tint: tint, delay: 0.0)
            ProfileBar(title: Self.scale(grape.body, "Body", light: "Light", full: "Full"), value: grape.body, tint: tint, delay: 0.08)
            if grape.berry == .black {
                ProfileBar(title: Self.scale(grape.tannin, "Tannin"), value: grape.tannin, tint: tint, delay: 0.16)
            }
            ProfileBar(title: Self.scale(grape.acidity, "Acidity"), value: grape.acidity, tint: tint, delay: 0.24)
            ProfileBar(title: Self.abv(grape.alcohol), value: grape.alcohol, tint: tint, delay: 0.32)
        }
    }

    static func scale(_ v: Int, _ what: String, light: String = "Low", full: String = "High") -> String {
        switch v {
        case ...1: return "\(light) \(what.lowercased())".capitalizedFirst
        case 2: return "Medium-\(light.lowercased()) \(what.lowercased())".capitalizedFirst
        case 3: return "Medium \(what.lowercased())".capitalizedFirst
        case 4: return "Medium-\(full.lowercased()) \(what.lowercased())".capitalizedFirst
        default: return "\(full) \(what.lowercased())".capitalizedFirst
        }
    }

    static func sweetWord(_ v: Int) -> String {
        switch v {
        case ...1: return "Dry"
        case 2: return "Off-dry"
        case 3: return "Medium-sweet"
        case 4: return "Sweet"
        default: return "Luscious"
        }
    }

    static func abv(_ v: Int) -> String {
        switch v {
        case ...1: return "Under 10% ABV"
        case 2: return "10–11.5% ABV"
        case 3: return "11.5–13.5% ABV"
        case 4: return "13.5–15% ABV"
        default: return "Over 15% ABV"
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Flavor icons (line icons per aroma family)

struct FlavorIcon: View {
    let aroma: String
    var size: CGFloat = 30

    var body: some View {
        let cat = ContentStore.shared.aromaCategory(forItem: aroma)
        let color = Color(hex: cat?.color ?? "#A08890").mix(with: .black, 0.1)
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let lw = s * 0.095
            let st = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)) }
            switch cat?.id ?? "" {
            case "red-fruit", "black-fruit":
                let r = s * 0.17
                for (dx, dy) in [(-0.18, 0.08), (0.18, 0.08), (0.0, -0.2)] {
                    ctx.stroke(circle(c.x + s * CGFloat(dx), c.y + s * CGFloat(dy), r), with: .color(color), style: st)
                }
                var stem = Path(); stem.move(to: CGPoint(x: c.x, y: c.y - s * 0.37)); stem.addLine(to: CGPoint(x: c.x + s * 0.1, y: c.y - s * 0.46))
                ctx.stroke(stem, with: .color(color), style: st)
            case "citrus":
                ctx.stroke(circle(c.x, c.y, s * 0.36), with: .color(color), style: st)
                var seg = Path()
                for k in 0..<6 {
                    let a = Double(k) * Double.pi / 3
                    seg.move(to: c); seg.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.26, y: c.y + CGFloat(sin(a)) * s * 0.26))
                }
                ctx.stroke(seg, with: .color(color), style: StrokeStyle(lineWidth: lw * 0.7, lineCap: .round))
            case "green-fruit", "stone-fruit", "tropical", "dried-fruit":
                ctx.stroke(circle(c.x, c.y + s * 0.06, s * 0.33), with: .color(color), style: st)
                var leaf = Path()
                leaf.move(to: CGPoint(x: c.x, y: c.y - s * 0.27))
                leaf.addQuadCurve(to: CGPoint(x: c.x + s * 0.28, y: c.y - s * 0.42), control: CGPoint(x: c.x + s * 0.06, y: c.y - s * 0.46))
                leaf.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s * 0.27), control: CGPoint(x: c.x + s * 0.24, y: c.y - s * 0.24))
                ctx.stroke(leaf, with: .color(color), style: st)
            case "floral":
                for k in 0..<5 {
                    let a = Double(k) * 2 * Double.pi / 5 - Double.pi / 2
                    ctx.stroke(circle(c.x + CGFloat(cos(a)) * s * 0.2, c.y + CGFloat(sin(a)) * s * 0.2, s * 0.15), with: .color(color), style: st)
                }
                ctx.fill(circle(c.x, c.y, s * 0.07), with: .color(color))
            default:
                ctx.draw(Text(Image(systemName: cat?.icon ?? "circle")).font(.system(size: s * 0.6, weight: .regular)).foregroundColor(color), at: c)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Aroma chip

struct AromaChip: View {
    let text: String
    var compact = false

    var body: some View {
        let cat = ContentStore.shared.aromaCategory(forItem: text)
        let tint = Color(hex: cat?.color ?? "#A08890")
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: compact ? 7 : 8, height: compact ? 7 : 8)
            Text(text).font(.system(size: compact ? 13 : 14, weight: .semibold)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(Palette.cardAlt))
    }
}

// MARK: - Game badges

struct FlameBadge: View {
    let count: Int
    var active = true
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: active ? "flame.fill" : "flame")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Palette.flame : Palette.inkFaint)
            Text("\(count)")
                .font(.numeric(size + 1, .bold))
                .foregroundStyle(active ? Palette.ink : Palette.inkSoft)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) day streak")
    }
}

struct XPBadge: View {
    let xp: Int
    var size: CGFloat = 15
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: size - 1, weight: .semibold)).foregroundStyle(Palette.brass)
            Text("\(xp)").font(.numeric(size + 1, .bold)).foregroundStyle(Palette.ink).lineLimit(1).contentTransition(.numericText())
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(xp) XP")
    }
}

/// A ring that fills toward the daily goal.
struct GoalRing: View {
    let progress: Double
    var lineWidth: CGFloat = 3
    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(progress >= 1 ? Palette.correct : Palette.pink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress >= 1 {
                Image(systemName: "checkmark").font(.system(size: lineWidth * 3, weight: .bold)).foregroundStyle(Palette.correct)
            }
        }
    }
}
