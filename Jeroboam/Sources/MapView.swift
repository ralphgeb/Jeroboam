import SwiftUI

// MARK: - Data

struct WineMapV2: Decodable {
    struct Area: Decodable {
        let id: String
        let name: String
        let lv: Int
        let c: Int
        let shapes: [[Int]]
        let cx: Int
        let cy: Int
        let lx: Int?
        let ly: Int?
        let parent: String?
        let g: String?
    }
    struct City: Decodable { let n: String; let x: Int; let y: Int; let r: Int? }
    struct Label: Decodable { let t: String; let x: Int; let y: Int; let k: String }
    struct River: Decodable { let w: Int; let p: [Int] }
    struct Village: Decodable { let n: String; let x: Int; let y: Int }

    let id: String
    let title: String
    let w: Int
    let h: Int
    let land: [[Int]]
    let focus: [[Int]]
    let lakes: [[Int]]
    let rivers: [River]
    let borders: [[Int]]?
    let areas: [Area]
    let cities: [City]
    let labels: [Label]
    let communes: [[Int]]?
    let villages: [Village]?
    let belts: [Int]?
}

/// Pre-built vector paths for a map, in map units.
final class MapGeometry {
    struct Area {
        let id: String
        let name: String
        let level: Int
        let color: Int
        let path: Path
        let centroid: CGPoint
        let label: CGPoint?
        let parent: String?
        let grapes: String?
        let area: CGFloat
        var index: Int { color }
    }

    let map: WineMapV2
    let land: Path
    let focus: Path
    let lakes: Path
    let landMask: Path
    let borders: Path
    let communes: Path
    let rivers: [(Path, CGFloat)]
    let areas: [Area]
    let hasChildren: Set<String>
    let maxLevel: Int

    private static var cache: [String: MapGeometry] = [:]
    private static let lock = NSLock()

    static func get(_ id: String) -> MapGeometry? {
        lock.lock(); defer { lock.unlock() }
        if let g = cache[id] { return g }
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Maps")
                ?? Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(WineMapV2.self, from: data) else { return nil }
        let g = MapGeometry(m)
        cache[id] = g
        return g
    }

    private static func pts(_ f: [Int]) -> [CGPoint] {
        stride(from: 0, to: f.count - 1, by: 2).map { CGPoint(x: CGFloat(f[$0]), y: CGFloat(f[$0 + 1])) }
    }

    private static func poly(_ list: [[Int]]) -> Path {
        var p = Path()
        for f in list {
            let ps = pts(f)
            guard ps.count > 2 else { continue }
            p.addLines(ps)
            p.closeSubpath()
        }
        return p
    }

    private static func lines(_ list: [[Int]], close: Bool = false) -> Path {
        var p = Path()
        for f in list {
            let ps = pts(f)
            guard ps.count > 1 else { continue }
            p.addLines(ps)
            if close { p.closeSubpath() }
        }
        return p
    }

    private init(_ m: WineMapV2) {
        map = m
        land = Self.poly(m.land)
        focus = Self.poly(m.focus)
        lakes = Self.poly(m.lakes)
        var mask = Path()
        mask.addPath(land)
        mask.addPath(focus)
        landMask = mask
        borders = Self.lines(m.borders ?? [])
        communes = Self.lines(m.communes ?? [], close: true)
        rivers = m.rivers.map { r in
            var p = Path()
            p.addLines(Self.pts(r.p))
            return (p, CGFloat(r.w))
        }
        var list: [Area] = []
        for a in m.areas {
            var p = Path()
            var total: CGFloat = 0
            for s in a.shapes {
                let ps = Self.pts(s)
                guard ps.count > 2 else { continue }
                p.addLines(ps)
                p.closeSubpath()
                total += abs(Self.area(ps))
            }
            let lab: CGPoint? = (a.lx != nil && a.ly != nil) ? CGPoint(x: CGFloat(a.lx!), y: CGFloat(a.ly!)) : nil
            list.append(Area(id: a.id, name: a.name, level: a.lv, color: a.c, path: p,
                             centroid: CGPoint(x: CGFloat(a.cx), y: CGFloat(a.cy)), label: lab, parent: a.parent,
                             grapes: a.g, area: total))
        }
        areas = list
        hasChildren = Set(list.compactMap(\.parent))
        maxLevel = list.map(\.level).max() ?? 0
    }

    static func area(_ p: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }

    /// Stable numbers for the areas visible at a level (top-to-bottom, left-to-right).
    func numbering(level: Int, zoom: CGFloat = 1) -> [String: Int] {
        var out: [String: Int] = [:]
        for (i, a) in numbered(level: level, zoom: zoom).enumerated() { out[a.id] = i + 1 }
        return out
    }

