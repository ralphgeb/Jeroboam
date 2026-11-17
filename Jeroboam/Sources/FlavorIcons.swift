import SwiftUI

// MARK: - Flavor icons
// One line icon per tasting descriptor, drawn on a 24 × 24 grid with round caps and joins:
// simple, single-color strokes in the descriptor's family color (in the spirit of classic wine-poster icons).

struct FlavorIcon: View {
    let aroma: String
    var size: CGFloat = 30
    var color: Color? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let cat = ContentStore.shared.aromaCategory(forItem: aroma)
        let base = Color(hex: cat?.color ?? "#A08890")
        let tint = color ?? (scheme == .dark ? base.mix(with: .white, 0.3) : base.mix(with: .black, 0.18))
        let kind = FlavorGlyph.kind(for: aroma, category: cat?.id)
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 24
            let g = FlavorGlyph.draw(kind)
            let t = CGAffineTransform(translationX: (sz.width - 24 * s) / 2, y: (sz.height - 24 * s) / 2).scaledBy(x: s, y: s)
            ctx.stroke(g.stroke.applying(t), with: .color(tint),
                       style: StrokeStyle(lineWidth: max(1.1, 1.45 * s), lineCap: .round, lineJoin: .round))
            ctx.stroke(g.thin.applying(t), with: .color(tint.opacity(0.85)),
                       style: StrokeStyle(lineWidth: max(0.7, 0.9 * s), lineCap: .round, lineJoin: .round))
            ctx.fill(g.fill.applying(t), with: .color(tint))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct GlyphPaths {
    var stroke = Path()
    var thin = Path()
    var fill = Path()
}

private extension Path {
    mutating func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    mutating func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ deg: CGFloat = 0) {
        let e = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry))
        addPath(e.applying(CGAffineTransform(rotationAngle: deg * .pi / 180).concatenating(CGAffineTransform(translationX: x, y: y))))
    }
    mutating func poly(_ pts: [(CGFloat, CGFloat)], close: Bool = false) {
        guard let f = pts.first else { return }
        move(to: CGPoint(x: f.0, y: f.1))
        for p in pts.dropFirst() { addLine(to: CGPoint(x: p.0, y: p.1)) }
        if close { closeSubpath() }
    }
    mutating func seg(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) {
        move(to: CGPoint(x: x0, y: y0)); addLine(to: CGPoint(x: x1, y: y1))
    }
    mutating func quad(_ x0: CGFloat, _ y0: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ x1: CGFloat, _ y1: CGFloat) {
        move(to: CGPoint(x: x0, y: y0)); addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))
    }
    /// Closed shape from a start point and cubic segments (c1, c2, end).
    mutating func shape(_ x: CGFloat, _ y: CGFloat, _ segs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)], close: Bool = true) {
        move(to: CGPoint(x: x, y: y))
        for s in segs {
            addCurve(to: CGPoint(x: s.4, y: s.5), control1: CGPoint(x: s.0, y: s.1), control2: CGPoint(x: s.2, y: s.3))
        }
        if close { closeSubpath() }
    }
    /// Pointed leaf from a to b with the given half-width.
    mutating func leaf(_ ax: CGFloat, _ ay: CGFloat, _ bx: CGFloat, _ by: CGFloat, _ w: CGFloat) {
        let dx = bx - ax, dy = by - ay
        let len = max(0.01, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * w, ny = dx / len * w
        let m1 = CGPoint(x: ax + dx * 0.45 + nx * 1.3, y: ay + dy * 0.45 + ny * 1.3)
        let m2 = CGPoint(x: ax + dx * 0.45 - nx * 1.3, y: ay + dy * 0.45 - ny * 1.3)
        move(to: CGPoint(x: ax, y: ay))
        addQuadCurve(to: CGPoint(x: bx, y: by), control: m1)
        addQuadCurve(to: CGPoint(x: ax, y: ay), control: m2)
        closeSubpath()
    }
    mutating func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 0.75) { circle(x, y, r) }
}

enum FlavorGlyph {
    enum Kind {
        case cherry, raspberry, currants, blueberry, strawberry, plum, pomegranate
        case apple, pear, quince, grape, appleRing
        case lemon, lime, grapefruit, peel, yuzu, jar
        case peach, apricot, driedApricot
        case banana, lychee, mango, melon, passionFruit, pineapple
        case fig, prune, raisin, fruitCake
        case flower, elderflower, honeysuckle, acacia, rose, violet, lavender, orangeBlossom
        case leaf, grass, tomatoLeaf, lobedLeaf, nettle, tobacco, fallenLeaves
        case thyme, mint, eucalyptus, dill, fennel, herbBundle
        case bellPepper, asparagus, peppercorns, whitePepper, liquorice
        case flint, pebbles, chalk, saline, wool
        case bread, brioche, biscuit, croissant, dough, cheese
        case butter, jug, tub
        case vanilla, clove, nutmeg, coconut, candy, caramel, toast, log, charred, smoke, chocolate, coffeeCup, coffeeBean, cinnamon
        case leather, earth, mushroom, feather, steak, truffle
        case honeycomb, petrol, hay
        case almond, hazelnut, walnut
        case generic
    }

