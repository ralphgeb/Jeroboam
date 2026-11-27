import SwiftUI
import Charts

/// Which cellar figure is open.
enum CellarStat: String, Hashable { case value, average, gain }

/// The graphs that open under a cellar figure. One panel per figure; everything below is pushed down.
struct CellarChartPanel: View {
    let stat: CellarStat
    let bottles: [CellarBottle]
    let currency: String

    private struct Slice: Identifiable { let id: String; let label: String; let value: Double; let color: Color }
    private struct Gain: Identifiable { let id: UUID; let name: String; let amount: Double }
    private struct Pair: Identifiable { let id = UUID(); let name: String; let kind: String; let amount: Double }

    private func family(_ s: String) -> String {
        let t = s.lowercased()
        if t.contains("spark") || t.contains("champ") { return "sparkling" }
        if t.contains("ros") { return "rose" }
        if t.contains("sweet") || t.contains("fortif") || t.contains("dessert") { return "sweet" }
        if t.contains("white") || t.contains("orange") { return "white" }
        return "red"
    }
    private func familyName(_ k: String) -> String {
        ["red": "Red", "white": "White", "rose": "Rosé", "sparkling": "Sparkling", "sweet": "Sweet & fortified"][k] ?? k
    }
    private func short(_ s: String, _ n: Int = 16) -> String { s.count > n ? String(s.prefix(n - 1)) + "…" : s }

    // MARK: data

    private var byColor: [Slice] {
        var d: [String: Double] = [:]
        for b in bottles { d[family(b.wine.style), default: 0] += stat == .average ? Double(b.quantity) : b.value }
        return d.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            .map { Slice(id: $0.key, label: familyName($0.key), value: $0.value, color: styleColor($0.key)) }
    }
    private var byCountry: [Slice] {
        var d: [String: Double] = [:]
        for b in bottles {
            let c = b.wine.country.trimmingCharacters(in: .whitespaces)
            d[c.isEmpty ? "Unknown" : c, default: 0] += stat == .average ? Double(b.quantity) : b.value
        }
        return Array(d.sorted { $0.value > $1.value }.prefix(6)).map { Slice(id: $0.key, label: $0.key, value: $0.value, color: Palette.wine) }
    }
    private var bands: [(String, Int)] {
        let edges: [(String, Double, Double)] = [("<25", 0, 25), ("25–50", 25, 50), ("50–100", 50, 100), ("100–200", 100, 200), ("200+", 200, .infinity)]
        return edges.map { name, lo, hi in
            (name, bottles.filter { b in
                guard let p = b.price?.average else { return false }
                return p >= lo && p < hi
            }.reduce(0) { $0 + $1.quantity })
        }
    }
    private var topValue: [CellarBottle] { Array(bottles.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(6)) }
    private var paidVsValue: [Pair] {
        bottles.filter { $0.paidUSD != nil && $0.price != nil }.sorted { $0.value > $1.value }.prefix(6).flatMap { b in
            [Pair(name: short(b.title), kind: "Paid", amount: b.paidTotal ?? 0), Pair(name: short(b.title), kind: "Worth now", amount: b.value)]
        }
    }
    private var gains: [Gain] {
        let all = bottles.compactMap { b in b.paidTotal.map { Gain(id: b.id, name: short(b.title), amount: b.value - $0) } }
        return Array(all.sorted { abs($0.amount) > abs($1.amount) }.prefix(7))
    }