    func numbered(level: Int, zoom: CGFloat = 1) -> [Area] {
        areas.filter { a in
            if a.level > level { return false }
            if hasChildren.contains(a.id) && a.level < level { return false }
            return true
        }
        .sorted { ($0.centroid.y / 120).rounded() == ($1.centroid.y / 120).rounded() ? $0.centroid.x < $1.centroid.x : $0.centroid.y < $1.centroid.y }
    }

    /// The deepest visible area containing a point (map units).
    func hit(_ pt: CGPoint, maxLevel lv: Int) -> Area? {
        areas.filter { $0.level <= lv && $0.path.contains(pt) }
            .sorted { ($0.level, -$0.area) > ($1.level, -$1.area) }
            .first
    }
}

// MARK: - Rendering

/// Level-of-detail thresholds (zoom = 1 fits the whole map).
private enum LOD {
    static let level1: CGFloat = 1.9
    static let level2: CGFloat = 3.2
    static let communes: CGFloat = 2.4
    static let villages: CGFloat = 4.0
}

struct MapRenderer {
    let g: MapGeometry
    var zoom: CGFloat = 1
    var offset: CGSize = .zero
    var highlight: Set<String> = []
    var selected: String? = nil
    var showLabels = true
    var showCities = true
    var labelScale: CGFloat = 1
    var dark = false
    var forcedLevel: Int? = nil
    /// Zoom at which the map first appears; detail levels are relative to it.
    var lodBase: CGFloat = 1
    var rel: CGFloat { zoom / max(0.01, lodBase) }
    /// Show a single highlighted area's name automatically (off in quiz questions).
    var autoCallout = true

    func visibleLevel() -> Int {
        if let f = forcedLevel { return f }
        if rel >= LOD.level2 { return 2 }
        if rel >= LOD.level1 { return 1 }
        return 0
    }

