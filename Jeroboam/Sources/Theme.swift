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

    /// One accent for every level, so lessons, buttons and progress all match.
    static func level(_ n: Int) -> Color { wine }
}

// MARK: - Type
// One family (SF Pro, like Halo, Ahead and Scout) and one modest scale:
//   screen title 30 bold · section 19 semibold · card title 17 semibold · body 16 · secondary 14 · caption 12.
// Poster type (`display`) is reserved for numbers and short posters and is kept small and bold, not heavy.

enum TypeScale {
    static let title: CGFloat = 30
    static let section: CGFloat = 19
    static let cardTitle: CGFloat = 17
    static let body: CGFloat = 16
    static let secondary: CGFloat = 14
    static let caption: CGFloat = 12
}

extension Font {
    /// Poster/number type: bold SF, scaled down from older call sites so nothing shouts.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let w: Font.Weight = (weight == .black || weight == .heavy) ? .bold : weight
        return .system(size: (size * 0.74).rounded(), weight: w)
    }
    /// Titles.
    static func heading(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    /// Kept for older call sites: a calm semibold sans, slightly smaller than requested.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: (size * 0.9).rounded(), weight: weight == .regular || weight == .light || weight == .medium ? .semibold : .semibold)
    }
    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    static var screenTitle: Font { .system(size: TypeScale.title, weight: .bold) }
    static var sectionTitle: Font { .system(size: TypeScale.section, weight: .semibold) }
    static var cardTitle: Font { .system(size: TypeScale.cardTitle, weight: .semibold) }
}

/// Small uppercase label above titles.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSoft
    init(_ text: String, color: Color = Palette.inkSoft) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}

/// The one title block used at the top of every screen: eyebrow, title, optional subtitle.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(eyebrow, color: Palette.wine)
            Text(title).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let s = subtitle {
                Text(rich(s)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

/// Section heading inside a screen.
struct SectionTitle: View {
    let text: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.sectionTitle).foregroundStyle(Palette.ink)
            Spacer()
            if let d = detail { Text(d).font(.system(size: 13)).foregroundStyle(Palette.inkFaint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Metrics {
    static let margin: CGFloat = 20
    static let gap: CGFloat = 16
    static let radius: CGFloat = 16
}

// MARK: - Buttons

/// Primary action: flat claret capsule with gentle press scale.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.wine
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(enabled ? (color == Palette.wine ? Palette.onWine : Color.white) : Palette.inkFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
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
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

// MARK: - Zoom transitions (cards grow into the screen they open; iOS 18+, plain push before that)

private struct ZoomNamespaceKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }

extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

private struct ZoomSource: ViewModifier {
    let id: String
    @Environment(\.zoomNamespace) private var ns
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let ns {
            content.matchedTransitionSource(id: id, in: ns) { $0.clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)) }
        } else {
            content
        }
    }
}

private struct ZoomDestination: ViewModifier {
    let id: String
    let ns: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            content
        }
    }
}

extension View {
    /// Mark a tappable card as the origin of a zoom transition.
    func zoomSource(_ id: String) -> some View { modifier(ZoomSource(id: id)) }
    /// Open this destination with a zoom from the matching source.
    func zoomDestination(_ id: String, in ns: Namespace.ID) -> some View { modifier(ZoomDestination(id: id, ns: ns)) }
}

enum ZoomID {
    static func grape(_ id: String) -> String { "g:" + id }
    static func region(_ id: String) -> String { "r:" + id }
    static func section(_ s: String) -> String { "s:" + s }
    static func style(_ id: String) -> String { "st:" + id }
}

/// A grouped list card (Settings-like): rows separated by inset hairlines.
struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}

/// A row with a small leading icon tile, title, detail and chevron.
struct IconRow<Icon: View>: View {
    let title: String
    var detail: String? = nil
    var last = false
    @ViewBuilder let icon: Icon
    var body: some View {
        HStack(spacing: 14) {
            icon
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.cardAlt))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                if let detail { Text(detail).font(.system(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 68) } }
        .contentShape(Rectangle())
    }
}


// MARK: - Status bar backdrop (content never shows under the clock)

extension View {
    func statusBarBackdrop() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0)
                .background(Palette.paper.ignoresSafeArea(edges: .top))
        }
    }
}
