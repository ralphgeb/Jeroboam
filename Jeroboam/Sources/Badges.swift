import SwiftUI

/// Collectible medals for achievements: each one has its own shape and metal, with ribbons, a dotted rim and an embossed icon.
struct AchievementBadge: View {
    enum Form { case seal, shield, hexagon, rosette, laurel }
    enum Metal {
        case bronze, silver, gold, bordeaux
        var colors: [Color] {
            switch self {
            case .bronze: return [Color(hex: "#E8A774"), Color(hex: "#B06A3B"), Color(hex: "#7A4422")]
            case .silver: return [Color(hex: "#F4F6F8"), Color(hex: "#B9C0C9"), Color(hex: "#7D8590")]
            case .gold: return [Color(hex: "#FBE7A1"), Color(hex: "#E0B04A"), Color(hex: "#9C6E1B")]
            case .bordeaux: return [Color(hex: "#E8708A"), Color(hex: "#9E1B3A"), Color(hex: "#5B2049")]
            }
        }
    }
    let achievement: Achievement
    var unlocked: Bool
    var size: CGFloat = 72

    static let style: [String: (Form, Metal)] = [
        "first-sip": (.seal, .bronze), "streak-3": (.rosette, .bronze), "streak-7": (.rosette, .silver), "streak-30": (.rosette, .gold),
        "perfect": (.hexagon, .silver), "perfect-10": (.hexagon, .gold), "xp-500": (.shield, .silver), "xp-2000": (.shield, .gold),
        "level-1": (.laurel, .bronze), "level-2": (.laurel, .silver), "level-3": (.laurel, .gold),
        "ampelographer": (.seal, .bordeaux), "globetrotter": (.hexagon, .bordeaux), "practice-10": (.shield, .bronze), "answers-500": (.seal, .gold),
        // the later achievements had no style and all came out silver: each gets its own form and metal (first steps bronze,
        // middle silver, big ones gold, exploring and journal ones Bordeaux)
        "level-4": (.laurel, .gold), "level-5": (.laurel, .bordeaux),
        "streak-14": (.rosette, .silver), "streak-100": (.rosette, .bordeaux), "xp-5000": (.shield, .bordeaux),
        "perfect-25": (.hexagon, .bordeaux), "answers-2000": (.seal, .bordeaux), "practice-50": (.shield, .gold),
        "grapes-50": (.seal, .gold), "regions-60": (.hexagon, .gold),
        "first-scan": (.seal, .bronze), "cellar-10": (.shield, .silver), "cellar-50": (.shield, .gold),
        "first-tasting": (.rosette, .bronze), "blind-first": (.hexagon, .bronze), "blind-80": (.hexagon, .gold), "blind-10": (.rosette, .gold),
        "countries-3": (.laurel, .bronze), "countries-10": (.laurel, .bordeaux),
        "tried-grapes-5": (.seal, .bronze), "tried-grapes-15": (.seal, .silver), "tried-grapes-30": (.seal, .gold),
        "bordeaux-five": (.rosette, .bordeaux), "tried-places-10": (.hexagon, .silver), "tried-countries-8": (.laurel, .silver),
        "classics-5": (.shield, .bronze), "classics-20": (.shield, .bordeaux),
    ]

