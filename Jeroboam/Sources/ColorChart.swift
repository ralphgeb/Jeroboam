import SwiftUI
import CoreMotion

/// Device tilt shared by every liquid swatch. A damped spring follows gravity, so the wine sloshes and settles.
@Observable final class Tilt {
    static let shared = Tilt()
    private(set) var angle: Double = 0      // direction of "down" on screen, radians (0 = straight down)
    private(set) var wave: Double = 0       // slosh amplitude, 0…1
    private(set) var phase: Double = 0
    private var velocity: Double = 0
    private var target: Double = 0
    private let motion = CMMotionManager()
    private var users = 0
    private var timer: Timer?

    func start() {
        users += 1
        guard users == 1 else { return }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
                guard let self, let g = m?.gravity else { return }
                // Ignore direction when the phone lies flat; the wine then settles back.
                if hypot(g.x, g.y) > 0.12 { self.target = max(-1.2, min(1.2, atan2(g.x, -g.y))) } else { self.target = 0 }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.step(1 / 60) }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        motion.stopDeviceMotionUpdates()
        timer?.invalidate(); timer = nil
    }

    private func step(_ dt: Double) {
        let k = 38.0, damping = 5.5
        velocity += (k * (target - angle) - damping * velocity) * dt
        angle += velocity * dt
        wave = min(1, wave * 0.97 + abs(velocity) * 0.025)
        phase += dt * 7
    }
}

/// A pane of wine whose surface stays level as the phone tilts: deeper color pools at the bottom, paler at the surface.
struct LiquidSwatch: View {
    let core: Color
    let rim: Color
    var level: Double = 0.84
    var live = true
    var tilt = Tilt.shared

    var body: some View {
        // Read the tilt here so SwiftUI redraws when it changes.
        let a = live ? tilt.angle : 0, wave = live ? tilt.wave : 0, phase = live ? tilt.phase : 1.2
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let s = max(w, h)
            let down = CGVector(dx: sin(a), dy: cos(a))
            let along = CGVector(dx: cos(a), dy: -sin(a))
            let c = CGPoint(x: w / 2, y: h / 2)
            // Surface sits (level - 0.5) of the pane above the center, measured against gravity.
            let off = -(level - 0.5) * h
            let amp = 2.5 + wave * h * 0.07
            var path = Path()
            let steps = 24
            for i in 0...steps {
                let u = (Double(i) / Double(steps) - 0.5) * s * 1.6
                let y = off + amp * sin(u / s * 7 + phase) * (0.35 + wave)
                let p = CGPoint(x: c.x + along.dx * u + down.dx * y, y: c.y + along.dy * u + down.dy * y)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            let far = s * 1.6
            let e1 = CGPoint(x: c.x + along.dx * 0.8 * far + down.dx * far, y: c.y + along.dy * 0.8 * far + down.dy * far)
            let e2 = CGPoint(x: c.x - along.dx * 0.8 * far + down.dx * far, y: c.y - along.dy * 0.8 * far + down.dy * far)
            path.addLine(to: e1); path.addLine(to: e2); path.closeSubpath()

            let top = CGPoint(x: c.x + down.dx * off, y: c.y + down.dy * off)
            let bottom = CGPoint(x: c.x + down.dx * h * 0.6, y: c.y + down.dy * h * 0.6)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(rim.opacity(0.18)))
            ctx.fill(path, with: .linearGradient(Gradient(colors: [rim, core, core.mix(with: .black, 0.12)]), startPoint: top, endPoint: bottom))
            // A thin bright meniscus along the surface.
            var line = Path()
            for i in 0...steps {
                let u = (Double(i) / Double(steps) - 0.5) * s * 1.6
                let y = off + amp * sin(u / s * 7 + phase) * (0.35 + wave)
                let p = CGPoint(x: c.x + along.dx * u + down.dx * y, y: c.y + along.dy * u + down.dy * y)
                if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            ctx.stroke(line, with: .color(.white.opacity(0.55)), lineWidth: 1)
        }
    }
}

struct ColorChartScreen: View {
    @State private var family = "white"
    @State private var picked: WineColor? = nil
    @Environment(\.windowWidth) private var width
    private var split: Bool { width >= AdaptiveLayout.twoPaneThreshold }
    private var sheetBinding: Binding<WineColor?> { split ? .constant(nil) : $picked }

