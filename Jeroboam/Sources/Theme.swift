import SwiftUI
import UIKit

// Design system: editorial and minimal. One main color (claret) with a few muted
// complements (brass, sage, slate) on warm ivory. Serif display type (New York),
// SF for text, generous 24pt margins, hairline separators, no heavy shadows.

// MARK: - Colors

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                      blue: Double(v & 0xFF) / 255, opacity: 1)
        } else {
            self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
        }
    }

    /// A color that switches between a light and a dark value.
    static func dynamic(_ light: String, _ dark: String) -> Color {
        Color(UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    func mix(with other: Color, _ t: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(t)
        return Color(.sRGB, red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t), opacity: 1)
    }
}

enum Palette {
    // Light: clean porcelain + Bordeaux. Dark: deep Bordeaux + beige.
    static let paper = Color.dynamic("#F5F4F2", "#1A0910")
    static let card = Color.dynamic("#FFFFFF", "#28101A")
    static let cardAlt = Color.dynamic("#EEECE9", "#341620")
    static let line = Color.dynamic("#E4E0DD", "#43202C")
    // Text
    static let ink = Color.dynamic("#140A0E", "#F4EADF")
    static let inkSoft = Color.dynamic("#655B5F", "#C9B5B0")
    static let inkFaint = Color.dynamic("#A39A9C", "#86656C")
    // Brand
    static let wine = Color.dynamic("#8B1538", "#F0D9C4")          // primary action
    static let onWine = Color.dynamic("#FFFFFF", "#3A0E1D")
    static let wineSoft = Color.dynamic("#F6E3E8", "#3E1724")
    static let wineDeep = Color(hex: "#4C0B22")
    static let bordeaux = Color(hex: "#8B1538")
    static let grape = Color.dynamic("#4A1D3F", "#E6B8C8")
    static let pink = Color(hex: "#D8285A")
    static let beige = Color(hex: "#F0E2D2")
    static let brass = Color.dynamic("#B07A2A", "#E3B567")
    static let sage = Color.dynamic("#5E8A4E", "#9CC48A")
    static let slate = Color.dynamic("#3F6E8C", "#8EB8D4")
    // Feedback
    static let correct = Color.dynamic("#2F8A4E", "#7FD39A")
    static let correctBG = Color.dynamic("#E7F5EC", "#173022")
    static let wrong = Color.dynamic("#C81E3F", "#FF8DA1")
    static let wrongBG = Color.dynamic("#FCE8EC", "#3D1522")
    // Game
    static let flame = Color.dynamic("#E8571F", "#FF9A5C")
    static let gold = brass
    static let goldDeep = brass
    // Maps (Wine Folly-style: white land, blue sea, grey neighbours)
    static let sea = Color.dynamic("#A9D2EA", "#122633")
    static let land = Color.dynamic("#E6E3E0", "#24111A")
    static let focusLand = Color.dynamic("#FFFFFF", "#3A1925")
    static let border = Color.dynamic("#C9C2BD", "#5A3341")
    static let adminLine = Color.dynamic("#E2DCD8", "#4A2734")
    static let river = Color.dynamic("#6FAED6", "#3F7598")
    static let locked = Color.dynamic("#E6E3E0", "#341620")
    static let lockedDeep = Color.dynamic("#D2CDC9", "#4A2230")

    /// Bold, wine-led map palette (indices are stored in the map files).
    static let mapColors: [Color] = ["#9E1B3A", "#C2185B", "#E8708A", "#EE7B5A", "#F29A3D", "#D9A23B", "#E8C547", "#9AA549",
                                     "#5FA35A", "#2E9C97", "#3A7BC8", "#7B4BA8", "#5B2049"].map { Color(hex: $0) }

    static func mapColor(_ i: Int) -> Color { mapColors[((i % mapColors.count) + mapColors.count) % mapColors.count] }

    static func regionFill(_ index: Int, dark: Bool) -> Color { mapColor(index) }

    static func berry(_ b: BerryColor) -> Color {
        switch b {
        case .black: return Color(hex: "#4A1D3F")
        case .white: return Color(hex: "#C7C25A")
        case .pink: return Color(hex: "#C46A82")
        }
    }

    static func level(_ n: Int) -> Color {
        switch n {
        case 1: return Color.dynamic("#C2185B", "#FF8DB3")
        case 2: return Color.dynamic("#8B1538", "#F0D9C4")
        default: return Color.dynamic("#4A1D3F", "#D7A7E0")
        }
    }
}

// MARK: - Type (SF Pro: bold, condensed display; same system family as Halo, Ahead and Scout)

extension Font {
    /// Poster headline: heavy, condensed. Use with uppercase text.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
    /// Titles: SF Pro bold.
    static func heading(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
    /// Kept for older call sites: maps to the bold sans heading.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight == .regular || weight == .light ? .bold : weight)
    }
    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Small uppercase label above titles.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSoft
    init(_ text: String, color: Color = Palette.inkSoft) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.3)
            .foregroundStyle(color)
    }
}

enum Metrics {
    static let margin: CGFloat = 24
    static let gap: CGFloat = 16
    static let radius: CGFloat = 18
}

// MARK: - Buttons

/// Primary action: flat claret capsule with gentle press scale.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.wine
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(enabled ? (color == Palette.wine ? Palette.onWine : Color.white) : Palette.inkFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? color : Palette.locked)
            )
            .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1)
            .opacity(configuration.isPressed && enabled ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary action: hairline outline.
struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = Palette.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Answer option tile.
struct TileStyle: ButtonStyle {
    var state: TileState = .idle

    enum TileState { case idle, selected, correct, wrong, disabled }

    func makeBody(configuration: Configuration) -> some View {
        let (fill, stroke, text, width) = colors
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(stroke, lineWidth: width))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var colors: (Color, Color, Color, CGFloat) {
        switch state {
        case .idle: return (Palette.card, Palette.line, Palette.ink, 1)
        case .selected: return (Palette.wineSoft, Palette.wine, Palette.wine, 1.5)
        case .correct: return (Palette.correctBG, Palette.correct, Palette.correct, 1.5)
        case .wrong: return (Palette.wrongBG, Palette.wrong, Palette.wrong, 1.5)
        case .disabled: return (Palette.card, Palette.line, Palette.inkFaint, 1)
        }
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                    .strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20) -> some View { modifier(CardBackground(padding: padding)) }
}

/// Thin hairline divider.
struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.line).frame(height: 0.5) }
}

// MARK: - Haptics

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

// MARK: - Rich text

/// Inline markdown (**bold**, *italic*) with graceful fallback.
func rich(_ s: String) -> AttributedString {
    (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += lineH + lineSpacing; lineH = 0 }
            x += s.width + spacing
            lineH = max(lineH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += lineH + lineSpacing; lineH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}