    /// Converts a point in the view to map units.
    func toMap(_ p: CGPoint, size: CGSize) -> CGPoint {
        let fit = size.width / CGFloat(g.map.w)
        let s = fit * zoom
        return CGPoint(x: (p.x - offset.width) / s, y: (p.y - offset.height) / s)
    }

    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        let fit = size.width / CGFloat(g.map.w)
        let s = fit * zoom
        let hair = 1 / s
        let lv = visibleLevel()
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .color(Palette.sea))

        func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s + offset.width, y: p.y * s + offset.height) }

        if let b = g.map.belts, b.count == 4 {
            for i in stride(from: 0, to: 4, by: 2) {
                let y0 = CGFloat(b[i]) * s + offset.height, y1 = CGFloat(b[i + 1]) * s + offset.height
                ctx.fill(Path(CGRect(x: 0, y: y0, width: size.width, height: y1 - y0)), with: .color(Palette.bordeaux.opacity(dark ? 0.22 : 0.10)))
            }
        }

        ctx.drawLayer { layer in
            layer.translateBy(x: offset.width, y: offset.height)
            layer.scaleBy(x: s, y: s)
            layer.fill(g.land, with: .color(Palette.land))
            layer.stroke(g.land, with: .color(Palette.border.opacity(0.7)), lineWidth: hair * 0.7)
        }
        // The focus country "pops out": a soft lift shadow under bright land, neighbours stay muted.
        if g.map.belts == nil {
            let t = CGAffineTransform(translationX: offset.width, y: offset.height).scaledBy(x: s, y: s)
            let fp = g.focus.applying(t)
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: .black.opacity(dark ? 0.55 : 0.16), radius: 7, x: 0, y: 3))
                l.fill(fp, with: .color(Palette.focusLand))
            }
        }
        ctx.drawLayer { layer in
            layer.translateBy(x: offset.width, y: offset.height)
            layer.scaleBy(x: s, y: s)
            layer.fill(g.focus, with: .color(Palette.focusLand))
            if showLabels || showCities {
                layer.stroke(g.borders, with: .color(Palette.adminLine), lineWidth: hair * 0.8)
            }

            if g.map.belts != nil {
                layer.fill(g.focus, with: .color(Palette.bordeaux.opacity(dark ? 0.75 : 0.62)))
            }

            var regions = layer
            regions.clip(to: g.landMask)
            let ids = Set(g.areas.map(\.id))
            let anyHL = !highlight.intersection(ids).isEmpty || selected != nil
            for a in g.areas where a.level <= lv {
                let parentIsZoomed = lv >= 1 && g.hasChildren.contains(a.id) && a.level < lv
                var color = Palette.mapColor(a.color)
                if a.level >= 1 && a.parent != nil {
                    color = color.mix(with: .black, a.level == 1 ? 0.18 : 0.32)
                }
                let isHL = highlight.contains(a.id) || selected == a.id
                var opacity: Double = parentIsZoomed ? 0.38 : 1
                if anyHL && !isHL && !(highlight.contains(a.parent ?? "") ) { opacity *= 0.28 }
                regions.fill(a.path, with: .color(color.opacity(opacity)))
                regions.stroke(a.path, with: .color(Palette.focusLand.opacity(0.95)), lineWidth: hair * (a.level == 0 ? 1.4 : 1.1))
                if isHL {
                    regions.stroke(a.path, with: .color(Palette.ink), lineWidth: hair * 2.2)
                }
            }
            if rel >= LOD.communes || (forcedLevel ?? 0) >= 2 {
                regions.stroke(g.communes, with: .color(Palette.focusLand.opacity(0.75)), lineWidth: hair * 0.7)
            }
            layer.fill(g.lakes, with: .color(Palette.sea))
            for (r, w) in g.rivers where showLabels || showCities {
                layer.stroke(r, with: .color(Palette.river), style: StrokeStyle(lineWidth: (w >= 2 ? 1.3 : 0.8) * hair, lineCap: .round, lineJoin: .round))
            }
            layer.stroke(g.focus, with: .color(Palette.border), lineWidth: hair * 1.2)
        }

        guard showLabels else { return }
        var taken: [CGRect] = []
        let inset = full.insetBy(dx: 2, dy: 2)
        func place(_ text: Text, at p: CGPoint, anchor: UnitPoint, force: Bool = false, halo: Bool = true) -> CGRect? {
            var t = ctx
            let resolved = t.resolve(text)
            let sz = resolved.measure(in: CGSize(width: 260, height: 120))
            let rect = CGRect(x: p.x - sz.width * anchor.x, y: p.y - sz.height * anchor.y, width: sz.width, height: sz.height)
            if !force {
                if !inset.contains(rect) { return nil }
                if taken.contains(where: { $0.insetBy(dx: -3, dy: -2).intersects(rect) }) { return nil }
            }
            taken.append(rect)
            if halo { t.addFilter(.shadow(color: Palette.focusLand.opacity(0.95), radius: 1.8)) }
            t.draw(resolved, at: p, anchor: anchor)
            return rect
        }
        let ls = labelScale

        for l in g.map.labels {
            let p = screen(CGPoint(x: CGFloat(l.x), y: CGFloat(l.y)))
            switch l.k {
            case "sea":
                _ = place(Text(l.t).font(.system(size: 11 * ls, weight: .medium).italic()).foregroundColor(Palette.slate), at: p, anchor: .center, halo: false)
            case "river":
                _ = place(Text(l.t).font(.system(size: 9.5 * ls, weight: .medium).italic()).foregroundColor(Palette.river), at: p, anchor: .center)
            default:
                _ = place(Text(l.t.uppercased()).font(.system(size: 9 * ls, weight: .bold)).kerning(1.8).foregroundColor(Palette.inkFaint), at: p, anchor: .center, halo: false)
            }
        }

        // Area labels: small numbered badges (names appear in a callout when an area is tapped).
        let shownLevel = lv
        let numbers = g.numbering(level: shownLevel, zoom: zoom)
        let calloutID = calloutArea
        let candidates = g.areas.filter { a in
            if a.level > shownLevel { return false }
            if g.hasChildren.contains(a.id) && a.level < shownLevel && rel > LOD.level1 * 1.4 { return false }
            return true
        }.sorted { a, b in
            if a.level != b.level { return a.level > b.level }
            return a.area < b.area
        }
        func badge(_ n: Int, color: Color, at c: CGPoint) {
            let r: CGFloat = 7.5 * max(1, ls * 0.95)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            guard inset.contains(rect), !taken.contains(where: { $0.insetBy(dx: -0.5, dy: -0.5).intersects(rect) }) else { return }
            taken.append(rect)
            let circle = Path(ellipseIn: rect)
            ctx.fill(circle, with: .color(color.mix(with: .black, 0.28)))
            ctx.stroke(circle, with: .color(.white.opacity(0.95)), lineWidth: 1)
            ctx.draw(Text("\(n)").font(.system(size: r * 1.12, weight: .bold).monospacedDigit()).foregroundColor(.white), at: c)
        }
        for a in candidates where a.id != calloutID {
            let c = screen(a.centroid)
            let b = a.path.boundingRect
            if let n = numbers[a.id], max(b.width * s, b.height * s) >= 3 {
                badge(n, color: Palette.mapColor(a.color), at: c)
            }
        }

        if rel >= LOD.villages || ((forcedLevel ?? 0) >= 2 && rel >= 2), let vs = g.map.villages {
            for v in vs {
                let p = screen(CGPoint(x: CGFloat(v.x), y: CGFloat(v.y)))
                guard full.contains(p) else { continue }
                _ = place(Text(v.n).font(.system(size: 9 * ls, weight: .medium).italic()).foregroundColor(Palette.inkSoft), at: p, anchor: .center)
            }
        }

        if showCities {
            for c in g.map.cities where (c.r ?? 1) == 0 || rel >= 1.5 {
                let p = screen(CGPoint(x: CGFloat(c.x), y: CGFloat(c.y)))
                let r: CGFloat = (c.r ?? 1) == 0 ? 3 : 2.3
                let txt = Text(c.n).font(.system(size: ((c.r ?? 1) == 0 ? 10.5 : 9.5) * ls, weight: (c.r ?? 1) == 0 ? .semibold : .regular)).foregroundColor(Palette.ink)
                if place(txt, at: CGPoint(x: p.x + 6, y: p.y), anchor: .leading) != nil
                    || place(txt, at: CGPoint(x: p.x - 6, y: p.y), anchor: .trailing) != nil {
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    ctx.fill(dot, with: .color(Palette.focusLand))
                    ctx.stroke(dot, with: .color(Palette.ink), lineWidth: 1.4)
                }
            }
        }
        drawCallout(in: &ctx, size: size)
    }

    /// The area whose name is shown in a callout: the tapped one, else a single highlighted area.
    var calloutArea: String? {
        if let s = selected { return s }
        guard autoCallout else { return nil }
        let ids = highlight.intersection(Set(g.areas.map(\.id)))
        return ids.count == 1 ? ids.first : nil
    }

    /// A small boxed name with a pointer, anchored on the area.
    func drawCallout(in ctx: inout GraphicsContext, size: CGSize) {
        guard let id = calloutArea, let a = g.areas.first(where: { $0.id == id }) else { return }
        let fit = size.width / CGFloat(g.map.w)
        let s = fit * zoom
        let c = CGPoint(x: a.centroid.x * s + offset.width, y: a.centroid.y * s + offset.height)
        var t = ctx
        let title = t.resolve(Text(a.name).font(.system(size: 12.5 * max(1, labelScale * 0.9), weight: .semibold)).foregroundColor(Palette.ink))
        let tsz = title.measure(in: CGSize(width: 240, height: 60))
        let w = tsz.width + 30, h = tsz.height + 12
        let below = c.y - h - 12 < 4
        var x = c.x - w / 2
        x = min(max(4, x), size.width - w - 4)
        let y = below ? c.y + 12 : c.y - h - 10
        let box = CGRect(x: x, y: y, width: w, height: h)
        var p = Path(roundedRect: box, cornerRadius: 8, style: .continuous)
        let tipX = min(max(box.minX + 10, c.x), box.maxX - 10)
        var tip = Path()
        if below {
            tip.move(to: CGPoint(x: tipX - 6, y: box.minY)); tip.addLine(to: CGPoint(x: tipX, y: box.minY - 6)); tip.addLine(to: CGPoint(x: tipX + 6, y: box.minY))
        } else {
            tip.move(to: CGPoint(x: tipX - 6, y: box.maxY)); tip.addLine(to: CGPoint(x: tipX, y: box.maxY + 6)); tip.addLine(to: CGPoint(x: tipX + 6, y: box.maxY))
        }
        tip.closeSubpath()
        p.addPath(tip)
        t.drawLayer { l in
            l.addFilter(.shadow(color: .black.opacity(dark ? 0.5 : 0.18), radius: 6, y: 2))
            l.fill(p, with: .color(Palette.card))
        }
        let dotR: CGFloat = 4
        t.fill(Path(ellipseIn: CGRect(x: box.minX + 10 - dotR, y: box.midY - dotR, width: 2 * dotR, height: 2 * dotR)), with: .color(Palette.mapColor(a.color)))
        t.draw(title, at: CGPoint(x: box.minX + 20, y: box.midY), anchor: .leading)
        let ring = Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
        t.fill(ring, with: .color(Palette.ink))
        t.stroke(ring, with: .color(.white), lineWidth: 1.2)
    }
}

