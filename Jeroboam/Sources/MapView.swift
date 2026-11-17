import SwiftUI

/// Pre-built vector paths for a map, in map units (width = map.w).
final class MapGeometry {
    struct Area {
        let id: String
        let name: String
        let small: Bool
        let path: Path
        let label: CGPoint
        let index: Int
        let area: CGFloat
    }

    let map: WineMap
    let land: Path
    let focus: Path
    let lakes: Path
    let landMask: Path
    let rivers: [(Path, CGFloat)]
    let areas: [Area]

    private static var cache: [String: MapGeometry] = [:]
    private static let lock = NSLock()

    static func get(_ id: String) -> MapGeometry? {
        lock.lock(); defer { lock.unlock() }
        if let g = cache[id] { return g }
        guard let m = ContentStore.shared.map(id) else { return nil }
        let g = MapGeometry(m)
        cache[id] = g
        return g
    }

    private init(_ m: WineMap) {
        map = m
        func pts(_ f: [Int]) -> [CGPoint] {
            stride(from: 0, to: f.count - 1, by: 2).map { CGPoint(x: CGFloat(f[$0]), y: CGFloat(f[$0 + 1])) }
        }
        func poly(_ list: [[Int]]) -> Path {
            var p = Path()
            for f in list {
                let ps = pts(f)
                guard ps.count > 2 else { continue }
                p.addLines(ps)
                p.closeSubpath()
            }
            return p
        }
        land = poly(m.land)
        focus = poly(m.focus)
        lakes = poly(m.lakes)
        var mask = Path()
        mask.addPath(land)
        mask.addPath(focus)
        landMask = mask
        rivers = m.rivers.map { r in
            var p = Path()
            p.addLines(pts(r.p))
            return (p, CGFloat(r.w))
        }
        var list: [Area] = []
        for (i, r) in m.regions.enumerated() {
            var p = Path()
            var a: CGFloat = 0
            for s in r.shapes {
                let ps = pts(s)
                guard ps.count > 2 else { continue }
                p.addPath(smoothClosedPath(ps, tension: 0.8))
                a += abs(MapGeometry.area(ps))
            }
            list.append(Area(id: r.id, name: r.name, small: r.small, path: p,
                             label: CGPoint(x: CGFloat(r.lx), y: CGFloat(r.ly)), index: i, area: a))
        }
        areas = list
    }

    static func area(_ p: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }

    /// Smallest region containing the point (map units).
    func hit(_ pt: CGPoint) -> Area? {
        areas.filter { $0.path.contains(pt) }.min { $0.area < $1.area }
            ?? areas.filter { $0.small }.min { hypot($0.label.x - pt.x, $0.label.y - pt.y) < hypot($1.label.x - pt.x, $1.label.y - pt.y) }
                .flatMap { hypot($0.label.x - pt.x, $0.label.y - pt.y) < 30 ? $0 : nil }
    }
}

