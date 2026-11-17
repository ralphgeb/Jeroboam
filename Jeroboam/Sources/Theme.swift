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
    // Surfaces
    static let paper = Color.dynamic("#F7F3EE", "#121011")
    static let card = Color.dynamic("#FFFFFF", "#1C1819")
    static let cardAlt = Color.dynamic("#F1EBE3", "#241F21")
    static let line = Color.dynamic("#E6DED5", "#2F282A")
    // Text
    static let ink = Color.dynamic("#1F1719", "#F2ECE8")
    static let inkSoft = Color.dynamic("#7A6B6E", "#A39598")
    static let inkFaint = Color.dynamic("#B3A6A2", "#6B5F62")
    // Brand
    static let wine = Color.dynamic("#7D1D3F", "#D4738F")
    static let wineSoft = Color.dynamic("#F3E4E7", "#3A2229")
    static let wineDeep = Color(hex: "#4E0F27")
    static let brass = Color.dynamic("#A9824A", "#CFA96E")
    static let sage = Color.dynamic("#7C8C62", "#A3B386")
    static let slate = Color.dynamic("#6F8193", "#93A6B8")
    // Feedback (muted, in the same family)
    static let correct = Color.dynamic("#4F7A4A", "#8DBE86")
    static let correctBG = Color.dynamic("#EEF3EA", "#1C261B")
    static let wrong = Color.dynamic("#A8323A", "#E4838A")
    static let wrongBG = Color.dynamic("#F8ECEB", "#2E1C1E")
    // Game
    static let flame = Color.dynamic("#C8642D", "#E8955C")
    static let gold = brass
    static let goldDeep = brass
    // Maps
    static let sea = Color.dynamic("#E4E9EA", "#161B1E")
    static let land = Color.dynamic("#EFE9E1", "#211C1E")
    static let focusLand = Color.dynamic("#FBF8F4", "#2A2426")
    static let border = Color.dynamic("#D8CEC3", "#3A3235")
    static let river = Color.dynamic("#A9BCC6", "#3E5462")
    static let locked = Color.dynamic("#EAE3DB", "#2A2426")
    static let lockedDeep = Color.dynamic("#D8CEC3", "#3A3235")

    /// Tints of the brand color for map regions (alternating so neighbours differ).
    static func regionFill(_ index: Int, dark: Bool) -> Color {
        let steps: [Double] = [0.34, 0.62, 0.20, 0.50, 0.76, 0.28, 0.44]
        let t = steps[index % steps.count]
        return dark ? Color(hex: "#D4738F").opacity(0.18 + t * 0.6)
                    : Color(hex: "#7D1D3F").mix(with: Color(hex: "#FBF8F4"), 1 - t)
    }

    static func berry(_ b: BerryColor) -> Color {
        switch b {
        case .black: return Color(hex: "#3E2140")
        case .white: return Color(hex: "#C9C47C")
        case .pink: return Color(hex: "#B9787F")
        }
    }

    static func level(_ n: Int) -> Color {
        switch n {
        case 1: return sage
        case 2: return wine
        default: return Color.dynamic("#3E2140", "#B79AC0")
        }
    }
}

// MARK: - Type

extension Font {
    /// Display serif (New York).
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Numbers in game UI.
    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Small uppercase label above titles.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSoft
    init(_ text: String, color: Color = Palette.inkSoft) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.4)
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
            .foregroundStyle(enabled ? Color.white : Palette.inkFaint)
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