// MARK: - Static map (cards, lessons)

struct WineMapView: View {
    let mapID: String
    var highlight: Set<String> = []
    var pins: [String] = []
    var showLabels = true
    var showCities = true
    var labelScale: CGFloat = 1
    /// Fill the given frame, centered on the wine areas (cards); otherwise keep the map's own aspect ratio.
    var fill = false
    var autoCallout = true
    var onSelect: ((String) -> Void)? = nil

    @Environment(\.colorScheme) private var scheme
    @State private var tapped: String? = nil

    private func layout(_ g: MapGeometry, _ size: CGSize) -> (zoom: CGFloat, offset: CGSize) {
        guard fill else { return (1, .zero) }
        let focusRect: CGRect? = {
            let hl = g.areas.filter { highlight.contains($0.id) && $0.level == 0 }
            guard !hl.isEmpty, pins.isEmpty else { return nil }
            return hl.map { $0.path.boundingRect }.reduce(CGRect.null) { $0.union($1) }
        }()
        return g.fitLayout(size: size, target: focusRect)
    }

    var body: some View {
        if let g = MapGeometry.get(mapID) {
            let canvas = Canvas { ctx, size in
                let (zoom, offset) = layout(g, size)
                var r = MapRenderer(g: g)
                r.zoom = zoom
                r.lodBase = zoom
                r.offset = offset
                r.highlight = highlight
                r.selected = tapped
                r.autoCallout = autoCallout
                r.showLabels = showLabels && pins.isEmpty
                r.showCities = showCities
                r.labelScale = labelScale
                r.dark = scheme == .dark
                let deepest = g.areas.filter { highlight.contains($0.id) }.map(\.level).max() ?? 0
                r.forcedLevel = deepest
                r.draw(in: &ctx, size: size)
                let s = size.width / CGFloat(g.map.w) * zoom
                func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s + offset.width, y: p.y * s + offset.height) }
                if !pins.isEmpty {
                    for (i, id) in pins.enumerated() {
                        guard let a = g.areas.first(where: { $0.id == id }), id != tapped else { continue }
                        let p = screen(a.centroid)
                        let rr: CGFloat = 8.5
                        let circle = Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr))
                        ctx.fill(circle, with: .color(Palette.mapColor(a.color).mix(with: .black, 0.28)))
                        ctx.stroke(circle, with: .color(.white), lineWidth: 1)
                        ctx.draw(Text("\(i + 1)").font(.system(size: 9.5, weight: .bold).monospacedDigit()).foregroundColor(.white), at: p)
                    }
                    if tapped != nil { r.drawCallout(in: &ctx, size: size) }
                }
            }
            Group {
                if fill { canvas } else { canvas.aspectRatio(CGFloat(g.map.w) / CGFloat(g.map.h), contentMode: .fit) }
            }
            .overlay {
                if let onSelect {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { pt in
                                let (zoom, offset) = layout(g, geo.size)
                                var r = MapRenderer(g: g)
                                r.zoom = zoom
                                r.offset = offset
                                let m = r.toMap(pt, size: geo.size)
                                let s = geo.size.width / CGFloat(g.map.w) * zoom
                                func d(_ a: MapGeometry.Area) -> CGFloat {
                                    hypot(a.centroid.x * s + offset.width - pt.x, a.centroid.y * s + offset.height - pt.y)
                                }
                                let pinHit = pins.compactMap { id in g.areas.first { $0.id == id } }.min { d($0) < d($1) }.flatMap { d($0) < 16 ? $0 : nil }
                                if let a = pinHit ?? g.hit(m, maxLevel: 0) ?? g.hit(m, maxLevel: 2) {
                                    Haptics.tap()
                                    if tapped == a.id { onSelect(a.id) } else { withAnimation(.easeOut(duration: 0.15)) { tapped = a.id } }
                                } else {
                                    tapped = nil
                                }
                            }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map of \(g.map.title)")
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Palette.cardAlt).frame(height: 160)
                .overlay(Text("Map unavailable").font(.footnote).foregroundStyle(Palette.inkSoft))
        }
    }
}