/// An illustrated wine map: ivory land, quiet sea, claret-tinted regions and fine labels.
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
            let aspect = CGFloat(g.map.w) / CGFloat(g.map.h)
            Canvas { ctx, size in
                draw(g, in: &ctx, size: size)
            }
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                if let onSelect {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { pt in
                                let sc = geo.size.width / CGFloat(g.map.w)
                                if let a = g.hit(CGPoint(x: pt.x / sc, y: pt.y / sc)) {
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

    private func draw(_ g: MapGeometry, in ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / CGFloat(g.map.w)
        let dark = scheme == .dark
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .color(Palette.sea))

        // Wine belts on the world map.
        if let b = g.map.belts, b.count == 4 {
            for i in stride(from: 0, to: 4, by: 2) {
                let band = CGRect(x: 0, y: CGFloat(b[i]) * s, width: size.width, height: CGFloat(b[i + 1] - b[i]) * s)
                ctx.fill(Path(band), with: .color(Palette.wine.opacity(dark ? 0.16 : 0.08)))
                for y in [band.minY, band.maxY] {
                    var l = Path(); l.move(to: CGPoint(x: 0, y: y)); l.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(l, with: .color(Palette.wine.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                }
            }
        }

        ctx.drawLayer { layer in
            layer.scaleBy(x: s, y: s)
            let hair = 0.6 / s
            layer.fill(g.land, with: .color(Palette.land))
            layer.stroke(g.land, with: .color(Palette.border), lineWidth: hair)
            // focus country with a soft lift
            var lifted = layer
            lifted.addFilter(.shadow(color: .black.opacity(dark ? 0.5 : 0.10), radius: 6 / s, x: 0, y: 1.5 / s))
            lifted.fill(g.focus, with: .color(Palette.focusLand))
            layer.stroke(g.focus, with: .color(Palette.border), lineWidth: hair * 1.4)

            // world map: wine countries in claret
            if g.map.belts != nil {
                layer.fill(g.focus, with: .color(Palette.wine.opacity(dark ? 0.55 : 0.32)))
            }

            // regions clipped to land
            var regions = layer
            regions.clip(to: g.landMask)
            for a in g.areas {
                let isHL = highlight.contains(a.id)
                let dim = !highlight.isEmpty && !isHL
                var fill = Palette.regionFill(a.index, dark: dark)
                if isHL { fill = dark ? Color(hex: "#D4738F") : Color(hex: "#7D1D3F") }
                regions.fill(a.path, with: .color(dim ? fill.opacity(0.35) : fill))
                regions.stroke(a.path, with: .color(Palette.focusLand), lineWidth: hair * 1.8)
            }
            layer.fill(g.lakes, with: .color(Palette.sea))
            for (r, w) in g.rivers {
                layer.stroke(r, with: .color(Palette.river), style: StrokeStyle(lineWidth: (w >= 2 ? 1.1 : 0.7) / s, lineCap: .round, lineJoin: .round))
            }
        }

        guard showLabels else { return }
        var taken: [CGRect] = []
        func place(_ text: Text, at p: CGPoint, anchor: UnitPoint, force: Bool = false, halo: Bool = true) -> Bool {
            var t = ctx
            let resolved = t.resolve(text)
            let sz = resolved.measure(in: CGSize(width: 400, height: 100))
            let rect = CGRect(x: p.x - sz.width * anchor.x, y: p.y - sz.height * anchor.y, width: sz.width, height: sz.height)
            if !force {
                if rect.minX < 2 || rect.maxX > size.width - 2 || rect.minY < 2 || rect.maxY > size.height - 2 { return false }
                if taken.contains(where: { $0.insetBy(dx: -2, dy: -1).intersects(rect) }) { return false }
            }
            taken.append(rect)
            if halo { t.addFilter(.shadow(color: Palette.focusLand.opacity(0.95), radius: 1.6)) }
            t.draw(resolved, at: p, anchor: anchor)
            return true
        }
        let ls = labelScale

        // seas, rivers, areas
        for l in g.map.labels {
            let p = CGPoint(x: CGFloat(l.x) * s, y: CGFloat(l.y) * s)
            switch l.k {
            case "sea":
                _ = place(Text(l.t).font(.serif(11 * ls).italic()).foregroundColor(Palette.slate), at: p, anchor: .center, halo: false)
            case "river":
                _ = place(Text(l.t).font(.serif(10 * ls).italic()).foregroundColor(Palette.slate), at: p, anchor: .center)
            default:
                _ = place(Text(l.t.uppercased()).font(.system(size: 8.5 * ls, weight: .semibold)).kerning(1.6).foregroundColor(Palette.inkFaint), at: p, anchor: .center, halo: false)
            }
        }

        // regions: highlighted first, then large, then small
        let ordered = g.areas.sorted { a, b in
            let ha = highlight.contains(a.id), hb = highlight.contains(b.id)
            if ha != hb { return ha }
            return a.area > b.area
        }
        for a in ordered {
            let isHL = highlight.contains(a.id)
            let p = CGPoint(x: a.label.x * s, y: a.label.y * s)
            let color: Color = isHL ? Palette.wine : Palette.ink
            let txt = Text(a.name.uppercased())
                .font(.system(size: (isHL ? 10 : 9) * ls, weight: isHL ? .bold : .semibold))
                .kerning(0.9)
                .foregroundColor(color)
            if !place(txt, at: p, anchor: .center, force: isHL) {
                // try beside the region
                _ = place(txt, at: CGPoint(x: p.x + 8, y: p.y), anchor: .leading)
                    || place(txt, at: CGPoint(x: p.x - 8, y: p.y), anchor: .trailing)
                    || place(txt, at: CGPoint(x: p.x, y: p.y - 10), anchor: .bottom)
                    || place(txt, at: CGPoint(x: p.x, y: p.y + 10), anchor: .top)
            }
        }

        if showCities {
            for c in g.map.cities {
                let p = CGPoint(x: CGFloat(c.x) * s, y: CGFloat(c.y) * s)
                let dotR: CGFloat = 2.2
                let txt = Text(c.n).font(.system(size: 10 * ls, weight: .regular)).foregroundColor(Palette.inkSoft)
                if place(txt, at: CGPoint(x: p.x + 5, y: p.y), anchor: .leading)
                    || place(txt, at: CGPoint(x: p.x - 5, y: p.y), anchor: .trailing) {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2)), with: .color(Palette.ink))
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2)), with: .color(Palette.focusLand), lineWidth: 0.8)
                }
            }
        }
    }
}