    static func kind(for aroma: String, category: String?) -> Kind {
        switch aroma.lowercased() {
        case "red cherry", "black cherry", "kirsch", "cherry", "sour cherry": return .cherry
        case "raspberry", "blackberry", "mulberry", "boysenberry": return .raspberry
        case "redcurrant", "blackcurrant", "cranberry", "cassis": return .currants
        case "blueberry": return .blueberry
        case "strawberry": return .strawberry
        case "red plum", "black plum", "plum", "damson": return .plum
        case "pomegranate": return .pomegranate
        case "green apple", "red apple", "apple": return .apple
        case "pear": return .pear
        case "quince": return .quince
        case "green grape", "grape": return .grape
        case "dried apple": return .appleRing
        case "lemon", "meyer lemon": return .lemon
        case "lime": return .lime
        case "grapefruit": return .grapefruit
        case "orange peel", "lemon zest", "citrus peel": return .peel
        case "yuzu", "orange": return .yuzu
        case "marmalade", "jammy fruit", "jam": return .jar
        case "peach", "white peach", "nectarine": return .peach
        case "apricot": return .apricot
        case "dried apricot": return .driedApricot
        case "banana": return .banana
        case "lychee": return .lychee
        case "mango": return .mango
        case "melon", "honeydew melon": return .melon
        case "passion fruit": return .passionFruit
        case "pineapple": return .pineapple
        case "fig", "dried fig": return .fig
        case "prune": return .prune
        case "raisin", "sultana": return .raisin
        case "fruit cake": return .fruitCake
        case "blossom": return .flower
        case "orange blossom": return .orangeBlossom
        case "elderflower": return .elderflower
        case "honeysuckle": return .honeysuckle
        case "acacia": return .acacia
        case "rose": return .rose
        case "violet": return .violet
        case "lavender": return .lavender
        case "grass", "hay grass": return .grass
        case "tomato leaf": return .tomatoLeaf
        case "blackcurrant leaf": return .lobedLeaf
        case "nettle": return .nettle
        case "tobacco": return .tobacco
        case "wet leaves", "forest floor": return .fallenLeaves
        case "thyme", "dried herbs": return .thyme
        case "mint": return .mint
        case "eucalyptus": return .eucalyptus
        case "dill": return .dill
        case "fennel", "anise": return .fennel
        case "garrigue": return .herbBundle
        case "green bell pepper": return .bellPepper
        case "asparagus": return .asparagus
        case "black pepper": return .peppercorns
        case "white pepper": return .whitePepper
        case "liquorice": return .liquorice
        case "flint", "gunflint": return .flint
        case "wet stones": return .pebbles
        case "chalk": return .chalk
        case "saline": return .saline
        case "wet wool": return .wool
        case "bread": return .bread
        case "brioche": return .brioche
        case "biscuit": return .biscuit
        case "pastry": return .croissant
        case "bread dough": return .dough
        case "cheese rind": return .cheese
        case "butter": return .butter
        case "cream": return .jug
        case "sour cream", "mushroom cream": return aroma.lowercased() == "mushroom cream" ? .mushroom : .tub
        case "vanilla": return .vanilla
        case "cloves": return .clove
        case "nutmeg": return .nutmeg
        case "coconut": return .coconut
        case "butterscotch", "toffee": return .candy
        case "caramel": return .caramel
        case "toast": return .toast
        case "cedar": return .log
        case "charred wood": return .charred
        case "smoke": return .smoke
        case "chocolate": return .chocolate
        case "coffee": return .coffeeCup
        case "coffee bean": return .coffeeBean
        case "sweet spice", "baking spice", "cinnamon": return .cinnamon
        case "leather": return .leather
        case "earth": return .earth
        case "mushroom", "truffle": return aroma.lowercased() == "truffle" ? .truffle : .mushroom
        case "game": return .feather
        case "meaty": return .steak
        case "honey": return .honeycomb
        case "petrol": return .petrol
        case "hay": return .hay
        case "almond", "marzipan": return .almond
        case "hazelnut": return .hazelnut
        case "walnut": return .walnut
        default:
            switch category ?? "" {
            case "red-fruit": return .cherry
            case "black-fruit": return .raspberry
            case "citrus": return .lime
            case "green-fruit": return .apple
            case "stone-fruit": return .peach
            case "tropical": return .mango
            case "dried-fruit": return .raisin
            case "floral": return .flower
            case "herbaceous": return .leaf
            case "herbal": return .thyme
            case "spice": return .peppercorns
            case "mineral": return .pebbles
            case "yeast": return .bread
            case "malolactic": return .butter
            case "oak": return .log
            case "red-ageing": return .earth
            case "white-ageing": return .honeycomb
            case "oxidative": return .almond
            default: return .generic
            }
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    static func draw(_ k: Kind) -> GlyphPaths {
        var g = GlyphPaths()
        switch k {
        // ---------------------------------------------------------------- red & black fruit
        case .cherry:
            g.stroke.circle(7.5, 16.5, 4.3)
            g.stroke.circle(16.5, 15.5, 4.3)
            g.stroke.quad(7.5, 12.2, 9, 6, 14, 3.5)
            g.stroke.quad(16.5, 11.2, 16, 6.5, 14, 3.5)
            g.stroke.leaf(14, 3.5, 20.5, 4.5, 1.6)
            g.thin.quad(5.5, 15, 5.8, 13.6, 7, 13.2)
        case .raspberry:
            for (x, y) in [(9.0, 9.5), (12.0, 9.0), (15.0, 9.5), (7.6, 12.8), (10.5, 12.6), (13.5, 12.6), (16.4, 12.8),
                           (9.0, 16.0), (12.0, 16.2), (15.0, 16.0), (10.5, 19.3), (13.5, 19.3)] {
                g.stroke.circle(x, y, 1.75)
            }
            g.stroke.poly([(7.5, 6.5), (9.5, 5.2), (10.5, 6.6), (12, 5), (13.5, 6.6), (14.5, 5.2), (16.5, 6.5)])
            g.stroke.seg(12, 5, 12, 2.2)
        case .currants:
            g.stroke.quad(3, 4, 11, 4.5, 20.5, 8)
            for (x, y, sx, sy) in [(6.5, 10.5, 6, 4.3), (11.5, 12.5, 11, 4.6), (16.5, 14, 16, 6.5), (9, 17.5, 8.6, 13.5), (14, 19.5, 13.5, 15.5)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                g.stroke.circle(x, y, 2.6)
                g.thin.seg(sx, sy, x, y - 2.6)
            }
        case .blueberry:
            g.stroke.circle(9, 14.5, 5.5)
            g.stroke.circle(17, 9.5, 4.2)
            g.thin.poly([(7.6, 12.2), (9, 13.2), (10.4, 12.2)])
            g.thin.seg(9, 13.2, 9, 11.4)
            g.thin.poly([(16, 7.8), (17, 8.6), (18, 7.8)])
            g.thin.seg(17, 8.6, 17, 7.2)
        case .strawberry:
            g.stroke.shape(12, 22, [(7, 19, 3.5, 12, 6, 8.5), (8, 6.5, 10, 7.5, 12, 7.5), (14, 7.5, 16, 6.5, 18, 8.5), (20.5, 12, 17, 19, 12, 22)])
            g.stroke.poly([(7, 7.5), (9.5, 4.5), (10.5, 7), (12, 3.5), (13.5, 7), (14.5, 4.5), (17, 7.5)])
            for (x, y) in [(9.5, 11), (14.5, 11), (12, 13.5), (9, 15.5), (15, 15.5), (12, 18)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.65) }
        case .plum:
            g.stroke.oval(12, 14, 7.2, 8)
            g.thin.quad(12, 6.5, 8.5, 13, 11, 21.5)
            g.stroke.seg(12, 6, 12.8, 2.5)
            g.stroke.leaf(12.8, 3.5, 18.5, 2.5, 1.3)
        case .pomegranate:
            g.stroke.circle(12, 14.5, 7.5)
            g.stroke.poly([(9.3, 7.6), (9.2, 4.2), (10.8, 5.6), (12, 3.5), (13.2, 5.6), (14.8, 4.2), (14.7, 7.6)])
            g.thin.quad(8, 12, 9, 10.2, 11, 9.6)
        // ---------------------------------------------------------------- orchard fruit
        case .apple:
            g.stroke.shape(12, 8, [(9, 5.5, 4.5, 7.5, 4.5, 13), (4.5, 19, 8.5, 22.5, 12, 21), (15.5, 22.5, 19.5, 19, 19.5, 13), (19.5, 7.5, 15, 5.5, 12, 8)])
            g.stroke.quad(12, 8, 11.8, 5.5, 12.8, 3)
            g.stroke.leaf(13, 5.5, 18.5, 3.5, 1.3)
        case .pear:
            g.stroke.shape(12, 5, [(10, 5, 9.5, 8.5, 8.5, 11), (7.3, 13.6, 5.3, 15, 5.5, 18), (5.8, 21, 8.5, 22, 12, 22),
                                   (15.5, 22, 18.2, 21, 18.5, 18), (18.7, 15, 16.7, 13.6, 15.5, 11), (14.5, 8.5, 14, 5, 12, 5)])
            g.stroke.quad(12, 5, 12.2, 3.5, 13.5, 2)
        case .quince:
            g.stroke.shape(12, 6, [(8, 5.5, 5, 9, 5, 13.5), (5, 19, 8, 22, 12, 22), (16, 22, 19, 19, 19, 13.5), (19, 9, 16, 5.5, 12, 6)])
            g.thin.quad(9, 7.5, 10.5, 9, 12, 8)
            g.stroke.leaf(12, 6, 6.5, 2.5, 1.3)
        case .grape:
            for (x, y) in [(8.5, 9.5), (15.5, 9.5), (12, 14), (8.5, 18.5), (15.5, 18.5)] as [(CGFloat, CGFloat)] { g.stroke.circle(x, y, 3.3) }
            g.stroke.quad(12, 6.2, 12, 4, 14, 2.5)
        case .appleRing:
            g.stroke.circle(12, 12, 8.5)
            g.stroke.circle(12, 12, 2.6)
            g.thin.circle(12, 12, 6.2)
            for (x, y) in [(12, 7.5), (16.5, 12), (12, 16.5), (7.5, 12)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.6) }
        // ---------------------------------------------------------------- citrus
        case .lemon:
            g.stroke.shape(3.5, 12, [(5, 7.5, 8, 5.5, 12, 5.5), (16, 5.5, 19, 7.5, 20.5, 12), (19, 16.5, 16, 18.5, 12, 18.5), (8, 18.5, 5, 16.5, 3.5, 12)])
            g.stroke.seg(3.5, 12, 2, 12)
            g.stroke.seg(20.5, 12, 22, 12)
            g.thin.quad(7, 9.5, 8.5, 8.2, 10.5, 8)
        case .lime, .grapefruit:
            g.stroke.circle(12, 12, 9)
            g.thin.circle(12, 12, 7)
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                g.thin.seg(12 + cos(a) * 1.2, 12 + sin(a) * 1.2, 12 + cos(a) * 6.2, 12 + sin(a) * 6.2)
            }
            if k == .grapefruit { g.fill.circle(12, 12, 1.1) }
        case .peel:
            g.stroke.shape(4, 6, [(9, 1.5, 18, 3, 19.5, 8), (20.5, 12, 10, 10.5, 7.5, 14), (5, 17.5, 12, 23, 20, 19)], close: false)
            g.thin.shape(5.8, 7.8, [(10, 4.5, 16.5, 5.5, 17.5, 8.5)], close: false)
            g.thin.shape(9.5, 15.5, [(9, 18.5, 13.5, 20.5, 18.5, 18.5)], close: false)
        case .yuzu:
            g.stroke.circle(12, 13.5, 8)
            g.stroke.leaf(12, 5.5, 18.5, 2.5, 1.5)
            for (x, y) in [(9, 11), (14.5, 10.5), (11.5, 15), (15.5, 16), (8, 16.5)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.55) }
        case .jar:
            g.stroke.shape(6, 9, [(6, 9, 5.5, 9, 5.5, 11), (5.5, 13, 5.5, 18, 5.5, 19.5), (5.5, 21, 6.5, 22, 8, 22), (12, 22, 12, 22, 16, 22),
                                  (17.5, 22, 18.5, 21, 18.5, 19.5), (18.5, 18, 18.5, 13, 18.5, 11), (18.5, 9, 18, 9, 18, 9)])
            g.stroke.poly([(6.5, 9), (17.5, 9)])
            g.stroke.poly([(7, 9), (7, 5.5), (17, 5.5), (17, 9)])
            g.thin.poly([(8, 13.5), (16, 13.5), (16, 18), (8, 18)], close: true)
        // ---------------------------------------------------------------- stone fruit
        case .peach:
            g.stroke.shape(12, 6.5, [(7, 4.5, 3.5, 9, 3.8, 13.5), (4, 19, 8, 22, 12, 22), (16, 22, 20, 19, 20.2, 13.5), (20.5, 9, 17, 4.5, 12, 6.5)])
            g.thin.quad(12, 6.5, 9, 12, 11.5, 21.5)
            g.stroke.leaf(12.5, 6, 18.5, 2.5, 1.5)
        case .apricot:
            g.stroke.circle(12, 13.5, 7.5)
            g.thin.quad(12, 6, 10, 12, 12.5, 21)
            g.stroke.seg(12, 6, 12.6, 3.5)
        case .driedApricot:
            g.stroke.shape(4, 13, [(4, 8, 9, 6, 12.5, 6.5), (17, 7, 20.5, 9.5, 20, 13.5), (19.5, 18, 15, 19.5, 11.5, 19), (7, 18.5, 4, 17, 4, 13)])
            g.thin.quad(7.5, 12, 10, 10, 13, 11)
            g.thin.quad(11, 15.5, 14, 14, 16.5, 15)
        // ---------------------------------------------------------------- tropical
        case .banana:
            g.stroke.shape(4.5, 6.5, [(4, 15, 10, 21, 20, 18.5), (20.8, 18.3, 20.5, 17, 19.5, 16.8), (12, 17, 7, 13.5, 6.2, 6.5)], close: false)
            g.stroke.seg(6.2, 6.5, 4.5, 6.5)
            g.stroke.seg(5.3, 6.5, 5.6, 3.8)
            g.thin.quad(7, 10, 9, 15.5, 15, 17.5)
        case .lychee:
            g.stroke.circle(12, 13.5, 7.5)
            for (x, y) in [(9, 10.5), (12, 9), (15, 10.5), (8, 14), (11, 13), (14, 13), (16.5, 14.5), (9.5, 17.5), (12.5, 16.5), (15, 18)] as [(CGFloat, CGFloat)] {
                g.thin.poly([(x - 0.9, y + 0.5), (x, y - 0.5), (x + 0.9, y + 0.5)])
            }
            g.stroke.quad(12, 6, 12.5, 4, 14.5, 2.5)
        case .mango:
            g.stroke.shape(6.5, 7, [(10, 2.5, 18, 3.5, 19.5, 9), (21, 14.5, 18.5, 21.5, 13, 21.5), (7, 21.5, 3, 13, 6.5, 7)])
            g.stroke.leaf(12.5, 4.5, 18, 1.8, 1.2)
            g.thin.quad(8, 15, 9, 18.5, 12.5, 19.5)
        case .melon:
            g.stroke.move(to: CGPoint(x: 3, y: 9)); g.stroke.addLine(to: CGPoint(x: 21, y: 9))
            g.stroke.addQuadCurve(to: CGPoint(x: 3, y: 9), control: CGPoint(x: 12, y: 27))
            g.thin.quad(5.5, 10.8, 12, 23.5, 18.5, 10.8)
            for (x, y) in [(8.5, 12), (10.5, 13.2), (12, 13.6), (13.5, 13.2), (15.5, 12)] as [(CGFloat, CGFloat)] { g.fill.oval(x, y, 0.5, 0.9) }
        case .passionFruit:
            g.stroke.circle(12, 12, 8.5)
            g.thin.circle(12, 12, 6.3)
            for (x, y) in [(10, 9.5), (13.5, 9), (15, 12), (12, 12.5), (9, 13), (11, 15.5), (14, 15)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.8) }
        case .pineapple:
            g.stroke.oval(12, 15.5, 5.5, 6.8)
            g.thin.seg(8, 11.5, 15.5, 20.5)
            g.thin.seg(8.5, 16, 12, 21.5)
            g.thin.seg(16, 11.5, 8.5, 20.5)
            g.thin.seg(15.5, 16, 12, 21.5)
            g.thin.seg(11, 9.5, 16.5, 15)
            g.thin.seg(13, 9.5, 7.5, 15)
            g.stroke.poly([(9, 3), (11, 8.7)]); g.stroke.poly([(12, 2), (12, 8.7)]); g.stroke.poly([(15, 3), (13, 8.7)])
            g.stroke.poly([(7.5, 6), (10, 9)]); g.stroke.poly([(16.5, 6), (14, 9)])
        // ---------------------------------------------------------------- dried fruit
        case .fig:
            g.stroke.shape(12, 4.5, [(14, 8, 19.5, 10, 19.5, 15.5), (19.5, 19.5, 16, 22, 12, 22), (8, 22, 4.5, 19.5, 4.5, 15.5), (4.5, 10, 10, 8, 12, 4.5)])
            g.stroke.seg(12, 4.5, 12.5, 2.2)
            g.thin.quad(9, 17, 12, 19.5, 15, 17)
        case .prune:
            g.stroke.oval(12, 13, 7, 8.2, -12)
            g.thin.quad(8.5, 9, 11, 11, 9.5, 14)
            g.thin.quad(13, 15, 15.5, 16, 15, 19)
            g.thin.quad(13.5, 8, 15.5, 9.5, 15.2, 12)
        case .raisin:
            for (x, y) in [(8, 15.5), (15.5, 14.5), (11.5, 8.5)] as [(CGFloat, CGFloat)] {
                g.stroke.oval(x, y, 3.8, 3.3)
                g.thin.quad(x - 2, y - 0.5, x, y + 1, x + 2, y - 0.8)
            }
        case .fruitCake:
            g.stroke.poly([(3, 18), (3, 10), (13, 6), (21, 10), (21, 18), (11, 22), (3, 18)])
            g.stroke.poly([(3, 10), (11, 14), (21, 10)])
            g.stroke.seg(11, 14, 11, 22)
            for (x, y) in [(5.5, 14), (8, 17.5), (14, 16), (17.5, 14.5), (16.5, 18.5)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.8) }
        // ---------------------------------------------------------------- flowers
        case .flower, .orangeBlossom:
            for i in 0..<5 {
                let a = CGFloat(i) * 72 - 90
                let r: CGFloat = 5.2
                g.stroke.oval(12 + cos(a * .pi / 180) * r, 12 + sin(a * .pi / 180) * r, k == .orangeBlossom ? 2.3 : 3.2, 4.4, a + 90)
            }
            g.fill.circle(12, 12, 1.6)
            if k == .orangeBlossom {
                for i in 0..<5 {
                    let a = (CGFloat(i) * 72 - 54) * .pi / 180
                    g.thin.seg(12, 12, 12 + cos(a) * 3.2, 12 + sin(a) * 3.2)
                }
            }
        case .elderflower:
            let tips: [(CGFloat, CGFloat)] = [(5.5, 9), (8.5, 5.5), (12, 4.2), (15.5, 5.5), (18.5, 9), (8.5, 11), (15.5, 11), (12, 9)]
            for t in tips {
                g.thin.seg(12, 16, t.0, t.1 + 1.6)
                g.stroke.circle(t.0, t.1, 1.5)
            }
            g.stroke.seg(12, 16, 12, 22)
        case .honeysuckle:
            for (ex, ey, cx, cy) in [(5, 6, 8, 14), (12, 3.5, 11, 12), (19, 6.5, 16, 14)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                g.stroke.quad(12, 20, cx, cy, ex, ey)
                g.stroke.circle(ex, ey, 1.6)
            }
            g.thin.quad(5, 6, 3.5, 4.5, 2.5, 4.8)
            g.thin.quad(19, 6.5, 20.5, 5, 21.5, 5.4)
            g.stroke.seg(12, 20, 12, 22.5)
        case .acacia:
            g.stroke.quad(4, 21, 10, 15, 19, 5)
            for (x, y) in [(8, 11), (13.5, 14.5), (13.5, 7), (18.5, 11), (6.5, 16.5)] as [(CGFloat, CGFloat)] {
                g.stroke.circle(x, y, 2.4)
                g.fill.dot(x, y, 0.6)
            }
        case .rose:
            g.stroke.shape(5, 9, [(5, 15, 8, 18.5, 12, 18.5), (16, 18.5, 19, 15, 19, 9)], close: false)
            g.stroke.quad(5, 9, 8, 7, 9.5, 8.5)
            g.stroke.quad(19, 9, 16, 7, 14.5, 8.5)
            var sp = Path()
            sp.addArc(center: CGPoint(x: 12, y: 10.5), radius: 2.2, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: false)
            sp.addArc(center: CGPoint(x: 12, y: 11), radius: 4.6, startAngle: .degrees(90), endAngle: .degrees(330), clockwise: false)
            g.stroke.addPath(sp)
            g.stroke.seg(12, 18.5, 12, 23)
            g.stroke.leaf(12, 21, 17, 19, 1.3)
        case .violet:
            g.stroke.oval(9, 8, 2.8, 4, -25)
            g.stroke.oval(15, 8, 2.8, 4, 25)
            g.stroke.oval(6.5, 13, 2.8, 3.6, -70)
            g.stroke.oval(17.5, 13, 2.8, 3.6, 70)
            g.stroke.oval(12, 15.5, 3.2, 3.6)
            g.fill.circle(12, 11.8, 1.2)
            g.stroke.quad(12, 19, 12.5, 21, 11.5, 23)
        case .lavender:
            g.stroke.seg(12, 23, 12, 6)
            for i in 0..<5 {
                let y = 4.5 + CGFloat(i) * 2.6
                g.stroke.oval(10, y, 1.3, 2.1, -35)
                g.stroke.oval(14, y + 1.2, 1.3, 2.1, 35)
            }
            g.stroke.leaf(12, 20, 7, 16, 1.0)
        // ---------------------------------------------------------------- leaves & green
        case .leaf:
            g.stroke.leaf(4, 20, 20, 4, 4.5)
            g.thin.seg(4, 20, 16.5, 7.5)
            g.thin.seg(9, 15, 8.5, 11); g.thin.seg(12, 12, 11.5, 8.5); g.thin.seg(9.5, 14.5, 13.5, 15); g.thin.seg(12.5, 11.5, 16, 12)
        case .grass:
            g.stroke.quad(5, 21, 5, 13, 3, 6)
            g.stroke.quad(9, 21, 9.5, 11, 12, 3)
            g.stroke.quad(13.5, 21, 14, 13, 18.5, 6)
            g.stroke.quad(17.5, 21, 18.5, 16, 21.5, 12)
            g.stroke.seg(2.5, 21, 21.5, 21)
        case .tomatoLeaf:
            g.stroke.quad(12, 22, 12, 13, 12, 3)
            g.stroke.leaf(12, 5.5, 12, 2, 1.3)
            g.stroke.leaf(12, 9, 6, 6.5, 1.8)
            g.stroke.leaf(12, 9, 18, 6.5, 1.8)
            g.stroke.leaf(12, 14.5, 5, 13, 2.1)
            g.stroke.leaf(12, 14.5, 19, 13, 2.1)
        case .lobedLeaf:
            g.stroke.poly([(12, 3), (14.5, 7.5), (19.5, 6.5), (17.5, 11.5), (21, 14.5), (15.5, 16), (14, 19.5), (12, 17.5),
                           (10, 19.5), (8.5, 16), (3, 14.5), (6.5, 11.5), (4.5, 6.5), (9.5, 7.5)], close: true)
            g.thin.seg(12, 22.5, 12, 6); g.thin.seg(12, 16, 7, 9.5); g.thin.seg(12, 16, 17, 9.5)
            g.stroke.seg(12, 17.5, 12, 22.5)
        case .nettle:
            g.stroke.poly([(12, 3), (13.8, 5), (15.2, 4.8), (15.6, 7), (17.3, 7.6), (16.8, 10), (18.4, 11.2), (17, 13.4), (17.8, 15.2), (15.4, 16.5),
                           (14.8, 18.5), (12, 19.5), (9.2, 18.5), (8.6, 16.5), (6.2, 15.2), (7, 13.4), (5.6, 11.2), (7.2, 10), (6.7, 7.6),
                           (8.4, 7), (8.8, 4.8), (10.2, 5)], close: true)
            g.thin.seg(12, 22.5, 12, 6.5)
            g.stroke.seg(12, 19.5, 12, 22.5)
        case .tobacco:
            g.stroke.leaf(3, 19, 21, 6, 5.5)
            g.thin.seg(3, 19, 18.5, 7.8)
            for t in [0.3, 0.5, 0.7] as [CGFloat] {
                let x = 3 + 15.5 * t, y = 19 - 11.2 * t
                g.thin.quad(x, y, x - 1, y - 3, x - 0.5, y - 5)
                g.thin.quad(x, y, x + 3, y + 0.5, x + 5, y + 0.5)
            }
        case .fallenLeaves:
            g.stroke.leaf(3, 17, 13, 9, 3.2)
            g.stroke.leaf(21, 15, 11, 5, 3.0)
            g.thin.seg(3, 17, 11.5, 10.2); g.thin.seg(21, 15, 12.5, 6.5)
            g.stroke.seg(2.5, 21, 21.5, 21)
            g.fill.dot(8, 19.2, 0.7); g.fill.dot(15, 19.2, 0.7)
        // ---------------------------------------------------------------- herbs
        case .thyme:
            g.stroke.quad(6, 22, 9, 12, 17, 3)
            for i in 0..<6 {
                let t = CGFloat(i) / 6 + 0.08
                let x = 6 + (17 - 6) * t + (1 - t) * t * 2, y = 22 - 19 * t
                g.stroke.oval(x - 1.8, y - 0.3, 0.9, 1.6, -50)
                g.stroke.oval(x + 1.6, y + 0.6, 0.9, 1.6, 40)
            }
        case .mint:
            g.stroke.seg(12, 23, 12, 5)
            g.stroke.leaf(12, 7, 12, 2, 1.8)
            g.stroke.leaf(12, 11, 5, 7.5, 2.6)
            g.stroke.leaf(12, 11, 19, 7.5, 2.6)
            g.stroke.leaf(12, 17, 4.5, 14.5, 2.8)
            g.stroke.leaf(12, 17, 19.5, 14.5, 2.8)
        case .eucalyptus:
            g.stroke.quad(9, 23, 10, 12, 15, 2)
            for (x, y) in [(14.5, 5.5), (9, 7.5), (14.5, 11), (7.5, 13.5), (13.5, 16.5), (6.5, 19)] as [(CGFloat, CGFloat)] { g.stroke.circle(x, y, 2.3) }
        case .dill:
            g.stroke.seg(12, 23, 12, 12)
            for (ex, ey) in [(4.5, 6.5), (8, 3.5), (12, 2.5), (16, 3.5), (19.5, 6.5)] as [(CGFloat, CGFloat)] {
                g.thin.seg(12, 12, ex, ey)
                g.thin.seg(ex, ey, ex - 1.2, ey - 1.2); g.thin.seg(ex, ey, ex + 1.2, ey - 1.2)
            }
            g.thin.seg(12, 17, 7, 13.5); g.thin.seg(12, 17, 17, 13.5)
        case .fennel:
            g.stroke.shape(7, 15, [(7, 10.5, 9, 9.5, 10, 9), (12, 9.5, 12, 9.5, 14, 9), (15, 9.5, 17, 10.5, 17, 15), (17, 19.5, 14.5, 22, 12, 22), (9.5, 22, 7, 19.5, 7, 15)])
            g.thin.seg(12, 9.5, 12, 21.5)
            g.stroke.seg(10, 9, 8, 2.5); g.stroke.seg(12, 9.5, 12, 2); g.stroke.seg(14, 9, 16, 2.5)
            g.thin.seg(8.7, 4.8, 6.5, 4); g.thin.seg(15.3, 4.8, 17.5, 4)
        case .herbBundle:
            g.stroke.quad(12, 22, 11, 12, 6, 3.5)
            g.stroke.seg(12, 22, 12, 3)
            g.stroke.quad(12, 22, 13, 12, 18, 3.5)
            g.stroke.poly([(9.5, 15.5), (14.5, 15.5)])
            for (x, y, d) in [(7.5, 6.5, -1.0), (9, 9.5, -1.0), (12, 6, 1.0), (12, 10, -1.0), (16.5, 6.5, 1.0), (15, 9.5, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
                g.thin.oval(x + d * 1.4, y, 0.8, 1.6, d * 40)
            }
        // ---------------------------------------------------------------- vegetal, spice
        case .bellPepper:
            g.stroke.shape(5, 10, [(6, 7.5, 9, 8, 12, 8), (15, 8, 18, 7.5, 19, 10), (21, 14, 19, 21, 16.5, 21.5), (14.5, 22, 13, 20.5, 12, 20),
                                   (11, 20.5, 9.5, 22, 7.5, 21.5), (5, 21, 3, 14, 5, 10)])
            g.stroke.quad(12, 8, 11.8, 5, 15, 3)
            g.thin.quad(12, 11, 11.5, 15, 12, 19)
        case .asparagus:
            for (x0, x1) in [(8.5, 8), (12, 12), (15.5, 16)] as [(CGFloat, CGFloat)] {
                g.stroke.seg(x0, 22, x1, 6)
                g.stroke.oval(x1, 5, 1.5, 2.4)
                g.thin.seg(x1 - 1.3, 9.5, x1 - 0.1, 10.6); g.thin.seg(x1 + 1.3, 12.5, x1 + 0.1, 13.6)
            }
            g.stroke.poly([(6.5, 15.5), (17.5, 15.5), (17.5, 17.5), (6.5, 17.5)], close: true)
        case .peppercorns, .whitePepper:
            for (x, y) in [(8, 9), (15, 8), (11.5, 14), (18, 14.5), (6.5, 18), (13.5, 19.5)] as [(CGFloat, CGFloat)] {
                g.stroke.circle(x, y, 2.7)
                if k == .peppercorns { g.thin.quad(x - 1.3, y - 0.3, x, y + 0.8, x + 1.3, y - 0.3) }
            }
        case .liquorice:
            g.stroke.seg(5, 20, 19.5, 5.5)
            g.stroke.seg(7.5, 22, 22, 7.5)
            g.stroke.seg(5, 20, 7.5, 22); g.stroke.seg(19.5, 5.5, 22, 7.5)
            for t in stride(from: CGFloat(0.12), to: 1, by: 0.16) {
                let x = 5 + 14.5 * t, y = 20 - 14.5 * t
                g.thin.seg(x, y, x + 2.5 + 0.6, y + 2 + 0.6)
            }
        // ---------------------------------------------------------------- mineral
        case .flint:
            g.stroke.poly([(3.5, 17), (6.5, 9), (12.5, 5), (19.5, 8.5), (21, 15.5), (15, 20.5), (8, 20.5)], close: true)
            g.thin.poly([(6.5, 9), (11, 12.5), (12.5, 5)]); g.thin.poly([(11, 12.5), (15, 20.5)]); g.thin.poly([(11, 12.5), (21, 15.5)])
        case .pebbles:
            g.stroke.oval(9.5, 17, 6.5, 4.2)
            g.stroke.oval(15.5, 10.5, 5, 3.4, -10)
            g.stroke.shape(6.5, 4, [(6.5, 4, 4.5, 7, 4.5, 8), (4.5, 9.5, 8.5, 9.5, 8.5, 8), (8.5, 7, 6.5, 4, 6.5, 4)])
        case .chalk:
            g.stroke.poly([(4, 15), (15, 4), (20, 9), (9, 20)], close: true)
            g.thin.seg(15, 4, 13.8, 8.2); g.thin.seg(13.8, 8.2, 20, 9)
            g.fill.dot(5, 21, 0.7); g.fill.dot(8, 22.3, 0.6); g.fill.dot(3, 18.8, 0.6)
        case .saline:
            for y in [9.0, 14.0, 19.0] as [CGFloat] {
                g.stroke.move(to: CGPoint(x: 3, y: y))
                g.stroke.addCurve(to: CGPoint(x: 12, y: y), control1: CGPoint(x: 6, y: y - 3), control2: CGPoint(x: 9, y: y + 3))
                g.stroke.addCurve(to: CGPoint(x: 21, y: y), control1: CGPoint(x: 15, y: y - 3), control2: CGPoint(x: 18, y: y + 3))
            }
            g.thin.poly([(16.5, 2.5), (19, 2.5), (19, 5), (16.5, 5)], close: true)
        case .wool:
            g.stroke.circle(11, 12, 8)
            g.thin.quad(4, 9, 11, 6, 17, 13); g.thin.quad(5, 15, 12, 10, 18.5, 9.5); g.thin.quad(7, 18.5, 13, 15, 17, 17)
            g.stroke.quad(17.5, 16.5, 20, 21, 22.5, 20)
        // ---------------------------------------------------------------- yeast & dairy
        case .bread:
            g.stroke.shape(3, 18, [(3, 10, 7, 7, 12, 7), (17, 7, 21, 10, 21, 18)], close: false)
            g.stroke.seg(3, 18, 21, 18)
            g.thin.seg(8, 10.5, 10, 14.5); g.thin.seg(11.5, 9.5, 13.5, 13.5); g.thin.seg(15, 10.5, 17, 14.5)
        case .brioche:
            g.stroke.poly([(4.5, 12), (6.5, 21), (17.5, 21), (19.5, 12)])
            g.stroke.shape(4.5, 12, [(4.5, 9, 8, 8.5, 12, 8.5), (16, 8.5, 19.5, 9, 19.5, 12)], close: false)
            g.stroke.circle(12, 5.5, 3)
            g.thin.seg(8.5, 12, 9.5, 21); g.thin.seg(12, 12, 12, 21); g.thin.seg(15.5, 12, 14.5, 21)
        case .biscuit:
            g.stroke.circle(12, 12, 8.5)
            for (x, y) in [(9, 9), (15, 9), (12, 12), (9, 15), (15, 15)] as [(CGFloat, CGFloat)] { g.fill.dot(x, y, 0.8) }
            g.thin.circle(12, 12, 6.8)
        case .croissant:
            g.stroke.shape(2.5, 16, [(4, 9, 9, 6, 12, 6), (15, 6, 20, 9, 21.5, 16), (19, 14.5, 16.5, 14, 15, 15.5), (13.5, 14.5, 10.5, 14.5, 9, 15.5),
                                       (7.5, 14, 5, 14.5, 2.5, 16)])
            g.thin.quad(9, 15.5, 9, 10, 10.5, 6.6); g.thin.quad(15, 15.5, 15, 10, 13.5, 6.6)
        case .dough:
            g.stroke.shape(3, 17, [(3, 11, 7, 8, 12, 8), (17, 8, 21, 11, 21, 17), (21, 19, 18, 20, 12, 20), (6, 20, 3, 19, 3, 17)])
            g.thin.quad(7, 13, 10, 11, 13, 12.5); g.thin.quad(11, 16, 14, 14.5, 17, 15.5)
        case .cheese:
            g.stroke.poly([(3, 16), (16, 6), (21, 10), (21, 19), (3, 19)], close: true)
            g.stroke.poly([(3, 16), (21, 16)])
            g.thin.seg(16, 6, 21, 10)
            g.stroke.circle(9, 17.5, 0.9); g.stroke.circle(15, 12.5, 1.3); g.stroke.circle(17.5, 17.5, 0.9)
        case .butter:
            g.stroke.poly([(3, 12), (9, 8), (21, 8), (15, 12)], close: true)
            g.stroke.poly([(3, 12), (3, 18), (15, 18), (15, 12)])
            g.stroke.poly([(15, 18), (21, 14), (21, 8)])
            g.thin.seg(7, 12, 7, 18)
        case .jug:
            g.stroke.shape(7, 6, [(7, 6, 17, 6, 17, 6), (16, 9, 18, 13, 17.5, 17), (17, 21, 15, 22, 12, 22), (9, 22, 7, 21, 6.5, 17), (6, 13, 8, 9, 7, 6)])
            g.stroke.quad(17, 9, 21.5, 9.5, 17.5, 16)
            g.stroke.quad(7, 6, 5.5, 5, 5, 4)
            g.thin.quad(8, 12, 12, 13.5, 16.3, 12)
        case .tub:
            g.stroke.poly([(5, 9), (7, 21), (17, 21), (19, 9)])
            g.stroke.poly([(4, 6), (20, 6), (20, 9), (4, 9)], close: true)
            g.thin.seg(8, 14, 16, 14)
        // ---------------------------------------------------------------- oak & spice
        case .vanilla:
            g.stroke.quad(5, 21, 8, 12, 15, 3)
            g.stroke.quad(8, 22, 12, 13, 19, 5)
            g.stroke.seg(15, 3, 19, 5)
            g.thin.quad(9, 21.5, 12.5, 14, 17, 6.5)
            g.stroke.poly([(5, 21), (8, 22)])
        case .clove:
            g.stroke.seg(12, 22, 12, 10)
            g.stroke.poly([(9.5, 10.5), (12, 9), (14.5, 10.5)])
            g.stroke.circle(12, 6, 2.6)
            g.stroke.seg(9.4, 9.5, 8, 7.5); g.stroke.seg(14.6, 9.5, 16, 7.5)
        case .nutmeg:
            g.stroke.oval(12, 12, 6.5, 8.5)
            g.thin.quad(8, 7, 12, 11, 9.5, 17); g.thin.quad(12, 4, 15, 10, 12, 15); g.thin.quad(16, 9, 13, 14, 15.5, 19)
        case .coconut:
            g.stroke.circle(12, 12, 8.5)
            g.fill.dot(9.5, 9, 1.0); g.fill.dot(14.5, 9, 1.0); g.fill.dot(12, 13, 1.0)
            g.thin.quad(5, 15, 7, 18, 10, 20); g.thin.quad(14, 20, 17, 18.5, 19, 15)
        case .candy:
            g.stroke.oval(12, 12, 5.5, 4)
            g.stroke.poly([(6.6, 11), (2.5, 8), (2.5, 16), (6.6, 13)])
            g.stroke.poly([(17.4, 11), (21.5, 8), (21.5, 16), (17.4, 13)])
            g.thin.seg(10, 9, 12, 15); g.thin.seg(13, 8.5, 15, 14.5)
        case .caramel:
            g.stroke.poly([(4, 10), (9, 7), (15, 10), (10, 13)], close: true)
            g.stroke.poly([(4, 10), (4, 17), (10, 20), (10, 13)])
            g.stroke.poly([(10, 20), (15, 17), (15, 10)])
            g.stroke.poly([(15, 13), (20, 12), (20, 18), (15, 19.5)])
            g.thin.seg(17.5, 10.5, 20, 12)
        case .toast:
            g.stroke.shape(5, 21, [(5, 21, 5, 11, 5, 11), (2.5, 10, 3, 4, 8, 4), (10, 4, 11, 5, 12, 5.5), (13, 5, 14, 4, 16, 4),
                                   (21, 4, 21.5, 10, 19, 11), (19, 11, 19, 21, 19, 21)])
            g.stroke.seg(5, 21, 19, 21)
            g.thin.quad(8, 13, 12, 11, 16, 13); g.thin.quad(8, 16.5, 12, 14.5, 16, 16.5)
        case .log:
            g.stroke.oval(6.5, 13, 3.5, 6)
            g.stroke.poly([(6.5, 7), (19, 7)]); g.stroke.poly([(6.5, 19), (19, 19)])
            g.stroke.shape(19, 7, [(21.5, 7, 22, 19, 19, 19)], close: false)
            g.thin.oval(6.5, 13, 1.8, 3.3); g.fill.dot(6.5, 13, 0.6)
            g.thin.seg(11, 10, 17, 10); g.thin.seg(12, 15.5, 18, 15.5)
        case .charred:
            g.stroke.oval(6.5, 17, 2.8, 4)
            g.stroke.poly([(6.5, 13), (19, 13)]); g.stroke.poly([(6.5, 21), (19, 21)])
            g.stroke.shape(19, 13, [(21, 13, 21, 21, 19, 21)], close: false)
            g.stroke.shape(12, 11, [(9, 9.5, 9.5, 6, 11.5, 2.5), (12.5, 5, 15.5, 6, 14.5, 10)], close: false)
            g.stroke.quad(14.5, 10, 13.5, 11.2, 12, 11)
        case .smoke:
            g.stroke.shape(8, 22, [(5, 18, 11, 15, 8, 11), (5, 7, 10, 5, 9, 2)], close: false)
            g.stroke.shape(14, 22, [(11, 18, 17, 15, 14, 11), (11, 7, 16, 5, 15, 2)], close: false)
            g.thin.shape(19.5, 20, [(17.5, 17, 21.5, 14.5, 19.5, 11)], close: false)
        case .chocolate:
            g.stroke.poly([(5, 3), (19, 3), (19, 21), (9, 21), (5, 17)], close: true)
            g.thin.seg(5, 9, 19, 9); g.thin.seg(5, 15, 19, 15); g.thin.seg(12, 3, 12, 21)
        case .coffeeCup:
            g.stroke.poly([(4, 10), (5, 19), (15, 19), (16, 10)], close: true)
            g.stroke.shape(16, 12, [(19.5, 11.5, 20, 16, 15.3, 16.5)], close: false)
            g.stroke.seg(3, 21.5, 17, 21.5)
            g.thin.quad(8, 7.5, 7, 5.5, 8.5, 3); g.thin.quad(12, 7.5, 11, 5.5, 12.5, 3)
        case .coffeeBean:
            g.stroke.oval(12, 12, 6.5, 9, 30)
            g.stroke.shape(15.5, 4.5, [(11, 9, 14, 14, 8.5, 19.5)], close: false)
        case .cinnamon:
            g.stroke.seg(4, 18, 17, 5); g.stroke.seg(7, 21, 20, 8)
            g.stroke.oval(5.5, 19.5, 2.1, 2.1)
            g.stroke.shape(17, 5, [(19, 5, 20, 6.5, 20, 8)], close: false)
            for i in 0..<8 {
                let a = (CGFloat(i) * 45) * .pi / 180
                g.thin.leaf(17.5, 17.5, 17.5 + cos(a) * 4.5, 17.5 + sin(a) * 4.5, 0.9)
            }
            g.fill.dot(17.5, 17.5, 0.9)
        // ---------------------------------------------------------------- earthy & savory
        case .leather:
            g.stroke.poly([(6, 4), (9, 6), (15, 6), (18, 4), (19.5, 8), (17.5, 12), (19.5, 16), (18, 20.5), (15, 18.5), (9, 18.5), (6, 20.5),
                           (4.5, 16), (6.5, 12), (4.5, 8)], close: true)
            g.thin.poly([(8.5, 9), (15.5, 9), (15.5, 16), (8.5, 16)], close: true)
        case .earth:
            g.stroke.shape(2.5, 17, [(5, 11, 9, 9, 12, 9), (15, 9, 19, 11, 21.5, 17)], close: false)
            g.stroke.seg(2.5, 17, 21.5, 17)
            g.fill.dot(7, 20, 0.8); g.fill.dot(12, 21.5, 0.8); g.fill.dot(17, 20, 0.8); g.fill.dot(9.5, 14, 0.7); g.fill.dot(14.5, 13, 0.7)
        case .mushroom:
            g.stroke.shape(3, 12, [(3, 6, 8, 3.5, 12, 3.5), (16, 3.5, 21, 6, 21, 12)], close: false)
            g.stroke.seg(3, 12, 21, 12)
            g.stroke.shape(9.5, 12, [(9.5, 16, 8.5, 20, 9.5, 21), (11, 21.8, 13, 21.8, 14.5, 21), (15.5, 20, 14.5, 16, 14.5, 12)], close: false)
            g.fill.dot(8, 8, 0.9); g.fill.dot(13.5, 6.5, 0.9); g.fill.dot(17, 9, 0.8)
        case .truffle:
            g.stroke.shape(5, 13, [(4, 8, 8, 4.5, 12, 5), (15, 4, 20, 7, 19.5, 12), (21, 16, 17, 20.5, 12, 20), (7, 21, 4, 17, 5, 13)])
            for (x, y) in [(9, 9), (13, 8.5), (16, 12), (10, 13), (13.5, 16), (8, 16.5)] as [(CGFloat, CGFloat)] {
                g.thin.poly([(x - 0.8, y + 0.4), (x, y - 0.5), (x + 0.8, y + 0.4)])
            }
        case .feather:
            g.stroke.leaf(5, 20, 19, 4, 3.6)
            g.stroke.seg(3, 22, 17, 6)
            g.thin.seg(9.5, 15, 7.5, 11.5); g.thin.seg(12, 12, 10.5, 8.5); g.thin.seg(10, 14.5, 13.5, 16); g.thin.seg(12.5, 11.5, 16, 12.5)
        case .steak:
            g.stroke.shape(4, 12, [(3, 6, 10, 3.5, 15, 5), (20, 6.5, 21.5, 11, 20, 15), (18.5, 19.5, 13, 21, 9, 19.5), (6, 18.5, 4.5, 16, 4, 12)])
            g.stroke.circle(9.5, 12, 2.2)
            g.thin.quad(7, 6, 12, 6.5, 17.5, 9.5)
        // ---------------------------------------------------------------- aged white, nuts
        case .honeycomb:
            func hex(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> [(CGFloat, CGFloat)] {
                (0..<6).map { i in let a = (CGFloat(i) * 60 + 30) * .pi / 180; return (cx + cos(a) * r, cy + sin(a) * r) }
            }
            g.stroke.poly(hex(8.5, 9, 4), close: true)
            g.stroke.poly(hex(15.5, 9, 4), close: true)
            g.stroke.poly(hex(12, 15, 4), close: true)
            g.stroke.shape(12, 19, [(12, 20.5, 11, 21.5, 12, 22.5), (13, 21.5, 12, 20.5, 12, 19)], close: false)
        case .petrol:
            g.stroke.shape(12, 3, [(12, 3, 5.5, 11, 5.5, 15), (5.5, 19, 8.5, 21.5, 12, 21.5), (15.5, 21.5, 18.5, 19, 18.5, 15), (18.5, 11, 12, 3, 12, 3)])
            g.thin.quad(8.5, 15, 9, 18, 12, 18.8)
            g.thin.quad(10.5, 13, 12, 12.5, 13, 14)
        case .hay:
            for x in stride(from: CGFloat(5), through: 19, by: 2.8) {
                g.stroke.quad(12, 15, x + (x - 12) * 0.2, 9, x, 3)
                g.thin.seg(12, 15, 12 + (x - 12) * 0.9, 22)
            }
            g.stroke.poly([(9, 14), (15, 14), (15, 16), (9, 16)], close: true)
        case .almond:
            g.stroke.shape(12, 3, [(17, 7, 18, 13, 16.5, 17), (15, 20.5, 13.5, 21.5, 12, 21.5), (10.5, 21.5, 9, 20.5, 7.5, 17), (6, 13, 7, 7, 12, 3)])
            g.thin.quad(12, 6, 10, 11, 11, 18); g.thin.quad(14, 9, 14.5, 13, 13.5, 17)
        case .hazelnut:
            g.stroke.circle(12, 14, 7)
            g.stroke.poly([(5, 11), (6.5, 7.5), (8.5, 9), (10, 5.5), (12, 8), (14, 5.5), (15.5, 9), (17.5, 7.5), (19, 11)])
            g.stroke.seg(12, 5.5, 12.5, 2.5)
            g.thin.quad(8.5, 16, 9, 18.5, 11.5, 19.5)
        case .walnut:
            g.stroke.oval(12, 12, 8.5, 9)
            g.stroke.seg(12, 3, 12, 21)
            g.thin.quad(5, 9, 8, 8, 9.5, 11); g.thin.quad(5, 15, 8, 13, 9.5, 16)
            g.thin.quad(19, 9, 16, 8, 14.5, 11); g.thin.quad(19, 15, 16, 13, 14.5, 16)
        case .generic:
            g.stroke.circle(12, 12, 7)
        }
        return g
    }
}