extension MapGeometry {
    /// Bounding box of the wine areas (map units); the focus country when there are none.
    var contentBounds: CGRect {
        let a = areas.filter { $0.level == 0 }.map { $0.path.boundingRect }.reduce(CGRect.null) { $0.union($1) }
        if !a.isNull, a.width > 1 { return a }
        let f = focus.boundingRect
        if !f.isNull, f.width > 1 { return f }
        return CGRect(x: 0, y: 0, width: CGFloat(map.w), height: CGFloat(map.h))
    }

    /// Zoom and offset that center `target` (default: the wine areas) and always cover the whole view with map.
    func fitLayout(size: CGSize, target: CGRect? = nil, padding: CGFloat = 0.1) -> (zoom: CGFloat, offset: CGSize) {
        let W = CGFloat(map.w), H = CGFloat(map.h)
        guard size.width > 0, size.height > 0 else { return (1, .zero) }
        let t = target ?? contentBounds
        let fit = size.width / W
        let cover = max(size.width / W, size.height / H)
        let content = min(size.width * (1 - 2 * padding) / max(1, t.width), size.height * (1 - 2 * padding) / max(1, t.height))
        let s = min(max(cover, content), cover * 10)
        func axis(_ v: CGFloat, view: CGFloat, content: CGFloat) -> CGFloat {
            if content <= view { return (view - content) / 2 }
            return min(0, max(view - content, v))
        }
        let off = CGSize(width: axis(size.width / 2 - t.midX * s, view: size.width, content: W * s),
                         height: axis(size.height / 2 - t.midY * s, view: size.height, content: H * s))
        return (s / fit, off)
    }