/// Full-screen map with pinch-to-zoom and a region list.
struct MapExplorer: View {
    let mapID: String
    var highlight: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var selected: String? = nil
    @State private var openRegion: Region? = nil

    var body: some View {
        NavigationStack {
            let g = MapGeometry.get(mapID)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        WineMapView(mapID: mapID, highlight: selected.map { [$0] } ?? highlight, labelScale: 1 / max(1, zoom * 0.85)) { id in
                            selected = id
                        }
                        .frame(width: (UIScreen.main.bounds.width - 32) * zoom)
                    }
                    .frame(height: min(560, (UIScreen.main.bounds.width - 32) * CGFloat(g?.map.h ?? 1) / CGFloat(g?.map.w ?? 1)))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .gesture(MagnifyGesture()
                        .onChanged { v in zoom = min(3.5, max(1, lastZoom * v.magnification)) }
                        .onEnded { _ in lastZoom = zoom })
                    .padding(.horizontal, 16)

                    if let id = selected, let a = g?.areas.first(where: { $0.id == id }) {
                        selectedCard(a)
                            .padding(.horizontal, Metrics.margin)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if let g {
                        VStack(alignment: .leading, spacing: 0) {
                            Eyebrow("Regions on this map").padding(.bottom, 10)
                            ForEach(g.areas.sorted { $0.name < $1.name }, id: \.id) { a in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { selected = a.id }
                                } label: {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 3).fill(Palette.regionFill(a.index, dark: false)).frame(width: 14, height: 14)
                                        Text(a.name).font(.system(size: 16)).foregroundStyle(Palette.ink)
                                        Spacer()
                                        if ContentStore.shared.region(a.id) != nil {
                                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Hairline()
                            }
                        }
                        .padding(.horizontal, Metrics.margin)
                    }
                    Text("Region outlines are illustrative. Base map: Natural Earth.")
                        .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                        .padding(.horizontal, Metrics.margin).padding(.bottom, 30)
                }
                .padding(.top, 8)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle(g?.map.title ?? "Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.wine)
                }
            }
            .sheet(item: $openRegion) { r in
                NavigationStack {
                    RegionDetailView(region: r)
                        .navigationDestination(for: Grape.self) { g in GrapeDetailView(grape: g) }
                        .navigationDestination(for: Region.self) { r in RegionDetailView(region: r) }
                }
            }
        }
        .onAppear { if highlight.count == 1 { selected = highlight.first } }
    }

    private func selectedCard(_ a: MapGeometry.Area) -> some View {
        let region = ContentStore.shared.region(a.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text(a.name).font(.serif(22))
                .foregroundStyle(Palette.ink)
            if let r = region {
                Text(r.summary).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(3).lineLimit(3)
                let grapes = ContentStore.shared.grapes(inRegion: r.id)
                if !grapes.isEmpty {
                    Text(grapes.map(\.name).joined(separator: " · ")).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.wine)
                }
                Button("Open region guide") { openRegion = r }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
