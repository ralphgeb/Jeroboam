import SwiftUI

/// The two wine belts (30°–50° north and south) on a soft world map, with famous regions pinned.
struct WineBeltDiagram: View {
    var compact = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let g = MapGeometry.get("world"), let b = g.map.belts, b.count == 4 {
            let aspect = CGFloat(g.map.w) / CGFloat(g.map.h)
            VStack(alignment: .leading, spacing: 8) {
                Canvas { ctx, size in
                    let s = size.width / CGFloat(g.map.w)
                    let dark = scheme == .dark
                    let full = CGRect(origin: .zero, size: size)
                    ctx.fill(Path(full), with: .linearGradient(Gradient(colors: dark ? [Color(hex: "#1D2B3A"), Color(hex: "#162231")] : [Color(hex: "#DCEBF5"), Color(hex: "#C9E0EF")]),
                                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                    let degPx = CGFloat(b[1] - b[0]) / 20 * s
                    let eqY = CGFloat(b[1]) * s + 30 * degPx
                    // belts
                    for i in stride(from: 0, to: 4, by: 2) {
                        let y0 = CGFloat(b[i]) * s, y1 = CGFloat(b[i + 1]) * s
                        let band = CGRect(x: 0, y: y0, width: size.width, height: y1 - y0)
                        ctx.fill(Path(band), with: .linearGradient(Gradient(colors: [Palette.bordeaux.opacity(dark ? 0.28 : 0.14), Palette.pink.opacity(dark ? 0.22 : 0.10)]),
                                                                   startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1)))
                        for y in [y0, y1] {
                            var l = Path(); l.move(to: CGPoint(x: 0, y: y)); l.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(l, with: .color(Palette.bordeaux.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        }
                    }
                    var eq = Path(); eq.move(to: CGPoint(x: 0, y: eqY)); eq.addLine(to: CGPoint(x: size.width, y: eqY))
                    ctx.stroke(eq, with: .color(Palette.slate.opacity(0.35)), style: StrokeStyle(lineWidth: 0.7, dash: [1, 3]))
                    // land: wine countries a little brighter
                    ctx.drawLayer { l in
                        l.scaleBy(x: s, y: s)
                        l.fill(g.land, with: .color(dark ? Color(hex: "#3A3036") : Color(hex: "#E7E1DC")))
                        l.fill(g.focus, with: .color(dark ? Color(hex: "#5A4650") : Color(hex: "#FBF8F5")))
                        l.stroke(g.focus, with: .color(dark ? .black.opacity(0.3) : Color(hex: "#D9CFC9")), lineWidth: 0.6 / s)
                    }
                    // latitude labels
                    let labels: [(String, CGFloat)] = [("50° N", CGFloat(b[0]) * s), ("30° N", CGFloat(b[1]) * s), ("Equator", eqY),
                                                       ("30° S", CGFloat(b[2]) * s), ("50° S", CGFloat(b[3]) * s)]
                    for (t, y) in labels {
                        let txt = Text(t).font(.system(size: compact ? 8 : 9, weight: .semibold)).foregroundColor(t == "Equator" ? Palette.slate : Palette.bordeaux)
                        ctx.draw(txt, at: CGPoint(x: 4, y: y - 1), anchor: .bottomLeading)
                    }
                    // pinned regions
                    var taken: [CGRect] = []
                    for c in g.map.cities {
                        let p = CGPoint(x: CGFloat(c.x) * s, y: CGFloat(c.y) * s)
                        let r: CGFloat = compact ? 2.6 : 3.2
                        let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                        ctx.fill(dot, with: .color(Palette.bordeaux))
                        ctx.stroke(dot, with: .color(.white), lineWidth: 1)
                        guard !compact else { continue }
                        let resolved = ctx.resolve(Text(c.n).font(.system(size: 8.5, weight: .medium)).foregroundColor(Palette.ink.opacity(0.8)))
                        let sz = resolved.measure(in: CGSize(width: 120, height: 20))
                        var rect = CGRect(x: p.x + 4, y: p.y - sz.height / 2, width: sz.width, height: sz.height)
                        if rect.maxX > size.width - 2 { rect.origin.x = p.x - 4 - sz.width }
                        if taken.contains(where: { $0.insetBy(dx: -2, dy: -1).intersects(rect) }) { continue }
                        taken.append(rect)
                        ctx.draw(resolved, in: rect)
                    }
                }
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !compact {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.bordeaux.opacity(0.25)).frame(width: 14, height: 10)
                        Text("Most of the world's vineyards lie between 30° and 50° of latitude, where summers are warm and winters cool enough to rest the vine.")
                            .font(.system(size: 12)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