    // MARK: body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch stat {
            case .value:
                title("Where the value sits", "By colour, and the countries worth the most")
                donut(byColor)
                barList(byCountry, money: true, heading: "Value by country")
                title("Most valuable bottles", nil)
                topList
            case .average:
                title("Your bottles", "What they cost, and where they are from")
                donut(byColor)
                barList(byCountry, money: false, heading: "Bottles by country")
                title("How they are priced", "Bottles in each price band (\(currencySymbol))")
                Chart(bands, id: \.0) { band in
                    BarMark(x: .value("Band", band.0), y: .value("Bottles", band.1))
                        .foregroundStyle(Palette.wine.gradient).cornerRadius(5)
                        .annotation(position: .top) { if band.1 > 0 { Text("\(band.1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkSoft) } }
                }
                .chartYAxis(.hidden).frame(height: 150)
                if let avg = average {
                    Text("Average bottle: \(money(avg, currency))").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
                title("Priciest bottles", nil)
                topList
            case .gain:
                title("What you paid and what it is worth", "Your biggest bottles, side by side")
                if paidVsValue.isEmpty { empty("Add the price you paid on a bottle's page to see this.") }
                else {
                    Chart(paidVsValue) { p in
                        BarMark(x: .value("Amount", p.amount), y: .value("Wine", p.name))
                            .foregroundStyle(by: .value("Kind", p.kind)).position(by: .value("Kind", p.kind)).cornerRadius(3)
                    }
                    .chartForegroundStyleScale(["Paid": Palette.inkFaint, "Worth now": Palette.wine])
                    .chartXAxis(.hidden).frame(height: CGFloat(paidVsValue.count / 2) * 46 + 30)
                }
                title("Gain and loss", "Worth now minus what you paid")
                if gains.isEmpty { empty("Add the price you paid on a bottle's page to see this.") }
                else {
                    Chart(gains) { g in
                        BarMark(x: .value("Gain", g.amount), y: .value("Wine", g.name))
                            .foregroundStyle(g.amount >= 0 ? Palette.sage : Palette.wrong).cornerRadius(4)
                        RuleMark(x: .value("Zero", 0)).foregroundStyle(Palette.line)
                    }
                    .chartXAxis(.hidden).frame(height: CGFloat(gains.count) * 32 + 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    }

    private var currencySymbol: String { currency }
    private var average: Double? {
        let priced = bottles.filter { $0.price != nil }
        let n = priced.reduce(0) { $0 + $1.quantity }
        return n == 0 ? nil : priced.reduce(0.0) { $0 + $1.value } / Double(n)
    }

    private func title(_ t: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Palette.ink)
            if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft) }
        }
    }
    private func empty(_ t: String) -> some View {
        Text(t).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).padding(.vertical, 14)
    }

    private func donut(_ slices: [Slice]) -> some View {
        HStack(spacing: 18) {
            Chart(slices) { s in
                SectorMark(angle: .value("Amount", s.value), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .foregroundStyle(s.color).cornerRadius(3)
            }
            .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                let total = max(1, slices.reduce(0) { $0 + $1.value })
                ForEach(slices) { s in
                    HStack(spacing: 8) {
                        Circle().fill(s.color).frame(width: 9, height: 9)
                        Text(s.label).font(.system(size: 13)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 4)
                        Text("\(Int((s.value / total * 100).rounded()))%").font(.system(size: 13).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
    }

    /// Each row: the name and its number on one line, a bar under them. Plain views, so nothing is ever cut to "…".
    private func barList(_ slices: [Slice], money m: Bool, heading: String) -> some View {
        let top = max(1, slices.map(\.value).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text(heading).font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
            ForEach(slices) { s in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(s.label).font(.system(size: 13.5)).foregroundStyle(Palette.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(m ? money(s.value, currency) : "\(Int(s.value))").font(.system(size: 13.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.ink).fixedSize()
                    }
                    GeometryReader { g in
                        Capsule().fill(Palette.wine.opacity(0.85)).frame(width: max(6, g.size.width * CGFloat(s.value / top)))
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private var topList: some View {
        VStack(spacing: 8) {
            ForEach(Array(topValue.enumerated()), id: \.element.id) { i, b in
                HStack(spacing: 10) {
                    Text("\(i + 1)").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Palette.onWine)
                        .frame(width: 22, height: 22).background(Circle().fill(Palette.wine))
                    Text(b.title).font(.system(size: 14)).foregroundStyle(Palette.ink).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(money(b.value, currency)).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                }
            }
        }
    }
}

/// A panel that opens downward from the tile above it: it unfolds from its top edge while everything below slides down.
struct ExpandFold: ViewModifier {
    var p: CGFloat
    func body(content: Content) -> some View {
        content.scaleEffect(x: 1, y: max(0.001, p), anchor: .top).opacity(Double(p))
    }
}
extension AnyTransition {
    static var unfold: AnyTransition { .modifier(active: ExpandFold(p: 0), identity: ExpandFold(p: 1)) }
}

/// Content that opens downward by its real height and closes the same way: the frame grows from 0 to the content's measured height
/// (clipped), so whatever sits below follows it smoothly in both directions.
struct Reveal<Content: View>: View {
    let open: Bool
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { g in Color.clear.preference(key: RevealHeight.self, value: g.size.height) })
            .onPreferenceChange(RevealHeight.self) { height = $0 }
            .frame(height: open ? height : 0, alignment: .top)
            .clipped()
            .opacity(open ? 1 : 0)
            .allowsHitTesting(open)
    }
}

private struct RevealHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
