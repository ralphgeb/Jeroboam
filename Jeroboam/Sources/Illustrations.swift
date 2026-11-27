import SwiftUI

// MARK: - Brand mark: a grape cluster resting on its side (rows 2 · 3 · 3, bottom row shifted right) with a stem and leaf

struct GrapeMarkLayout {
    static let d: CGFloat = 2.12            // berry spacing (radius = 1)
    static let dy: CGFloat = d * 0.866
    /// Berry centers in unit space; returns (center, toneIndex).
    static let berries: [(CGPoint, Int)] = [
        (CGPoint(x: 0.5 * d, y: 0), 2), (CGPoint(x: 1.5 * d, y: 0), 1),
        (CGPoint(x: 0, y: dy), 1), (CGPoint(x: d, y: dy), 0), (CGPoint(x: 2 * d, y: dy), 2),
        (CGPoint(x: 0.5 * d, y: 2 * dy), 0), (CGPoint(x: 1.5 * d, y: 2 * dy), 1), (CGPoint(x: 2.5 * d, y: 2 * dy), 0),
    ]
    /// Stem rises from between the two top berries; the leaf sits on it, to the right.
    static let stemBase = CGPoint(x: d, y: -0.55)
    static let stemTop = CGPoint(x: d + 0.25, y: -2.0)
    static let leafBase = CGPoint(x: d + 0.2, y: -1.55)
    static let leafTip = CGPoint(x: d + 2.8, y: -2.75)
    static let leafWidth: CGFloat = 0.95
    static let minX: CGFloat = -1, maxX: CGFloat = 2.5 * d + 1
    static let minY: CGFloat = leafTip.y - 0.9, maxY: CGFloat = 2 * dy + 1

    /// Pointed leaf from base to tip (unit space).
    static func leaf(_ t: (CGPoint) -> CGPoint) -> Path {
        let a = leafBase, b = leafTip
        let dx = b.x - a.x, dyy = b.y - a.y
        let len = (dx * dx + dyy * dyy).squareRoot()
        let nx = -dyy / len * leafWidth * 1.35, ny = dx / len * leafWidth * 1.35
        let m1 = CGPoint(x: a.x + dx * 0.42 + nx, y: a.y + dyy * 0.42 + ny)
        let m2 = CGPoint(x: a.x + dx * 0.42 - nx, y: a.y + dyy * 0.42 - ny)
        var p = Path()
        p.move(to: t(a))
        p.addQuadCurve(to: t(b), control: t(m1))
        p.addQuadCurve(to: t(a), control: t(m2))
        p.closeSubpath()
        return p
    }
}

struct GrapeMark: View {
    var tones: [Color] = [Color(hex: "#8B1538"), Color(hex: "#6A0F2B"), Color(hex: "#A82247")]
    /// Optional vertical gradient (top → bottom) instead of tones.
    var gradient: [Color]? = nil
    var stem = true
    var leafColor: Color? = nil

    /// Brand gradient: rose to Bordeaux.
    static let brandGradient: [Color] = ["#E9B8C2", "#C8506F", "#9B1D45", "#64102E"].map { Color(hex: $0) }

