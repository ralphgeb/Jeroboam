import SwiftUI

/// The Jero splash: wine in a round bowl rising into a wave (owner's reference). Same curves as tools/render_splash_icon.py.
struct SplashShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2, oy = rect.midY - s / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.move(to: P(0.07, 0.56))
        p.addCurve(to: P(0.47, 0.95), control1: P(0.07, 0.79), control2: P(0.25, 0.95))
        p.addCurve(to: P(0.88, 0.55), control1: P(0.7, 0.95), control2: P(0.88, 0.78))
        p.addCurve(to: P(0.67, 0.12), control1: P(0.88, 0.36), control2: P(0.8, 0.2))
        p.addCurve(to: P(0.5, 0.15), control1: P(0.6, 0.075), control2: P(0.5, 0.085))
        p.addCurve(to: P(0.635, 0.245), control1: P(0.5, 0.215), control2: P(0.585, 0.225))
        p.addCurve(to: P(0.66, 0.44), control1: P(0.7, 0.29), control2: P(0.7, 0.38))
        p.addCurve(to: P(0.6, 0.54), control1: P(0.63, 0.49), control2: P(0.61, 0.52))
        p.addCurve(to: P(0.07, 0.56), control1: P(0.45, 0.5), control2: P(0.2, 0.5))
        p.closeSubpath()
        for (x, y, r) in [(0.585, 0.305, 0.03), (0.605, 0.415, 0.036)] as [(CGFloat, CGFloat, CGFloat)] {
            p.addEllipse(in: CGRect(x: ox + (x - r) * s, y: oy + (y - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        return p
    }
}

struct SplashSurface: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2, oy = rect.midY - s / 2
        return Path(ellipseIn: CGRect(x: ox + (0.335 - 0.27) * s, y: oy + (0.535 - 0.045) * s, width: 2 * 0.27 * s, height: 2 * 0.045 * s))
    }
}

/// The brand mark: a Bordeaux splash with a lighter wine surface (on white or paper).
struct SplashMark: View {
    var color: Color = Palette.bordeaux
    var surface: Color = Palette.pink
    var body: some View {
        ZStack {
            SplashShape().fill(color)
            SplashSurface().fill(surface)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Hero card ground: Bordeaux gradient with a large, faint splash watermark bleeding off the right edge.
struct HeroCardBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Palette.bordeaux, Palette.bordeaux.mix(with: .black, 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                SplashShape().fill(.white.opacity(0.09))
                    .frame(width: geo.size.height * 1.9, height: geo.size.height * 1.9)
                    .offset(x: geo.size.width - geo.size.height * 1.05, y: -geo.size.height * 0.35)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius + 2, style: .continuous))
    }
}
