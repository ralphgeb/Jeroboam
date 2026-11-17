import SwiftUI

/// Sunburst aroma wheel: inner ring = primary/secondary/tertiary, outer ring = categories.
struct AromaWheel: View {
    var compact = false
    @Binding var selected: String?

    init(compact: Bool = false, selected: Binding<String?> = .constant(nil)) {
        self.compact = compact
        self._selected = selected
    }

    var body: some View {
        let groups = ContentStore.shared.library.aromas
        let cats = groups.flatMap { g in g.categories.map { (g, $0) } }
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Canvas { ctx, _ in
                    let total = Double(max(1, cats.count))
                    let rIn: CGFloat = s * 0.17, rMid: CGFloat = s * 0.29, rOut: CGFloat = s * 0.48
                    var start = -90.0
                    for g in groups {
                        let span = 360.0 * Double(g.categories.count) / total
                        let groupTone = groupColor(g.id)
                        ctx.fill(ring(c, rIn, rMid, start, start + span), with: .color(groupTone))
                        ctx.stroke(ring(c, rIn, rMid, start, start + span), with: .color(Palette.paper), lineWidth: 1.5)
                        // label on inner ring
                        let mid = (start + span / 2) * Double.pi / 180
                        let lp = CGPoint(x: c.x + CGFloat(cos(mid)) * (rIn + rMid) / 2, y: c.y + CGFloat(sin(mid)) * (rIn + rMid) / 2)
                        if !compact {
                            var lt = ctx
                            lt.translateBy(x: lp.x, y: lp.y)
                            var tdeg = (start + span / 2 + 90).truncatingRemainder(dividingBy: 360)
                            if tdeg > 180 { tdeg -= 360 }
                            if tdeg < -180 { tdeg += 360 }
                            if tdeg > 90 { tdeg -= 180 }
                            if tdeg < -90 { tdeg += 180 }
                            lt.rotate(by: .degrees(tdeg))
                            lt.draw(Text(g.name.uppercased()).font(.system(size: 8, weight: .bold)).kerning(1.0).foregroundColor(.white), at: .zero)
                        }
                        var a = start
                        for cat in g.categories {
                            let step = 360.0 / total
                            let isSel = selected == cat.id
                            let base = Color(hex: cat.color)
                            let path = ring(c, rMid + 2, isSel ? rOut + s * 0.015 : rOut, a, a + step)
                            ctx.fill(path, with: .color(selected == nil || isSel ? base : base.opacity(0.35)))
                            ctx.stroke(path, with: .color(Palette.paper), lineWidth: 1.5)
                            if !compact {
                                let m = (a + step / 2) * Double.pi / 180
                                let rr = (rMid + rOut) / 2
                                let p = CGPoint(x: c.x + CGFloat(cos(m)) * rr, y: c.y + CGFloat(sin(m)) * rr)
                                var t = ctx
                                t.translateBy(x: p.x, y: p.y)
                                var deg = (a + step / 2)
                                if deg > 90 && deg < 270 { deg += 180 }
                                t.rotate(by: .degrees(deg))
                                let avail = rOut - rMid - 10
                                let ink = Color(hex: cat.color).mix(with: .black, 0.62)
                                let probe = t.resolve(Text(cat.name).font(.system(size: 10, weight: .bold)))
                                let wNeeded = probe.measure(in: CGSize(width: 400, height: 40)).width
                                let fs = max(6.5, min(10.5, 10 * avail / max(1, wNeeded)))
                                t.draw(Text(cat.name).font(.system(size: fs, weight: .bold)).foregroundColor(ink), at: .zero)
                            }
                            a += step
                        }
                        start += span
                    }
                }
                VStack(spacing: 2) {
                    Image(systemName: "nose").font(.system(size: compact ? 14 : 18, weight: .light)).foregroundStyle(Palette.wine)
                    if !compact { Text("Aromas").font(.serif(13)).foregroundStyle(Palette.ink) }
                }
                .position(c)
            }
            .contentShape(Rectangle())
            .onTapGesture { pt in
                guard !compact else { return }
                let dx = pt.x - c.x, dy = pt.y - c.y
                let d = hypot(dx, dy)
                guard d > s * 0.29, d < s * 0.5 else { selected = nil; return }
                var ang = atan2(Double(dy), Double(dx)) * 180 / Double.pi + 90
                if ang < 0 { ang += 360 }
                let idx = Int(ang / (360.0 / Double(max(1, cats.count))))
                if idx < cats.count {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { selected = cats[idx].1.id }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Aroma wheel")
    }

    private func ring(_ c: CGPoint, _ r0: CGFloat, _ r1: CGFloat, _ a0: Double, _ a1: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r1, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
        p.addArc(center: c, radius: r0, startAngle: .degrees(a1), endAngle: .degrees(a0), clockwise: true)
        p.closeSubpath()
        return p
    }

    private func groupColor(_ id: String) -> Color {
        switch id {
        case "primary": return Color(hex: "#7C8C62")
        case "secondary": return Color(hex: "#A9824A")
        default: return Color(hex: "#7D1D3F")
        }
    }
}

struct AromaWheelMini: View {
    var body: some View { AromaWheel(compact: true) }
}

struct AromaWheelScreen: View {
    @State private var selected: String? = nil

    var body: some View {
        let lib = ContentStore.shared.library
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: "The nose", title: "Aroma wheel",
                             subtitle: "Aromas come from three sources: the **grape** (primary), **winemaking** (secondary) and **ageing** (tertiary). Tap a slice to see its descriptors.")
                AromaWheel(selected: $selected)
                    .padding(.horizontal, -8)

                if let id = selected, let cat = ContentStore.shared.allAromaCategories().first(where: { $0.id == id }) {
                    categoryCard(cat)
                        .transition(.opacity)
                }

                ForEach(lib.aromas) { g in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionTitle(text: g.name)
                        }
                        Text(rich(g.summary)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(g.categories) { cat in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: cat.color)).frame(width: 9, height: 9)
                                    Text(cat.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                }
                                iconGrid(cat.items)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    Hairline()
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryCard(_ cat: AromaCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: cat.icon).font(.system(size: 16)).foregroundStyle(Color(hex: cat.color).mix(with: .black, 0.3))
                Text(cat.name).font(.sectionTitle).foregroundStyle(Palette.ink)
                Spacer()
                Button { selected = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint) }
            }
            if let n = cat.note { Text(rich(n)).font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2.5) }
            iconGrid(cat.items)
        }
        .cardStyle()
    }

    private func iconGrid(_ items: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), alignment: .center, spacing: 12) {
            ForEach(items, id: \.self) { a in
                VStack(spacing: 5) {
                    FlavorIcon(aroma: a, size: 30)
                    Text(a).font(.system(size: 10.5)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.85)
                }
            }
        }
    }
}
