import SwiftUI

/// The expected structure of a bottle (1–5 like the grape pages): its grapes blended by share, then nudged for the style
/// (sparkling, rosé, sweet, fortified) and for the climate of the place (cool places keep more acidity, warm ones more alcohol).
struct WineProfile: Equatable {
    var sweetness: Int
    var body: Int
    var tannin: Int
    var acidity: Int
    var alcohol: Int

    private static let cool = ["germany", "england", "united kingdom", "austria", "new zealand", "champagne", "chablis", "mosel",
                               "loire", "sancerre", "alsace", "burgundy", "bourgogne", "oregon", "tasmania", "jura", "savoie",
                               "alto adige", "sudtirol", "canada", "ontario", "finger lakes", "rias baixas", "vinho verde", "marlborough"]
    private static let warm = ["barossa", "mclaren vale", "napa", "paso robles", "lodi", "priorat", "douro", "mendoza", "puglia",
                               "sicily", "sicilia", "sardinia", "sardegna", "campania", "chateauneuf", "languedoc", "roussillon",
                               "jumilla", "toro", "alentejo", "stellenbosch", "swartland", "bekaa", "california", "central valley", "riverland"]

    static func estimate(_ w: WineIdentity) -> WineProfile? {
        let grapes = w.grapes.compactMap(matchGrape)
        guard !grapes.isEmpty else { return nil }
        // weights: the blend percentages when known, else the first grape counts most
        var weights: [Double] = grapes.indices.map { $0 == 0 ? 2 : 1 }
        if let p = w.grapePercent, p.count == w.grapes.count {
            let matched = w.grapes.enumerated().compactMap { i, n in matchGrape(n) == nil ? nil : Double(max(1, p[i])) }
            if matched.count == grapes.count { weights = matched }
        }
        let total = weights.reduce(0, +)
        func mix(_ k: KeyPath<Grape, Int>) -> Double { zip(grapes, weights).map { Double($0[keyPath: k]) * $1 }.reduce(0, +) / total }
        var sweet = mix(\.sweetness), body = mix(\.body), tannin = mix(\.tannin), acid = mix(\.acidity), alc = mix(\.alcohol)

        let style = w.style.lowercased()
        if style.contains("spark") { body -= 0.8; alc -= 1; acid += 0.6; tannin = 1 }
        if style.contains("ros") { body -= 0.6; tannin = 1 }
        if style.contains("white") || style.contains("orange") { tannin = style.contains("orange") ? max(2, tannin) : 1 }
        if style.contains("sweet") { sweet = max(sweet, 4.4) }
        if style.contains("fortified") { alc = 5; body = max(body, 4); sweet = max(sweet, 3.5) }

        let place = (w.region + " " + w.country).folding(options: .diacriticInsensitive, locale: nil).lowercased()
        if cool.contains(where: { place.contains($0) }) { acid += 0.5; alc -= 0.5; body -= 0.3 }
        else if warm.contains(where: { place.contains($0) }) { alc += 0.5; body += 0.4; acid -= 0.4 }

        func r(_ v: Double) -> Int { min(5, max(1, Int(v.rounded()))) }
        return WineProfile(sweetness: r(sweet), body: r(body), tannin: r(tannin), acidity: r(acid), alcohol: r(alc))
    }

    /// What you noted in a tasting of this wine, on the same scale (your sweetness is out of 4, scaled to 5).
    static func tasted(_ e: JournalEntry) -> WineProfile {
        WineProfile(sweetness: min(5, max(1, Int((Double(e.sweetness) * 5 / 4).rounded()))), body: e.body, tannin: e.tannin,
                    acidity: e.acidity, alcohol: 0)
    }
}

extension WineIdentity {
    /// A wine of the Atlas (Wines of the world, Great wines) as an identity, so it gets the same expected profile as a scanned bottle.
    static func catalogue(grapes: [Grape], style: String, region: String, country: String) -> WineIdentity {
        var w = WineIdentity.empty
        w.found = true
        w.grapes = grapes.map(\.name)
        w.style = style; w.region = region; w.country = country
        return w
    }
}

extension Wine {
    var identity: WineIdentity {
        let cat = (styleInfo?.category ?? "").lowercased()
        let style = cat.hasPrefix("fortified") ? "fortified" : (kind == .all ? "" : kind.rawValue)
        return .catalogue(grapes: grapeInfos, style: style, region: regionInfo?.name ?? "", country: country)
    }
}

extension GreatWine {
    var identity: WineIdentity {
        .catalogue(grapes: grapeInfos, style: color, region: [zone, regionInfo?.name ?? ""].joined(separator: " "),
                   country: regionInfo?.country ?? "")
    }
}

/// "Wine profile" on a bottle's page: the expected structure, and when you have tasted it, your own marks beside it.
struct BottleProfileCard: View {
    let wine: WineIdentity
    var tasting: JournalEntry? = nil

    var body: some View {
        if let p = WineProfile.estimate(wine) {
            let mine = tasting.map(WineProfile.tasted)
            let red = wine.style.lowercased().contains("red") || (wine.style.isEmpty && (wine.grapes.first.flatMap(matchGrape)?.berry == .black))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Wine profile").font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    if mine != nil {
                        HStack(spacing: 10) {
                            legend(Palette.wine, "Expected")
                            legend(Palette.brass, "You")
                        }
                    }
                }
                Text(mine == nil ? "What to expect, from its grapes, style and where it grows."
                                 : "What to expect, and what you noted when you tasted it.")
                    .font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).padding(.top, -6)
                VStack(spacing: 11) {
                    row("Sweetness", p.sweetness, mine?.sweetness, StructureBars.sweetWord(p.sweetness), 0)
                    row("Body", p.body, mine?.body, StructureBars.level(p.body, low: "Light", high: "Full"), 0.06)
                    if red { row("Tannin", p.tannin, mine?.tannin, StructureBars.level(p.tannin), 0.12) }
                    row("Acidity", p.acidity, mine?.acidity, StructureBars.level(p.acidity), 0.18)
                    row("Alcohol", p.alcohol, nil, StructureBars.abvShort(p.alcohol), 0.24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 16)
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(c).frame(width: 12, height: 4)
            Text(t).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
        }
    }

    private func row(_ label: String, _ v: Int, _ yours: Int?, _ word: String, _ d: Double) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.jero(size: 13, weight: .medium)).foregroundStyle(Palette.ink).frame(width: 74, alignment: .leading)
            VStack(spacing: 4) {
                SegmentMeter(value: v, tint: Palette.wine, delay: d)
                if let y = yours, y > 0 { SegmentMeter(value: y, tint: Palette.brass, delay: d + 0.1) }
            }
            Text(word).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).frame(width: 78, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(word)" + (yours.map { $0 > 0 ? ", you noted \(StructureBars.level($0))" : "" } ?? ""))
    }
}