    /// The smallest zoom (relative to fitting the width) that still covers the view.
    func coverZoom(size: CGSize) -> CGFloat {
        let W = CGFloat(map.w), H = CGFloat(map.h)
        guard size.width > 0 else { return 1 }
        return max(size.width / W, size.height / H) / (size.width / W)
    }
}

// MARK: - Interactive, zoomable map

struct ZoomableWineMap: View {
    let mapID: String
    var highlight: Set<String> = []
    var focus: String? = nil
    var forcedLevel: Int? = nil
    var zoomCommand: Int = 0
    @Binding var selected: String?
    @Binding var zoom: CGFloat
    @State private var absZoom: CGFloat = 1
    @State private var lodBase: CGFloat = 1

    @State private var offset: CGSize = .zero
    @State private var baseZoom: CGFloat = 1
    @State private var baseOffset: CGSize = .zero
    @State private var pinchAnchor: CGPoint? = nil
    @Environment(\.colorScheme) private var scheme

    private let maxZoom: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            if let g = MapGeometry.get(mapID) {
                let size = geo.size
                Canvas { ctx, sz in
                    var r = MapRenderer(g: g)
                    r.zoom = absZoom
                    r.lodBase = lodBase
                    r.offset = offset
                    r.highlight = highlight
                    r.selected = selected
                    r.dark = scheme == .dark
                    r.forcedLevel = forcedLevel
                    r.draw(in: &ctx, size: sz)
                }
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnifyGesture()
                            .onChanged { v in
                                let anchor = CGPoint(x: v.startAnchor.x * size.width, y: v.startAnchor.y * size.height)
                                let newZoom = min(lodBase * 12, max(g.coverZoom(size: size), baseZoom * v.magnification))
                                let k = newZoom / baseZoom
                                absZoom = newZoom
                                offset = clamp(CGSize(width: anchor.x - (anchor.x - baseOffset.width) * k,
                                                      height: anchor.y - (anchor.y - baseOffset.height) * k), size: size, g: g)
                            }
                            .onEnded { _ in baseZoom = absZoom; baseOffset = offset },
                        DragGesture(minimumDistance: 4)
                            .onChanged { v in
                                offset = clamp(CGSize(width: baseOffset.width + v.translation.width,
                                                      height: baseOffset.height + v.translation.height), size: size, g: g)
                            }
                            .onEnded { _ in baseOffset = offset }
                    )
                )
                .onTapGesture(count: 2) { pt in
                    zoomBy(2, at: pt, size: size, g: g)
                }
                .onChange(of: zoomCommand) { old, new in
                    zoomBy(new > old ? 1.8 : 1 / 1.8, at: CGPoint(x: size.width / 2, y: size.height / 2), size: size, g: g)
                }
                .onTapGesture { pt in
                    var r = MapRenderer(g: g)
                    r.zoom = absZoom
                    r.lodBase = lodBase
                    r.offset = offset
                    let m = r.toMap(pt, size: size)
                    r.forcedLevel = forcedLevel
                    if let a = g.hit(m, maxLevel: r.visibleLevel()) {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { selected = a.id }
                    } else {
                        selected = nil
                    }
                }
                .onAppear { fitInitial(size: size, g: g) }
                .onChange(of: size) { _, new in fitInitial(size: new, g: g) }
            }
        }
        .clipped()
        .onChange(of: absZoom) { _, v in zoom = v / max(0.01, lodBase) }
    }

    /// Open centered on the wine areas (or the focused one), with the map covering the whole screen.
    private func fitInitial(size: CGSize, g: MapGeometry) {
        guard size.width > 0 else { return }
        // detail levels are measured from the whole-map view
        let (base, _) = g.fitLayout(size: size, padding: 0.14)
        // open wide: the wine areas plus a generous ring of the surrounding country and neighbours
        let c = g.contentBounds
        var target: CGRect? = c.insetBy(dx: -c.width * 0.35, dy: -c.height * 0.35)
        if let f = focus, let a = g.areas.first(where: { $0.id == f }) {
            let b = a.path.boundingRect
            let side = max(max(b.width, b.height) * 7, min(c.width, c.height) * 0.6)
            target = CGRect(x: b.midX - side / 2, y: b.midY - side / 2, width: side, height: side)
        }
        // leave room for the header and the bottom card
        let (z, o) = g.fitLayout(size: size, target: target, padding: 0.14)
        absZoom = z; baseZoom = z; lodBase = base
        zoom = z / max(0.01, base)
        offset = clamp(CGSize(width: o.width, height: o.height + size.height * 0.04), size: size, g: g)
        baseOffset = offset
    }

    private func zoomBy(_ k: CGFloat, at pt: CGPoint, size: CGSize, g: MapGeometry) {
        let newZoom = min(lodBase * 12, max(g.coverZoom(size: size), absZoom * k))
        let f = newZoom / absZoom
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            absZoom = newZoom
            offset = clamp(CGSize(width: pt.x - (pt.x - offset.width) * f, height: pt.y - (pt.y - offset.height) * f), size: size, g: g)
        }
        baseZoom = absZoom; baseOffset = offset
    }

    private func contentSize(_ size: CGSize, g: MapGeometry) -> CGSize {
        let fit = size.width / CGFloat(g.map.w)
        return CGSize(width: CGFloat(g.map.w) * fit * absZoom, height: CGFloat(g.map.h) * fit * absZoom)
    }

    private func centeredOffset(size: CGSize, g: MapGeometry) -> CGSize {
        let c = contentSize(size, g: g)
        return CGSize(width: 0, height: (size.height - c.height) / 2)
    }

    private func clamp(_ o: CGSize, size: CGSize, g: MapGeometry) -> CGSize {
        let c = contentSize(size, g: g)
        func axis(_ v: CGFloat, view: CGFloat, content: CGFloat) -> CGFloat {
            if content <= view { return (view - content) / 2 }
            return min(0, max(view - content, v))
        }
        return CGSize(width: axis(o.width, view: size.width, content: c.width),
                      height: axis(o.height, view: size.height, content: c.height))
    }
}

