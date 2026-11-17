import SwiftUI

// MARK: - Brand droplet

/// The Jeroboam droplet: a classic teardrop built from x = sin t · sin(t/2)^m, y = cos t.
struct DropletShape: Shape {
    var m: Double = 1.9
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 120
        let h = r.height, w = r.width
        for i in 0...n {
            let t = 2 * Double.pi * Double(i) / Double(n)
            let x = sin(t) * pow(abs(sin(t / 2)), m)
            let y = cos(t)
            let pt = CGPoint(x: r.midX + CGFloat(x) * w, y: r.midY - CGFloat(y) * h / 2)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct BrandDroplet: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            DropletShape()
                .fill(LinearGradient(colors: [Color(hex: "#B22E54"), Color(hex: "#5C0C28")], startPoint: .top, endPoint: .bottom))
            DropletShape()
                .fill(RadialGradient(colors: [.clear, Color.black.opacity(0.28)], center: UnitPoint(x: 0.35, y: 0.55),
                                     startRadius: size * 0.05, endRadius: size * 0.45))
            DropletShape()
                .stroke(Color.white.opacity(0.35), lineWidth: size * 0.025)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.45, y: 0.7)))
                .scaleEffect(0.78)
                .offset(x: -size * 0.03, y: size * 0.04)
        }
        .frame(width: size * 0.5, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Grape cluster

/// A bunch of grapes: flat berries with subtle tonal variation, a fine stem and a vine leaf.
struct GrapeCluster: View {
    var berry: BerryColor
    var tint: Color? = nil
    var leaf: Bool = true
    var seed: Int = 0

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2, oy = (size.height - s) / 2
            let base = tint ?? Palette.berry(berry)
            let r = s * 0.068
            let rows = [5, 6, 5, 5, 4, 3, 2, 1]
            var berries: [(CGPoint, CGFloat, Double)] = []
            var rng = SeededRandom(seed: UInt64(seed &+ 7))
            for (i, n) in rows.enumerated() {
                let y = oy + s * 0.32 + CGFloat(i) * r * 1.66
                for k in 0..<n {
                    let jx = CGFloat(rng.next() - 0.5) * r * 0.3
                    let jy = CGFloat(rng.next() - 0.5) * r * 0.25
                    let x = ox + s * 0.47 + (CGFloat(k) - CGFloat(n - 1) / 2) * r * 1.86 + jx
                    berries.append((CGPoint(x: x, y: y + jy), r * (0.94 + CGFloat(rng.next()) * 0.1), rng.next()))
                }
            }
            // stem
            var stem = Path()
            stem.move(to: CGPoint(x: ox + s * 0.47, y: oy + s * 0.33))
            stem.addCurve(to: CGPoint(x: ox + s * 0.55, y: oy + s * 0.08),
                          control1: CGPoint(x: ox + s * 0.47, y: oy + s * 0.22),
                          control2: CGPoint(x: ox + s * 0.5, y: oy + s * 0.12))
            ctx.stroke(stem, with: .color(Color(hex: "#7A6650")), style: StrokeStyle(lineWidth: s * 0.016, lineCap: .round))
            // leaf
            if leaf {
                let rect = CGRect(x: ox + s * 0.53, y: oy + s * 0.04, width: s * 0.36, height: s * 0.32)
                let leafPath = VineLeaf.path(in: rect)
                ctx.fill(leafPath, with: .color(Color(hex: "#9AA87A")))
                var vein = Path()
                let o = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.6)
                for tip in [(0.68, 0.06), (0.95, 0.3), (0.98, 0.62), (0.62, 0.95)] {
                    vein.move(to: o)
                    vein.addLine(to: CGPoint(x: rect.minX + rect.width * tip.0, y: rect.minY + rect.height * tip.1))
                }
                ctx.stroke(vein, with: .color(Color(hex: "#6F7F50")), lineWidth: max(0.6, s * 0.005))
            }
            // berries
            for (c, rr, v) in berries {
                let tone = base.mix(with: v > 0.5 ? .white : .black, 0.04 + v * 0.1)
                let rect = CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)
                ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
                    Gradient(colors: [tone.mix(with: .white, 0.14), tone]),
                    startPoint: CGPoint(x: c.x - rr, y: c.y - rr), endPoint: CGPoint(x: c.x + rr, y: c.y + rr)))
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.3, dy: 0.3)), with: .color(Palette.paper.opacity(0.55)), lineWidth: max(0.6, s * 0.006))
            }
        }
        .accessibilityHidden(true)
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