    var body: some View {
        let (form, metal) = Self.style[achievement.id] ?? (.seal, .silver)
        let c = metal.colors
        ZStack {
            Canvas { ctx, sz in
                let s = min(sz.width, sz.height)
                let cx = sz.width / 2, cy = s * 0.44
                // ribbons
                if form != .shield && form != .hexagon {
                    for side in [-1.0, 1.0] {
                        var r = Path()
                        let x0 = cx + CGFloat(side) * s * 0.06
                        r.move(to: CGPoint(x: x0, y: cy + s * 0.2))
                        r.addLine(to: CGPoint(x: x0 + CGFloat(side) * s * 0.2, y: cy + s * 0.2))
                        r.addLine(to: CGPoint(x: x0 + CGFloat(side) * s * 0.26, y: s * 0.98))
                        r.addLine(to: CGPoint(x: x0 + CGFloat(side) * s * 0.15, y: s * 0.9))
                        r.addLine(to: CGPoint(x: x0 + CGFloat(side) * s * 0.06, y: s * 0.98))
                        r.closeSubpath()
                        ctx.fill(r, with: .color(side < 0 ? Palette.bordeaux : Palette.pink))
                    }
                }
                // laurel leaves
                if form == .laurel {
                    for side in [-1.0, 1.0] {
                        for k in 0..<7 {
                            let a = Double.pi * (0.62 + 0.11 * Double(k))
                            let rr = s * 0.4
                            let px = cx + CGFloat(side) * CGFloat(-cos(a)) * rr, py = cy + CGFloat(sin(a)) * rr * 0.98 - s * 0.02
                            var leaf = Path(ellipseIn: CGRect(x: -s * 0.035, y: -s * 0.075, width: s * 0.07, height: s * 0.15))
                            leaf = leaf.applying(CGAffineTransform(rotationAngle: CGFloat(side) * CGFloat(a - .pi / 2) * 0.9 + CGFloat(side) * 0.5))
                                .applying(CGAffineTransform(translationX: px, y: py))
                            ctx.fill(leaf, with: .color(Color(hex: "#6E8B47")))
                        }
                    }
                }
                // body
                let R = s * (form == .laurel ? 0.3 : 0.38)
                let body = Self.path(form, center: CGPoint(x: cx, y: cy), r: R)
                ctx.drawLayer { l in
                    l.addFilter(.shadow(color: .black.opacity(0.22), radius: s * 0.03, x: 0, y: s * 0.02))
                    l.fill(body, with: .linearGradient(Gradient(colors: c), startPoint: CGPoint(x: cx - R, y: cy - R), endPoint: CGPoint(x: cx + R, y: cy + R)))
                }
                ctx.stroke(body, with: .color(c[2].opacity(0.8)), lineWidth: s * 0.015)
                // dotted rim
                let rim = R * 0.78
                for k in 0..<24 {
                    let a = Double(k) / 24 * 2 * .pi
                    let p = CGPoint(x: cx + CGFloat(cos(a)) * rim, y: cy + CGFloat(sin(a)) * rim)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - s * 0.008, y: p.y - s * 0.008, width: s * 0.016, height: s * 0.016)), with: .color(c[0].opacity(0.9)))
                }
                // inner disc
                let inner = R * 0.64
                ctx.fill(Path(ellipseIn: CGRect(x: cx - inner, y: cy - inner, width: inner * 2, height: inner * 2)),
                         with: .radialGradient(Gradient(colors: [c[0], c[1]]), center: CGPoint(x: cx - inner * 0.3, y: cy - inner * 0.3), startRadius: 0, endRadius: inner * 1.4))
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - inner, y: cy - inner, width: inner * 2, height: inner * 2)), with: .color(c[2].opacity(0.5)), lineWidth: s * 0.01)
                // shine
                var shine = Path()
                shine.addArc(center: CGPoint(x: cx, y: cy), radius: R * 0.9, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
                ctx.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round))
            }
            Image(systemName: achievement.icon)
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundStyle((Self.style[achievement.id]?.1 ?? .silver).colors[2])
                .shadow(color: .white.opacity(0.7), radius: 0, x: 0, y: 1)
                .offset(y: -size * 0.06)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        // Locked: a faint flat silhouette of the medal; it shows in full once earned.
        .modifier(SilhouetteIf(on: !unlocked))
        .accessibilityLabel(achievement.title + (unlocked ? ", unlocked" : ", locked"))
    }

    static func path(_ f: Form, center c: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        switch f {
        case .seal, .laurel:
            let n = f == .seal ? 16 : 0
            if n == 0 { return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
            for k in 0..<(n * 2) {
                let a = Double(k) / Double(n * 2) * 2 * .pi
                let rr = k % 2 == 0 ? r : r * 0.9
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        case .rosette:
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                p.addEllipse(in: CGRect(x: c.x + CGFloat(cos(a)) * r * 0.72 - r * 0.3, y: c.y + CGFloat(sin(a)) * r * 0.72 - r * 0.3, width: r * 0.6, height: r * 0.6))
            }
            p.addEllipse(in: CGRect(x: c.x - r * 0.8, y: c.y - r * 0.8, width: r * 1.6, height: r * 1.6))
        case .hexagon:
            for k in 0..<6 {
                let a = Double(k) / 6 * 2 * .pi - .pi / 2
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        case .shield:
            p.move(to: CGPoint(x: c.x - r * 0.85, y: c.y - r * 0.85))
            p.addQuadCurve(to: CGPoint(x: c.x + r * 0.85, y: c.y - r * 0.85), control: CGPoint(x: c.x, y: c.y - r * 1.15))
            p.addLine(to: CGPoint(x: c.x + r * 0.85, y: c.y + r * 0.1))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r * 1.05), control: CGPoint(x: c.x + r * 0.8, y: c.y + r * 0.75))
            p.addQuadCurve(to: CGPoint(x: c.x - r * 0.85, y: c.y + r * 0.1), control: CGPoint(x: c.x - r * 0.8, y: c.y + r * 0.75))
        }
        p.closeSubpath()
        return p
    }
}

/// Rank emblem: each rank is a bottle size, from a piccolo for a curious sipper to a Nebuchadnezzar for a Master of wine.
struct RankEmblem: View {
    let rankIndex: Int
    var size: CGFloat = 76
    static let bottles = ["Piccolo", "Half bottle", "Bottle", "Magnum", "Jeroboam", "Methuselah", "Balthazar", "Nebuchadnezzar"]
    var body: some View {
        let t = CGFloat(min(7, max(0, rankIndex))) / 7
        ZStack {
            Circle().fill(LinearGradient(colors: [Palette.bordeaux, Palette.bordeaux.mix(with: .black, 0.3)], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Color(hex: "#E0B04A"), lineWidth: size * 0.04)
            Circle().strokeBorder(Color(hex: "#E0B04A").opacity(0.5), style: StrokeStyle(lineWidth: size * 0.015, dash: [2, 3])).padding(size * 0.08)
            BottleShape().fill(Color(hex: "#F0D9C4"))
                .frame(width: size * (0.12 + 0.12 * t), height: size * (0.34 + 0.3 * t))
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

private struct SilhouetteIf: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on {
            Palette.ink.opacity(0.09).mask(content)
        } else {
            content
        }
    }
}