/// Full-screen map with pinch-to-zoom; deeper levels appear as you zoom in.
struct MapExplorer: View {
    let mapID: String
    var highlight: Set<String> = []
    var focus: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String? = nil
    @State private var zoom: CGFloat = 1
    @State private var openRegion: Region? = nil
    @State private var resetToken = 0
    @State private var layer: Int? = nil
    @State private var zoomCommand = 0
    @State private var listExpanded = false

    var body: some View {
        let g = MapGeometry.get(mapID)
        ZStack(alignment: .top) {
            Palette.sea.ignoresSafeArea()
            ZoomableWineMap(mapID: mapID, highlight: highlight, focus: highlight.count == 1 ? highlight.first : focus,
                            forcedLevel: layer, zoomCommand: zoomCommand, selected: $selected, zoom: $zoom)
                .id(resetToken)
                .ignoresSafeArea()

            // header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Wine map", color: Palette.wine)
                    Text(g?.map.title ?? "").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(levelHint).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.focusLand.opacity(0.94)))
                Spacer()
                VStack(spacing: 10) {
                    circleButton("xmark") { dismiss() }
                    if zoom > 1.01 { circleButton("arrow.down.right.and.arrow.up.left") { resetToken += 1; zoom = 1; selected = nil } }
                    Spacer().frame(height: 6)
                    circleButton("plus") { zoomCommand += 1 }
                    circleButton("minus") { zoomCommand -= 1 }
                    if (g?.maxLevel ?? 0) > 0 {
                        Menu {
                            Picker("Detail", selection: $layer) {
                                Text("Automatic").tag(Int?.none)
                                Text("Regions").tag(Int?.some(0))
                                Text("Appellations").tag(Int?.some(1))
                                if (g?.maxLevel ?? 0) >= 2 { Text("Villages & crus").tag(Int?.some(2)) }
                            }
                        } label: {
                            Image(systemName: "square.3.layers.3d").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Palette.focusLand.opacity(0.94)))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack {
                Spacer()
                if let id = selected, let a = g?.areas.first(where: { $0.id == id }) {
                    selectedCard(a, g: g!)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let g {
                    let lv = min(g.maxLevel, layer ?? (zoom >= 3.2 ? 2 : (zoom >= 1.9 ? 1 : 0)))
                    MapListCard(mapID: mapID, level: lv, expanded: $listExpanded) { id in selected = id }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selected)
        .sheet(item: $openRegion) { r in
            NavigationStack {
                RegionDetailView(region: r)
                    .navigationDestination(for: Grape.self) { g in GrapeDetailView(grape: g) }
                    .navigationDestination(for: Region.self) { r in RegionDetailView(region: r) }
            }
        }
        .onAppear { if highlight.count == 1 { selected = highlight.first } }
    }

    private var levelHint: String {
        guard let g = MapGeometry.get(mapID) else { return "" }
        if g.maxLevel == 0 { return "Regions" }
        if let l = layer { return ["Regions", "Appellations", "Villages & crus"][min(2, l)] }
        if zoom >= 3.2 && g.maxLevel >= 2 { return "Villages & crus" }
        if zoom >= 1.9 { return "Appellations · zoom for more" }
        return "Regions · zoom in for appellations"
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Palette.focusLand.opacity(0.94)))
        }
    }

    private func selectedCard(_ a: MapGeometry.Area, g: MapGeometry) -> some View {
        let region = ContentStore.shared.region(a.id)
        let parent = a.parent.flatMap { p in g.areas.first { $0.id == p } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 4).fill(Palette.mapColor(a.color)).frame(width: 6, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    if let p = parent { Eyebrow(p.name) }
                    Text(a.name).font(.system(size: 21, weight: .bold)).foregroundStyle(Palette.ink)
                }
                Spacer()
                Button { selected = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.inkFaint)
                }
            }
            if let gr = a.grapes ?? region?.grapes.compactMap({ ContentStore.shared.grape($0)?.name }).prefix(3).joined(separator: " · ") , !gr.isEmpty {
                Text(gr).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Palette.mapColor(a.color).mix(with: .black, 0.15))
            }
            if let r = region {
                Text(r.summary).font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2).lineLimit(3)
                Button { openRegion = r } label: {
                    HStack(spacing: 6) {
                        Text("Open guide").font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Palette.wine)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
    }
}


