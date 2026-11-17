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

    func visibleLevel() -> Int {
        if zoom >= LOD.level2 { return 2 }
        if zoom >= LOD.level1 { return 1 }
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
            layer.stroke(g.land, with: .color(Palette.border), lineWidth: hair * 0.8)
            layer.fill(g.focus, with: .color(Palette.focusLand))
            layer.stroke(g.borders, with: .color(Palette.adminLine), lineWidth: hair * 0.8)

            if g.map.belts != nil {
                layer.fill(g.focus, with: .color(Palette.bordeaux.opacity(dark ? 0.8 : 0.85)))
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
            if zoom >= LOD.communes {
                regions.stroke(g.communes, with: .color(Palette.focusLand.opacity(0.75)), lineWidth: hair * 0.7)
            }
            layer.fill(g.lakes, with: .color(Palette.sea))
            for (r, w) in g.rivers {
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

        // Region and appellation labels: highlighted first, then by level and size.
        let shownLevel = lv
        let candidates = g.areas.filter { a in
            if a.level > shownLevel { return false }
            if g.hasChildren.contains(a.id) && a.level < shownLevel && zoom > LOD.level1 * 1.4 { return false }
            return true
        }.sorted { a, b in
            let ha = highlight.contains(a.id) || selected == a.id, hb = highlight.contains(b.id) || selected == b.id
            if ha != hb { return ha }
            if a.level != b.level { return a.level < b.level }
            return a.area > b.area
        }
        for a in candidates {
            let isHL = highlight.contains(a.id) || selected == a.id
            let top = a.level == 0 && !(lv >= 1 && g.hasChildren.contains(a.id))
            let name = top ? a.name.uppercased() : a.name
            let font: Font = top ? .display(15 * ls, .heavy) : .system(size: (a.level == 1 ? 11.5 : 10.5) * ls, weight: .bold)
            var title = Text(name).font(font).foregroundColor(Palette.ink)
            if top { title = title.kerning(0.6) }
            let c = screen(a.centroid)
            if top, let l = a.label, zoom < LOD.level1 {
                // Wine Folly-style callout with a leader line and the main grapes.
                let lp = screen(l)
                var block = title
                if let gr = a.grapes {
                    block = block + Text("\n" + gr.uppercased()).font(.system(size: 7.5 * ls, weight: .semibold)).foregroundColor(Palette.inkSoft)
                }
                let anchor: UnitPoint = lp.x < c.x ? .trailing : .leading
                if let r = place(block, at: lp, anchor: anchor, force: isHL) {
                    var line = Path()
                    line.move(to: c)
                    line.addLine(to: CGPoint(x: anchor == .trailing ? r.maxX + 3 : r.minX - 3, y: r.midY))
                    ctx.stroke(line, with: .color(Palette.ink.opacity(0.75)), lineWidth: 0.8)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(Palette.ink))
                    continue
                }
            }
            if place(title, at: c, anchor: .center, force: isHL) == nil {
                _ = place(title, at: CGPoint(x: c.x + 8, y: c.y), anchor: .leading)
                    ?? place(title, at: CGPoint(x: c.x - 8, y: c.y), anchor: .trailing)
            }
        }

        if zoom >= LOD.villages, let vs = g.map.villages {
            for v in vs {
                let p = screen(CGPoint(x: CGFloat(v.x), y: CGFloat(v.y)))
                guard full.contains(p) else { continue }
                _ = place(Text(v.n).font(.system(size: 9 * ls, weight: .medium).italic()).foregroundColor(Palette.inkSoft), at: p, anchor: .center)
            }
        }

        if showCities {
            for c in g.map.cities where (c.r ?? 1) == 0 || zoom >= 1.5 {
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
    }
}

// MARK: - Static map (cards, lessons)

struct WineMapView: View {
    let mapID: String
    var highlight: Set<String> = []
    var showLabels = true
    var showCities = true
    var labelScale: CGFloat = 1
    var onSelect: ((String) -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let g = MapGeometry.get(mapID) {
            Canvas { ctx, size in
                var r = MapRenderer(g: g)
                r.highlight = highlight
                r.showLabels = showLabels
                r.showCities = showCities
                r.labelScale = labelScale
                r.dark = scheme == .dark
                // highlighted deeper areas need their level visible
                let deepest = g.areas.filter { highlight.contains($0.id) }.map(\.level).max() ?? 0
                if deepest >= 2 { r.zoom = 1.0001 }
                r.draw(in: &ctx, size: size)
                if deepest >= 1 {
                    // draw highlighted sub-areas on top even at zoom 1
                    let s = size.width / CGFloat(g.map.w)
                    ctx.drawLayer { layer in
                        layer.scaleBy(x: s, y: s)
                        for a in g.areas where highlight.contains(a.id) && a.level >= 1 {
                            layer.fill(a.path, with: .color(Palette.mapColor(a.color).mix(with: .black, 0.2)))
                            layer.stroke(a.path, with: .color(Palette.ink), lineWidth: 2 / s)
                        }
                    }
                }
            }
            .aspectRatio(CGFloat(g.map.w) / CGFloat(g.map.h), contentMode: .fit)
            .overlay {
                if let onSelect {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { pt in
                                let r = MapRenderer(g: g)
                                let m = r.toMap(pt, size: geo.size)
                                if let a = g.hit(m, maxLevel: 0) ?? g.hit(m, maxLevel: 2) {
                                    Haptics.tap()
                                    onSelect(a.id)
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

// MARK: - Interactive, zoomable map

struct ZoomableWineMap: View {
    let mapID: String
    var highlight: Set<String> = []
    var focus: String? = nil
    @Binding var selected: String?
    @Binding var zoom: CGFloat

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
                    r.zoom = zoom
                    r.offset = offset
                    r.highlight = highlight
                    r.selected = selected
                    r.dark = scheme == .dark
                    r.draw(in: &ctx, size: sz)
                }
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnifyGesture()
                            .onChanged { v in
                                let anchor = CGPoint(x: v.startAnchor.x * size.width, y: v.startAnchor.y * size.height)
                                let newZoom = min(maxZoom, max(1, baseZoom * v.magnification))
                                let k = newZoom / baseZoom
                                zoom = newZoom
                                offset = clamp(CGSize(width: anchor.x - (anchor.x - baseOffset.width) * k,
                                                      height: anchor.y - (anchor.y - baseOffset.height) * k), size: size, g: g)
                            }
                            .onEnded { _ in baseZoom = zoom; baseOffset = offset },
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
                .onTapGesture { pt in
                    var r = MapRenderer(g: g)
                    r.zoom = zoom
                    r.offset = offset
                    let m = r.toMap(pt, size: size)
                    if let a = g.hit(m, maxLevel: r.visibleLevel()) {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { selected = a.id }
                    } else {
                        selected = nil
                    }
                }
                .onAppear {
                    offset = centeredOffset(size: size, g: g)
                    baseOffset = offset
                    if let f = focus, let a = g.areas.first(where: { $0.id == f }) {
                        let fit = size.width / CGFloat(g.map.w)
                        let b = a.path.boundingRect
                        let z = min(10, max(1, min(size.width * 0.7 / (b.width * fit), size.height * 0.5 / (b.height * fit))))
                        zoom = z; baseZoom = z
                        let s = fit * z
                        offset = clamp(CGSize(width: size.width / 2 - b.midX * s, height: size.height * 0.45 - b.midY * s), size: size, g: g)
                        baseOffset = offset
                    }
                }
            }
        }
        .clipped()
    }

    func reset(size: CGSize, g: MapGeometry) {
        zoom = 1; baseZoom = 1
        offset = centeredOffset(size: size, g: g); baseOffset = offset
    }

    private func zoomBy(_ k: CGFloat, at pt: CGPoint, size: CGSize, g: MapGeometry) {
        let newZoom = min(maxZoom, max(1, zoom * k))
        let f = newZoom / zoom
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            zoom = newZoom
            offset = clamp(CGSize(width: pt.x - (pt.x - offset.width) * f, height: pt.y - (pt.y - offset.height) * f), size: size, g: g)
        }
        baseZoom = zoom; baseOffset = offset
    }

    private func contentSize(_ size: CGSize, g: MapGeometry) -> CGSize {
        let fit = size.width / CGFloat(g.map.w)
        return CGSize(width: CGFloat(g.map.w) * fit * zoom, height: CGFloat(g.map.h) * fit * zoom)
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

    var body: some View {
        let g = MapGeometry.get(mapID)
        ZStack(alignment: .top) {
            Palette.sea.ignoresSafeArea()
            ZoomableWineMap(mapID: mapID, highlight: highlight, focus: highlight.count == 1 ? highlight.first : focus, selected: $selected, zoom: $zoom)
                .id(resetToken)
                .ignoresSafeArea()

            // header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WINE MAP OF").font(.system(size: 10, weight: .bold)).kerning(1.6).foregroundStyle(Palette.inkSoft)
                    Text((g?.map.title ?? "").uppercased()).font(.display(30)).foregroundStyle(Palette.ink)
                    Text(levelHint).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.focusLand.opacity(0.94)))
                Spacer()
                VStack(spacing: 10) {
                    circleButton("xmark") { dismiss() }
                    if zoom > 1.01 { circleButton("arrow.down.right.and.arrow.up.left") { resetToken += 1; zoom = 1; selected = nil } }
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
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.pinch").font(.system(size: 13, weight: .semibold))
                        Text("Pinch to zoom · tap a region").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Palette.focusLand.opacity(0.94)))
                    .padding(.bottom, 20)
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
                    Text(a.name.uppercased()).font(.display(26)).foregroundStyle(Palette.ink)
                }
                Spacer()
                Button { selected = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.inkFaint)
                }
            }
            if let gr = a.grapes ?? region?.grapes.compactMap({ ContentStore.shared.grape($0)?.name }).prefix(3).joined(separator: " · ") , !gr.isEmpty {
                Text(gr.uppercased()).font(.system(size: 11, weight: .bold)).kerning(0.8).foregroundStyle(Palette.mapColor(a.color))
            }
            if let r = region {
                Text(r.summary).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2).lineLimit(3)
                Button { openRegion = r } label: {
                    HStack(spacing: 6) {
                        Text("Open guide").font(.system(size: 15, weight: .bold))
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
