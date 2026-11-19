import SwiftUI

/// Bold silhouette glasses (owner's reference): a dark glass outline with an open bowl,
/// a flat pool of wine inside and a flared stem and foot. One renderer for every glass in the app.
enum GlassArt {
    struct Shape {
        var rim: CGFloat      // half-width at the rim (fraction of width)
        var widest: CGFloat   // half-width at the widest point
        var widestY: CGFloat  // y of the widest point (fraction of height)
        var bottom: CGFloat   // y of the inner bowl bottom
        var stemTop: CGFloat  // y where the stem starts
        static let red = Shape(rim: 0.33, widest: 0.47, widestY: 0.30, bottom: 0.53, stemTop: 0.62)
        static let white = Shape(rim: 0.29, widest: 0.39, widestY: 0.27, bottom: 0.50, stemTop: 0.59)
        static let flute = Shape(rim: 0.19, widest: 0.21, widestY: 0.22, bottom: 0.60, stemTop: 0.67)
        static let tasting = Shape(rim: 0.30, widest: 0.44, widestY: 0.32, bottom: 0.54, stemTop: 0.63)
    }

    static func bowl(_ s: Shape, in r: CGRect, inset: CGFloat = 0, topInset: CGFloat = 0) -> Path {
        let cx = r.midX, w = r.width, h = r.height
        let y0 = r.minY + topInset, ym = r.minY + h * s.widestY, yb = r.minY + h * s.bottom - inset
        let tw = w * s.rim - inset, mw = w * s.widest - inset
        var p = Path()
        p.move(to: CGPoint(x: cx - tw, y: y0))
        p.addCurve(to: CGPoint(x: cx - mw, y: ym), control1: CGPoint(x: cx - tw - (mw - tw) * 0.55, y: y0 + (ym - y0) * 0.35),
                   control2: CGPoint(x: cx - mw, y: ym - (ym - y0) * 0.45))
        p.addCurve(to: CGPoint(x: cx, y: yb), control1: CGPoint(x: cx - mw, y: ym + (yb - ym) * 0.62),
                   control2: CGPoint(x: cx - mw * 0.55, y: yb))
        p.addCurve(to: CGPoint(x: cx + mw, y: ym), control1: CGPoint(x: cx + mw * 0.55, y: yb),
                   control2: CGPoint(x: cx + mw, y: ym + (yb - ym) * 0.62))
        p.addCurve(to: CGPoint(x: cx + tw, y: y0), control1: CGPoint(x: cx + mw, y: ym - (ym - y0) * 0.45),
                   control2: CGPoint(x: cx + tw + (mw - tw) * 0.55, y: y0 + (ym - y0) * 0.35))
        p.closeSubpath()
        return p
    }

    static func draw(_ ctx: inout GraphicsContext, in r: CGRect, shape s: Shape, fill: CGFloat, color: Color,
                     sparkling: Bool, ink: Color, inner: Color) {
        let w = r.width, h = r.height, cx = r.midX
        let wall = max(1.3, w * 0.06)
        // outer glass: bowl grown by the wall, heavier towards the bottom like hand-blown glass
        var outerShape = s
        outerShape.bottom = s.bottom + (s.stemTop - s.bottom) * 0.75
        let outer = bowl(outerShape, in: r.insetBy(dx: -wall * 0.5, dy: 0))
        ctx.fill(outer, with: .color(ink))
        // stem and foot
        let yStem = r.minY + h * s.stemTop
        let yFoot = r.minY + h * 0.955
        let sw = max(1.5, w * 0.055)
        var stem = Path()
        stem.move(to: CGPoint(x: cx - w * 0.16, y: yStem - h * 0.04))
        stem.addQuadCurve(to: CGPoint(x: cx - sw, y: yStem + h * 0.07), control: CGPoint(x: cx - sw * 1.2, y: yStem - h * 0.01))
        stem.addLine(to: CGPoint(x: cx - sw, y: yFoot - h * 0.07))
        stem.addQuadCurve(to: CGPoint(x: cx - w * 0.32, y: yFoot), control: CGPoint(x: cx - sw, y: yFoot - h * 0.01))
        stem.addLine(to: CGPoint(x: cx - w * 0.33, y: yFoot + h * 0.03))
        stem.addLine(to: CGPoint(x: cx + w * 0.33, y: yFoot + h * 0.03))
        stem.addLine(to: CGPoint(x: cx + w * 0.32, y: yFoot))
        stem.addQuadCurve(to: CGPoint(x: cx + sw, y: yFoot - h * 0.07), control: CGPoint(x: cx + sw, y: yFoot - h * 0.01))
        stem.addLine(to: CGPoint(x: cx + sw, y: yStem + h * 0.07))
        stem.addQuadCurve(to: CGPoint(x: cx + w * 0.16, y: yStem - h * 0.04), control: CGPoint(x: cx + sw * 1.2, y: yStem - h * 0.01))
        stem.closeSubpath()
        ctx.fill(stem, with: .color(ink))
        var foot = Path(roundedRect: CGRect(x: cx - w * 0.34, y: yFoot, width: w * 0.68, height: max(1.5, h * 0.03)), cornerRadius: h * 0.015)
        foot.closeSubpath()
        ctx.fill(foot, with: .color(ink))
        // the open bowl
        let innerBowl = bowl(s, in: r.insetBy(dx: wall * 0.5, dy: 0), topInset: max(1, wall * 0.55))
        ctx.fill(innerBowl, with: .color(inner))
        // wine: a flat pool with a small gap from the glass
        let gap = max(1, w * 0.04)
        let wineBowl = bowl(s, in: r.insetBy(dx: wall * 0.5, dy: 0), inset: gap)
        let top = r.minY + h * 0.06, bottom = r.minY + h * s.bottom - gap
        let level = bottom - (bottom - top) * fill
        var wctx = ctx
        wctx.clip(to: wineBowl)
        wctx.fill(Path(CGRect(x: r.minX, y: level, width: w, height: bottom - level + 2)), with: .color(color))
        if sparkling {
            var rng = SeededRandom(seed: 5)
            for _ in 0..<9 {
                let bx = cx + w * 0.18 * CGFloat(rng.next() - 0.5)
                let by = level + CGFloat(rng.next()) * (bottom - level) * 0.85 + 2
                let br = max(0.8, w * 0.022 * CGFloat(0.6 + rng.next()))
                wctx.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(.white.opacity(0.85)))
            }
        }
    }
}

/// A silhouette glass of a given shape.
struct SilhouetteGlass: View {
    var shape: GlassArt.Shape = .red
    var color: Color
    var fill: CGFloat = 0.5
    var sparkling = false
    var ink: Color = Palette.ink
    var inner: Color = Palette.card
    var body: some View {
        Canvas { ctx, size in
            let w = min(size.width, size.height * 0.56)
            let r = CGRect(x: (size.width - w) / 2, y: (size.height - w / 0.56) / 2, width: w, height: w / 0.56)
            GlassArt.draw(&ctx, in: r, shape: shape, fill: fill, color: color, sparkling: sparkling, ink: ink, inner: inner)
        }
        .aspectRatio(0.56, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