/// Numbered key for a map's areas (matches the badges drawn on the map): a tidy two-column list.
struct MapLegend: View {
    let mapID: String
    var level: Int = 0
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        if let g = MapGeometry.get(mapID) {
            let list = g.numbered(level: level)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .leading), GridItem(.flexible(), spacing: 10, alignment: .leading)],
                      alignment: .leading, spacing: 8) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, a in
                    Button { onSelect?(a.id) } label: {
                        HStack(spacing: 8) {
                            Text("\(i + 1)").font(.system(size: 9.5, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Palette.mapColor(a.color).mix(with: .black, 0.28)))
                            Text(a.name).font(.system(size: 13)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
        }
    }
}

/// Bottom card on the full map: numbered list of the areas shown, collapsible.
struct MapListCard: View {
    let mapID: String
    var level: Int = 0
    @Binding var expanded: Bool
    var onSelect: (String) -> Void

    var body: some View {
        if let g = MapGeometry.get(mapID) {
            let list = g.numbered(level: level)
            let title = level == 0 ? "Regions" : (level == 1 ? "Appellations" : "Villages & crus")
            VStack(spacing: 0) {
                Capsule().fill(Palette.line).frame(width: 36, height: 4).padding(.top, 8)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("\(list.count)").font(.system(size: 13).monospacedDigit()).foregroundStyle(Palette.inkFaint)
                        Spacer()
                        Text("Pinch to zoom").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                        Image(systemName: expanded ? "chevron.down" : "chevron.up").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft).padding(.leading, 6)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Hairline()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, a in
                            Button { onSelect(a.id) } label: {
                                HStack(spacing: 12) {
                                    Text("\(i + 1)").font(.system(size: 10.5, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Palette.mapColor(a.color).mix(with: .black, 0.28)))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a.name).font(.system(size: 15)).foregroundStyle(Palette.ink).lineLimit(1)
                                        if let gr = a.grapes ?? ContentStore.shared.region(a.id)?.grapes.prefix(2).compactMap({ ContentStore.shared.grape($0)?.name }).joined(separator: " · "), !gr.isEmpty {
                                            Text(gr).font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: expanded ? 330 : 150)
            }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 4)
        }
    }
}