// MARK: - Wine glass

struct WineGlassShape: Shape {
    /// The bowl outline (without stem), inside the top 62% of the rect.
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.2, y: r.minY + h * 0.02))
        p.addLine(to: CGPoint(x: r.minX + w * 0.8, y: r.minY + h * 0.02))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.6),
                   control1: CGPoint(x: r.minX + w * 1.0, y: r.minY + h * 0.3),
                   control2: CGPoint(x: r.minX + w * 0.86, y: r.minY + h * 0.6))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.2, y: r.minY + h * 0.02),
                   control1: CGPoint(x: r.minX + w * 0.14, y: r.minY + h * 0.6),
                   control2: CGPoint(x: r.minX + w * 0.0, y: r.minY + h * 0.3))
        p.closeSubpath()
        return p
    }
}

/// A fine-line wine glass with the wine's color and a paler rim.
struct WineGlass: View {
    var color: Color
    var rim: Color? = nil
    var fill: CGFloat = 0.55
    var sparkling = false

    var body: some View {
        Canvas { ctx, size in
            let w = min(size.width, size.height * 0.62)
            let h = w / 0.62
            let r = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            let bowl = WineGlassShape().path(in: r)
            let bottom = r.minY + r.height * 0.6
            let top = bottom - r.height * 0.58 * fill
            var clip = ctx
            clip.clip(to: bowl)
            clip.fill(Path(CGRect(x: r.minX, y: top, width: r.width, height: bottom - top + 2)), with: .linearGradient(
                Gradient(stops: [
                    .init(color: rim ?? color.mix(with: .white, 0.3), location: 0),
                    .init(color: color, location: 0.3),
                    .init(color: color.mix(with: .black, 0.15), location: 1)
                ]),
                startPoint: CGPoint(x: r.midX, y: top), endPoint: CGPoint(x: r.midX, y: bottom)))
            let t = Double(max(0, min(1, (top - r.minY) / (r.height * 0.6))))
            let sw = r.width * 0.9 * CGFloat(sin(Double.pi * (0.27 + 0.73 * t)))
            clip.fill(Path(ellipseIn: CGRect(x: r.midX - sw / 2, y: top - r.height * 0.014, width: sw, height: r.height * 0.028)),
                      with: .color((rim ?? color).mix(with: .white, 0.2)))
            if sparkling {
                var rng = SeededRandom(seed: 3)
                for _ in 0..<12 {
                    let bx = r.midX + CGFloat(rng.next() - 0.5) * sw * 0.6
                    let by = top + CGFloat(rng.next()) * (bottom - top) * 0.9
                    let br = r.width * 0.014 * CGFloat(0.6 + rng.next())
                    clip.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(.white.opacity(0.7)))
                }
            }
            let stroke = Palette.inkFaint
            ctx.stroke(bowl, with: .color(stroke), lineWidth: max(0.8, w * 0.012))
            var stem = Path()
            stem.move(to: CGPoint(x: r.midX, y: bottom))
            stem.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.96))
            stem.move(to: CGPoint(x: r.midX - r.width * 0.26, y: r.minY + r.height * 0.97))
            stem.addQuadCurve(to: CGPoint(x: r.midX + r.width * 0.26, y: r.minY + r.height * 0.97),
                              control: CGPoint(x: r.midX, y: r.minY + r.height * 0.93))
            ctx.stroke(stem, with: .color(stroke), style: StrokeStyle(lineWidth: max(0.8, w * 0.014), lineCap: .round))
            var shine = Path()
            shine.move(to: CGPoint(x: r.minX + r.width * 0.21, y: r.minY + r.height * 0.1))
            shine.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.36),
                               control: CGPoint(x: r.minX + r.width * 0.15, y: r.minY + r.height * 0.26))
            ctx.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: w * 0.025, lineCap: .round))
        }
        .aspectRatio(0.62, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Structure scale

/// Wine Folly-style structure profile: a thin track with five ticks and a marker.
struct StructureBars: View {
    let grape: Grape

    var body: some View {
        VStack(spacing: 14) {
            row("Body", grape.body, lo: "Light", hi: "Full")
            if grape.berry == .black { row("Tannin", grape.tannin, lo: "Low", hi: "High") }
            row("Acidity", grape.acidity, lo: "Low", hi: "High")
            row("Alcohol", grape.alcohol, lo: "Low", hi: "High")
            row("Sweetness", grape.sweetness, lo: "Dry", hi: "Sweet")
        }
    }

    private func row(_ name: String, _ v: Int, lo: String, hi: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text(scaleWord(v, lo: lo, hi: hi)).font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(height: 3)
                    Capsule().fill(Palette.wine.opacity(0.85)).frame(width: max(6, w * CGFloat(v) / 5), height: 3)
                    ForEach(1..<5, id: \.self) { i in
                        Rectangle().fill(Palette.card).frame(width: 2, height: 5).offset(x: w * CGFloat(i) / 5 - 1)
                    }
                    Circle().fill(Palette.wine).frame(width: 9, height: 9)
                        .offset(x: max(0, w * CGFloat(v) / 5 - 4.5))
                }
                .frame(height: 9)
            }
            .frame(height: 9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(v) out of 5")
    }

    private func scaleWord(_ v: Int, lo: String, hi: String) -> String {
        switch v {
        case ...1: return lo
        case 2: return "Medium–"
        case 3: return "Medium"
        case 4: return "Medium+"
        default: return hi
        }
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
            Circle().fill(tint).frame(width: compact ? 6 : 7, height: compact ? 6 : 7)
            Text(text).font(.system(size: compact ? 13 : 14, weight: .medium)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(Palette.cardAlt))
    }
}

