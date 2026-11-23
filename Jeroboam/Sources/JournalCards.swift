import SwiftUI

/// The top of a wine's page in the Journal: the things you want to know first, as four small tiles, then where it comes from.
struct WineGlance: View {
    let wine: WineIdentity
    var price: PriceInfo? = nil
    /// The score: your own points for a tasting, a rough guess for a bottle in the cellar.
    var points: Int? = nil
    var pointsAreGuess = false

    private var grapeLine: String { wine.grapes.first ?? "–" }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(icon: "star.fill", label: pointsAreGuess ? "Score (estimate)" : "Score",
                     value: points.map { "\($0)" } ?? "–", unit: points == nil ? "" : "pts",
                     note: points.map { RatingGuide.band($0).0 } ?? "Taste it to score it")
                tile(icon: "calendar", label: "Vintage", value: wine.vintage.isEmpty ? "NV" : wine.vintage, unit: "",
                     note: (wine.drinkWindow?.isEmpty == false) ? "Drink \(wine.drinkWindow!)" : "Drinking window unknown")
                tile(icon: "tag", label: priceLabel, value: price.map { $0.averageText } ?? "–", unit: price == nil ? "" : "/ 750 ml",
                     note: priceNote)
                tile(icon: "leaf", label: "Main grape", value: grapeLine, unit: "",
                     note: wine.grapes.count > 1 ? "+ \(wine.grapes.count - 1) more" : (wine.style.isEmpty ? "" : wine.style.capitalized), small: true)
            }
            RegionMapCard(wine: wine)
            if !wine.funFact.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(Palette.wine).frame(width: 22).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Did you know").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                        Text(wine.funFact).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.9)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
            }
        }
    }

    private var priceLabel: String {
        guard let p = price else { return "Price" }
        return p.source == "You paid" ? "You paid" : ((p.source.hasPrefix("Cheapest") || p.source.hasPrefix("Shop price")) ? "Lowest found" : "Price (estimate)")
    }
    private var priceNote: String {
        guard let p = price else { return "Not found yet" }
        if p.source == "You paid" { return "Your own price" }
        return p.source.components(separatedBy: " · ").first ?? p.source
    }

    private func tile(icon: String, label: String, value: String, unit: String, note: String, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.wine)
                Text(label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: small ? 18 : 25, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if !unit.isEmpty { Text(unit).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft) }
            }
            Text(note).font(.system(size: 11.5)).foregroundStyle(Palette.inkFaint).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}

/// Where the wine comes from, on the Atlas map, with a link to that place's page.
struct RegionMapCard: View {
    let wine: WineIdentity
    var body: some View {
        if let r = ContentStore.shared.regionMatching(wine.region, country: wine.country), let m = r.map {
            DetailLink(value: r) {
                VStack(alignment: .leading, spacing: 0) {
                    WineMapView(mapID: m, highlight: Set(r.highlight ?? (r.kind == "country" ? [] : [r.id])), showCities: false, labelScale: 0.85, fill: true)
                        .frame(height: 150).frame(maxWidth: .infinity).clipped().allowsHitTesting(false)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(r.kind == "country" ? "Country" : r.country).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Text("Open in the Atlas").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.wine)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.wine)
                    }
                    .padding(12)
                }
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
            }
            .buttonStyle(PressableStyle())
        }
    }
}
