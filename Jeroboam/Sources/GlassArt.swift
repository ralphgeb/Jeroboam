import SwiftUI

/// Shared illustrated-glass renderer: translucent bowl, wine with depth and a lit surface,
/// highlights, tapered stem, perspective foot and a soft shadow.
enum GlassArt {
    static func draw(_ ctx: inout GraphicsContext, bowl: Path, top: CGFloat, bottom: CGFloat, stemX: CGFloat,
                     footY: CGFloat, footHalf: CGFloat, fill: CGFloat, color: Color, rim: Color?, sparkling: Bool,
                     ink: Color, scale: CGFloat) {
        let bb = bowl.boundingRect
        let lw = max(0.9, scale * 0.028)
        // shadow under the foot
        let sh = CGRect(x: stemX - footHalf * 1.15, y: footY - footHalf * 0.12, width: footHalf * 2.3, height: footHalf * 0.36)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(1, footHalf * 0.12)))
            l.fill(Path(ellipseIn: sh), with: .color(.black.opacity(0.16)))
        }
        // foot (ellipse) and tapered stem
        let footRect = CGRect(x: stemX - footHalf, y: footY - footHalf * 0.2, width: footHalf * 2, height: footHalf * 0.4)
        ctx.fill(Path(ellipseIn: footRect), with: .linearGradient(Gradient(colors: [.white.opacity(0.85), Color(white: 0.86).opacity(0.7)]),
                                                                   startPoint: CGPoint(x: footRect.minX, y: footRect.minY), endPoint: CGPoint(x: footRect.maxX, y: footRect.maxY)))
        ctx.stroke(Path(ellipseIn: footRect), with: .color(ink.opacity(0.45)), lineWidth: lw * 0.8)
        let sw0 = max(1.2, scale * 0.022), sw1 = max(2, scale * 0.05)
        var stem = Path()
        stem.move(to: CGPoint(x: stemX - sw0, y: bottom - lw))
        stem.addLine(to: CGPoint(x: stemX + sw0, y: bottom - lw))
        stem.addQuadCurve(to: CGPoint(x: stemX + sw1, y: footY), control: CGPoint(x: stemX + sw0 * 0.8, y: footY - (footY - bottom) * 0.15))
        stem.addLine(to: CGPoint(x: stemX - sw1, y: footY))
        stem.addQuadCurve(to: CGPoint(x: stemX - sw0, y: bottom - lw), control: CGPoint(x: stemX - sw0 * 0.8, y: footY - (footY - bottom) * 0.15))
        stem.closeSubpath()
        ctx.fill(stem, with: .linearGradient(Gradient(colors: [Color(white: 0.8).opacity(0.8), .white.opacity(0.95), Color(white: 0.78).opacity(0.8)]),
                                              startPoint: CGPoint(x: stemX - sw1, y: 0), endPoint: CGPoint(x: stemX + sw1, y: 0)))
        ctx.stroke(stem, with: .color(ink.opacity(0.4)), lineWidth: lw * 0.7)

        // the empty glass: a faint cool tint
        ctx.fill(bowl, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.55), Color(red: 0.9, green: 0.93, blue: 0.96).opacity(0.35)]),
                                              startPoint: CGPoint(x: bb.minX, y: bb.minY), endPoint: CGPoint(x: bb.maxX, y: bb.maxY)))
        // wine
        let level = bottom - (bottom - top) * fill
        var w = ctx
        w.clip(to: bowl)
        let deep = color.mix(with: .black, 0.28)
        w.fill(Path(CGRect(x: bb.minX - 2, y: level, width: bb.width + 4, height: bottom - level + 4)),
               with: .linearGradient(Gradient(stops: [.init(color: rim ?? color.mix(with: .white, 0.18), location: 0),
                                                      .init(color: color, location: 0.35),
                                                      .init(color: deep, location: 1)]),
                                     startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: bottom)))
        // depth: darker core, lighter rim at the sides
        w.fill(Path(CGRect(x: bb.minX - 2, y: level, width: bb.width + 4, height: bottom - level + 4)),
               with: .linearGradient(Gradient(stops: [.init(color: .white.opacity(0.22), location: 0), .init(color: .clear, location: 0.22),
                                                      .init(color: .clear, location: 0.78), .init(color: .white.opacity(0.14), location: 1)]),
                                     startPoint: CGPoint(x: bb.minX, y: 0), endPoint: CGPoint(x: bb.maxX, y: 0)))
        // lit surface (an ellipse across the bowl at the wine level)
        var xs: [CGFloat] = []
        let steps = 60
        for i in 0...steps {
            let x = bb.minX + bb.width * CGFloat(i) / CGFloat(steps)
            if bowl.contains(CGPoint(x: x, y: level + 0.5)) { xs.append(x) }
        }
        if let x0 = xs.first, let x1 = xs.last, x1 - x0 > 2 {
            let sh = max(2, (x1 - x0) * 0.14)
            let surf = CGRect(x: x0, y: level - sh / 2, width: x1 - x0, height: sh)
            w.fill(Path(ellipseIn: surf), with: .linearGradient(Gradient(colors: [color.mix(with: .white, 0.45), color.mix(with: .white, 0.12)]),
                                                                 startPoint: CGPoint(x: surf.minX, y: surf.minY), endPoint: CGPoint(x: surf.maxX, y: surf.maxY)))
            w.stroke(Path(ellipseIn: surf), with: .color(color.mix(with: .black, 0.2).opacity(0.5)), lineWidth: lw * 0.6)
        }
        if sparkling {
            var rng = SeededRandom(seed: 5)
            for _ in 0..<14 {
                let bx = bb.midX + bb.width * 0.32 * CGFloat(rng.next() - 0.5)
                let by = level + CGFloat(rng.next()) * (bottom - level) * 0.92 + 3
                let br = scale * 0.016 * CGFloat(0.5 + rng.next())
                w.stroke(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(.white.opacity(0.85)), lineWidth: max(0.6, br * 0.5))
            }
        }
        // highlights on the glass
        var hl = ctx
        hl.clip(to: bowl)
        var shine = Path()
        shine.move(to: CGPoint(x: bb.minX + bb.width * 0.2, y: bb.minY + bb.height * 0.1))
        shine.addQuadCurve(to: CGPoint(x: bb.minX + bb.width * 0.24, y: bb.minY + bb.height * 0.72),
                           control: CGPoint(x: bb.minX + bb.width * 0.08, y: bb.minY + bb.height * 0.42))
        hl.stroke(shine, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: max(1.2, scale * 0.045), lineCap: .round))
        var shine2 = Path()
        shine2.move(to: CGPoint(x: bb.maxX - bb.width * 0.17, y: bb.minY + bb.height * 0.22))
        shine2.addQuadCurve(to: CGPoint(x: bb.maxX - bb.width * 0.2, y: bb.minY + bb.height * 0.42),
                            control: CGPoint(x: bb.maxX - bb.width * 0.1, y: bb.minY + bb.height * 0.32))
        hl.stroke(shine2, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.8, scale * 0.022), lineCap: .round))
        // outline: fine, slightly darker at the rim
        ctx.stroke(bowl, with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        var rimLine = Path()
        rimLine.move(to: CGPoint(x: bb.minX + 1, y: bb.minY + lw / 2))
        rimLine.addLine(to: CGPoint(x: bb.maxX - 1, y: bb.minY + lw / 2))
        if bowl.contains(CGPoint(x: bb.midX, y: bb.minY + lw * 2)) {
            ctx.stroke(rimLine, with: .color(ink.opacity(0.35)), lineWidth: lw * 0.8)
        }
    }
}