    var body: some View {
        let colors = ContentStore.shared.library.colors.filter { $0.chart == true && $0.family == family }
        if split {
            // the chart on the left; the open color (the first to begin with) with its glass on the right
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenHeader(eyebrow: "Appearance", title: "Wine color chart", subtitle: "Tap a color to see what it tells you.")
                        Picker("Family", selection: $family) {
                            Text("White").tag("white"); Text("Rosé").tag("rose"); Text("Red").tag("red")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: family) { _, _ in picked = nil }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 4), alignment: .leading, spacing: 14) {
                            ForEach(Array(colors.enumerated()), id: \.element.id) { i, c in
                                Button { picked = c } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        LiquidSwatch(core: Color(hex: c.hex), rim: Color(hex: c.rim), level: 1.2, live: false)
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay(Rectangle().strokeBorder((picked ?? colors.first)?.id == c.id ? Palette.wine : Palette.ink.opacity(0.06),
                                                                              lineWidth: (picked ?? colors.first)?.id == c.id ? 2 : 0.5))
                                        Text(c.name).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Palette.ink)
                                            .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .frame(width: width / 2)
                Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5)
                Group {
                    if let c = picked ?? colors.first { ColorDetailSheet(color: c).id(c.id) } else { Color.clear }
                }
                .frame(width: width / 2 - 0.5)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        } else {
            narrowBody(colors)
        }
    }

    @ViewBuilder private func narrowBody(_ colors: [WineColor]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "Appearance", title: "Wine color chart",
                             subtitle: "Tilt your phone and the wine moves. Tap a color to see what it tells you and which grapes give it.")
                Picker("Family", selection: $family) {
                    Text("White").tag("white")
                    Text("Rosé").tag("rose")
                    Text("Red").tag("red")
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4), alignment: .leading, spacing: 18) {
                    ForEach(Array(colors.enumerated()), id: \.element.id) { i, c in
                        Button { picked = c } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                LiquidSwatch(core: Color(hex: c.hex), rim: Color(hex: c.rim), level: 1.2, live: false)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.06), lineWidth: 0.5))
                                Text(String(format: "%02d", i + 1)).font(.system(size: 10, weight: .medium).monospacedDigit()).foregroundStyle(Palette.inkFaint)
                                Text(c.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                                    .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: family)
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, Metrics.margin)
            .readable(720)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: sheetBinding) { c in ColorDetailSheet(color: c) }
    }
}

struct ColorDetailSheet: View {
    let color: WineColor

    var body: some View {
        let c = color
        let grapes = Self.grapes(for: c)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GlassPool(color: c)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(c.family == "rose" ? "Rosé" : c.family.capitalized)
                    Text(c.name).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(c.note).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.9)).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("What it tells you")
                    Text(Self.reading(c)).font(.system(size: 15)).foregroundStyle(Palette.ink).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle(padding: 16)
                if !grapes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Grapes that give this color")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4), spacing: 12) {
                            ForEach(grapes) { g in
                                VStack(spacing: 4) {
                                    GrapeBadge(grape: g, size: 52)
                                    Text(g.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.ink)
                                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                                }
                            }
                        }
                    }
                }
                if let e = c.examples {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("Wines to look for")
                        Text(e).font(.system(size: 15)).foregroundStyle(Palette.ink)
                    }
                }
            }
            .padding(Metrics.margin).padding(.top, 8)
        }
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { Tilt.shared.start() }
        .onDisappear { Tilt.shared.stop() }
    }

    /// Grapes named in the examples first, then those whose usual glass is this hue.
    static func grapes(for c: WineColor) -> [Grape] {
        let all = ContentStore.shared.library.grapes
        let ex = (c.examples ?? "").lowercased()
        var out = all.filter { g in ex.contains(g.name.lowercased()) || (g.aka ?? []).contains { ex.contains($0.lowercased()) } }
        let base: [String: String] = ["straw": "lemon-green", "yellow": "lemon", "gold": "gold", "amber": "amber", "brown": "brown",
                                      "salmon": "pink", "copper": "pink", "pink": "pink", "ruby": "ruby", "purple": "purple",
                                      "garnet": "garnet", "tawny": "garnet"]
        if let hue = c.id.split(separator: "-").last, let id = base[String(hue)] {
            for g in all where g.glass == id && !out.contains(g) { out.append(g) }
        }
        return Array(out.prefix(8))
    }

    static func reading(_ c: WineColor) -> String {
        let depth: String
        if c.id.contains("pale") { depth = "Pale: light extraction, often a cool climate, a thin-skinned grape or a young wine." }
        else if c.id.contains("deep") { depth = "Deep: lots of color, from thick skins, ripe grapes, long contact with the skins, oak or age." }
        else { depth = "Medium depth: the middle of the road, typical of many classic styles." }
        let hue: String
        switch c.family {
        case "white": hue = "Whites darken with age: lemon turns gold, then amber and brown. Oak and sweetness also deepen the color."
        case "rose": hue = "Rosé color comes from a few hours on the skins. Paler, onion-skin hues are typical of Provence; deeper pinks of Tavel or Navarra."
        default: hue = "Reds fade with age: purple rims are young, ruby is the prime of life, and garnet or tawny rims show years in bottle or barrel."
        }
        return depth + "\n\n" + hue
    }
}

/// The opened color as wine in a glass seen from above: it sloshes when the phone tilts, with the paler rim and a glassy shine.
struct GlassPool: View {
    let color: WineColor
    var body: some View {
        let core = Color(hex: color.hex), rim = Color(hex: color.rim)
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.card)
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
                LiquidSwatch(core: core, rim: rim, level: 0.62)
                    .clipShape(Circle())
                    .padding(10)
                // rim of the bowl: paler where the wine thins out, then the glass edge
                Circle().strokeBorder(rim.opacity(0.55), lineWidth: 6).padding(10)
                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).padding(9)
                Circle().strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.6)
                Circle().trim(from: 0.58, to: 0.72)
                    .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .padding(24)
            }
            .frame(width: 210, height: 210)
            HStack(spacing: 8) {
                Circle().fill(core).frame(width: 12, height: 12)
                Text("Core").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
                Circle().fill(rim).frame(width: 12, height: 12).overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.5))
                    .padding(.leading, 8)
                Text("Rim").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
                Text("· Tilt your phone").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.vertical, 6)
    }
}
