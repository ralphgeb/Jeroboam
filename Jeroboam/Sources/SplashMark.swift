import SwiftUI

/// The brand mark (owner's Illustrator splash, see BrandShapes.swift): a Bordeaux splash on white or paper.
struct SplashMark: View {
    var color: Color = Palette.bordeaux
    var surface: Color? = nil      // droplet color; defaults to the body color
    var body: some View {
        ZStack {
            SplashBodyShape().fill(color)
            SplashDropShape().fill(surface ?? color)
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
                SplashBodyShape().fill(.white.opacity(0.08))
                    .frame(width: geo.size.height * 1.8, height: geo.size.height * 1.8)
                    .offset(x: geo.size.width - geo.size.height * 1.15, y: -geo.size.height * 0.3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius + 2, style: .continuous))
    }
}