// MARK: - Bottle

struct BottleShape: Shape {
    var neck: CGFloat = 0.32   // fraction of width
    var shoulder: CGFloat = 0.38
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let nw = w * neck
        let st = r.minY + h * shoulder
        p.move(to: CGPoint(x: r.midX - nw / 2, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + nw / 2, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + nw / 2, y: st - h * 0.16))
        p.addCurve(to: CGPoint(x: r.maxX, y: st + h * 0.1),
                   control1: CGPoint(x: r.midX + nw / 2, y: st - h * 0.03),
                   control2: CGPoint(x: r.maxX, y: st - h * 0.02))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - w * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.06, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.06, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - w * 0.06), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: st + h * 0.1))
        p.addCurve(to: CGPoint(x: r.midX - nw / 2, y: st - h * 0.16),
                   control1: CGPoint(x: r.minX, y: st - h * 0.02),
                   control2: CGPoint(x: r.midX - nw / 2, y: st - h * 0.03))
        p.closeSubpath()
        return p
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
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? Palette.flame : Palette.inkFaint)
            Text("\(count)")
                .font(.numeric(size + 1, .semibold))
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
            Image(systemName: "sparkle").font(.system(size: size - 1, weight: .medium)).foregroundStyle(Palette.brass)
            Text("\(xp)").font(.numeric(size + 1, .semibold)).foregroundStyle(Palette.ink).lineLimit(1).contentTransition(.numericText())
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