    var body: some View {
        Canvas { ctx, size in
            let L = GrapeMarkLayout.self
            let w = L.maxX - L.minX, h = L.maxY - L.minY
            let s = min(size.width / w, size.height / h)
            let ox = (size.width - w * s) / 2 - L.minX * s
            let oy = (size.height - h * s) / 2 - L.minY * s
            func t(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * s, y: oy + p.y * s) }
            let first = gradient?.first ?? tones[0]
            let deep = gradient?.last ?? tones[1 % tones.count]
            if stem {
                let green = leafColor ?? first.mix(with: deep, 0.25)
                var st = Path()
                st.move(to: t(L.stemBase))
                st.addQuadCurve(to: t(L.stemTop), control: t(CGPoint(x: L.d - 0.15, y: -1.3)))
                ctx.stroke(st, with: .color(green), style: StrokeStyle(lineWidth: max(1, 0.3 * s), lineCap: .round))
                let leaf = L.leaf(t)
                ctx.fill(leaf, with: .color(green))
                var vein = Path()
                vein.move(to: t(L.leafBase))
                vein.addLine(to: t(CGPoint(x: L.leafBase.x + (L.leafTip.x - L.leafBase.x) * 0.78, y: L.leafBase.y + (L.leafTip.y - L.leafBase.y) * 0.78)))
                ctx.stroke(vein, with: .color(green.mix(with: deep, 0.45)), style: StrokeStyle(lineWidth: max(0.6, 0.14 * s), lineCap: .round))
            }
            for (c, ti) in L.berries {
                let r = CGRect(x: t(c).x - s, y: t(c).y - s, width: 2 * s, height: 2 * s)
                var color = tones[ti % tones.count]
                if let grad = gradient, grad.count >= 2 {
                    let f = Double(c.y / (2 * L.dy))
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
        SplashMark()
            .frame(width: size * 0.9, height: size * 0.9)
    }
}

struct Wordmark: View {
    var size: CGFloat = 24
    var body: some View {
        HStack(spacing: size * 0.3) {
            BrandDroplet(size: size * 1.05)
            Text("Jero").font(.system(size: size * 0.95, weight: .bold)).kerning(-0.2).foregroundStyle(Palette.ink)
        }
    }
}

/// Kept for the onboarding hero and older call sites.
struct DropletShape: Shape {
    func path(in r: CGRect) -> Path { Path(ellipseIn: r) }
}

// MARK: - Grape cluster illustration (drawn bunch with shaded berries, stem and vine leaf)

struct GrapeCluster: View {
    var berry: BerryColor
    var tint: Color? = nil
    var leaf: Bool = true
    var seed: Int = 0

    static func base(_ b: BerryColor) -> Color {
        switch b {
        case .black: return Color(hex: "#43183F")
        case .white: return Color(hex: "#BFC266")
        case .pink: return Color(hex: "#B8667F")
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2, oy = (size.height - s) / 2
            let base = tint ?? Self.base(berry)
            let r = s * 0.07
            let rows = [4, 5, 5, 4, 4, 3, 2, 1]
            var berries: [(CGPoint, CGFloat, Double)] = []
            var rng = SeededRandom(seed: UInt64(abs(seed) &+ 7))
            for (i, n) in rows.enumerated() {
                let y = oy + s * 0.3 + CGFloat(i) * r * 1.62
                for k in 0..<n {
                    let jx = CGFloat(rng.next() - 0.5) * r * 0.35
                    let jy = CGFloat(rng.next() - 0.5) * r * 0.3
                    let lean = CGFloat(i) * r * 0.12
                    let x = ox + s * 0.46 + lean + (CGFloat(k) - CGFloat(n - 1) / 2) * r * 1.84 + jx
                    berries.append((CGPoint(x: x, y: y + jy), r * (0.93 + CGFloat(rng.next()) * 0.12), rng.next()))
                }
            }
            // stem
            var stem = Path()
            stem.move(to: CGPoint(x: ox + s * 0.46, y: oy + s * 0.3))
            stem.addCurve(to: CGPoint(x: ox + s * 0.5, y: oy + s * 0.06),
                          control1: CGPoint(x: ox + s * 0.45, y: oy + s * 0.2),
                          control2: CGPoint(x: ox + s * 0.47, y: oy + s * 0.1))
            ctx.stroke(stem, with: .color(Color(hex: "#7A6650")), style: StrokeStyle(lineWidth: s * 0.018, lineCap: .round))
            if leaf {
                let rect = CGRect(x: ox + s * 0.5, y: oy + s * 0.02, width: s * 0.34, height: s * 0.3)
                let lp = VineLeaf.path(in: rect)
                ctx.fill(lp, with: .linearGradient(Gradient(colors: [Color(hex: "#A9B887"), Color(hex: "#7F9260")]),
                                                   startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                var vein = Path()
                let o = CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.62)
                for tip in [(0.68, 0.08), (0.94, 0.3), (0.97, 0.62), (0.6, 0.93)] {
                    vein.move(to: o)
                    vein.addLine(to: CGPoint(x: rect.minX + rect.width * tip.0, y: rect.minY + rect.height * tip.1))
                }
                ctx.stroke(vein, with: .color(Color(hex: "#5F7044").opacity(0.8)), lineWidth: max(0.5, s * 0.006))
            }
            // berries, back to front
            for (c, rr, v) in berries {
                let tone = base.mix(with: v > 0.5 ? .white : .black, 0.03 + v * 0.1)
                let rect = CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [tone.mix(with: .white, 0.28), tone, tone.mix(with: .black, 0.25)]),
                    center: CGPoint(x: c.x - rr * 0.35, y: c.y - rr * 0.4), startRadius: 0, endRadius: rr * 1.5))
                let hl = CGRect(x: c.x - rr * 0.55, y: c.y - rr * 0.6, width: rr * 0.42, height: rr * 0.3)
                ctx.fill(Path(ellipseIn: hl), with: .color(.white.opacity(0.32)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum VineLeaf {
    /// A five-lobed vine leaf filling the rect.
    static func path(in r: CGRect) -> Path {
        let raw: [(CGFloat, CGFloat)] = [
            (0.05, 0.62), (0.2, 0.52), (0.08, 0.32), (0.3, 0.33), (0.35, 0.08), (0.5, 0.25),
            (0.68, 0.0), (0.72, 0.3), (0.95, 0.25), (0.85, 0.48), (1.0, 0.62), (0.78, 0.68),
            (0.8, 0.92), (0.58, 0.8), (0.42, 1.0), (0.36, 0.78), (0.12, 0.85), (0.2, 0.68)
        ]
        let pts: [CGPoint] = raw.map { CGPoint(x: r.minX + r.width * $0.0, y: r.minY + r.height * $0.1) }
        return smoothClosedPath(pts, tension: 0.35)
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
        SilhouetteGlass(shape: sparkling ? .flute : .tasting, color: color, fill: min(0.9, fill), sparkling: sparkling,
                        ink: outline ?? Palette.ink)
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
                        .font(.system(size: max(6, w * 0.085), weight: .bold).width(.condensed))
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

/// Five-step meter: thin segments, filled up to the value (animates in).
struct SegmentMeter: View {
    let value: Int          // 1...5
    let tint: Color
    var delay: Double = 0
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Capsule().fill(i <= shown ? tint : Palette.line).frame(height: 5)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = value }
        }
    }
}

/// Kept for older call sites.
struct ProfileBar: View {
    let title: String
    let value: Int
    let tint: Color
    var delay: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft)
            SegmentMeter(value: value, tint: tint, delay: delay)
        }
    }
}

/// Structure profile: label · meter · plain-English value.
struct StructureBars: View {
    let grape: Grape

    var body: some View {
        let tint = WineCardView.tint(for: grape)
        VStack(spacing: 11) {
            row("Sweetness", grape.sweetness, Self.sweetWord(grape.sweetness), tint, 0)
            row("Body", grape.body, Self.level(grape.body, low: "Light", high: "Full"), tint, 0.06)
            if grape.berry == .black { row("Tannin", grape.tannin, Self.level(grape.tannin), tint, 0.12) }
            row("Acidity", grape.acidity, Self.level(grape.acidity), tint, 0.18)
            row("Alcohol", grape.alcohol, Self.abvShort(grape.alcohol), tint, 0.24)
        }
    }

    private func row(_ label: String, _ v: Int, _ word: String, _ tint: Color, _ d: Double) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink).frame(width: 74, alignment: .leading)
            SegmentMeter(value: v, tint: tint, delay: d)
            Text(word).font(.system(size: 12)).foregroundStyle(Palette.inkSoft).frame(width: 78, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(word)")
    }

    static func level(_ v: Int, low: String = "Low", high: String = "High") -> String {
        switch v {
        case ...1: return low
        case 2: return "Medium–"
        case 3: return "Medium"
        case 4: return "Medium+"
        default: return high
        }
    }

    static func abvShort(_ v: Int) -> String {
        switch v {
        case ...1: return "< 10%"
        case 2: return "10–11.5%"
        case 3: return "11.5–13.5%"
        case 4: return "13.5–15%"
        default: return "> 15%"
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

// MARK: - Aroma chip

struct AromaChip: View {
    let text: String
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            FlavorIcon(aroma: text, size: compact ? 16 : 18)
            Text(text).font(.system(size: compact ? 13 : 14)).foregroundStyle(Palette.ink)
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
    var frozen = false     // a streak freeze is keeping the streak today (shown as a snowflake until the day's lesson)
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 4) {
            // a freeze is covering yesterday: the flame is a snowflake until today's lesson
            Image(systemName: frozen && !active ? "snowflake" : (active ? "flame.fill" : "flame"))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(frozen && !active ? Palette.slate : (active ? Palette.flame : Palette.inkFaint))
            Text("\(count)")
                .font(.numeric(size + 1, .bold))
                .foregroundStyle(active ? Palette.ink : Palette.inkSoft)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frozen && !active ? "\(count) day streak, kept by a streak freeze: do a lesson today" : "\(count) day streak")
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
                .stroke(progress >= 1 ? Palette.correct : Palette.wine, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress >= 1 {
                Image(systemName: "checkmark").font(.system(size: lineWidth * 3, weight: .bold)).foregroundStyle(Palette.correct)
            }
        }
    }
}
