import SwiftUI

/// An icon wine to try, region by region (content/greatwines.yaml).
struct GreatWine: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let producer: String
    let region: String
    let zone: String
    let grapes: [String]
    let color: String
    let price: [Int]
    let scores: String
    let vintages: [String]
    let photo: String?
    let what: String
    let why: String

    static func == (a: GreatWine, b: GreatWine) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var regionInfo: Region? { ContentStore.shared.library.regions.first { $0.id == region } }
    var grapeInfos: [Grape] { grapes.compactMap { ContentStore.shared.grape($0) } }
    /// "Bordeaux", "Burgundy", "Tuscany"… for grouping.
    var area: String { zone.components(separatedBy: " · ").first ?? zone }
    var priceText: String {
        guard price.count == 2 else { return "" }
        func f(_ v: Int) -> String { v >= 1000 ? "$\(v / 1000),\(String(format: "%03d", v % 1000))" : "$\(v)" }
        return "\(f(price[0]))–\(f(price[1]))"
    }
    var tint: Color {
        switch color {
        case "white": return Color(hex: "#C9A227")
        case "sparkling": return Color(hex: "#B8A35A")
        case "sweet": return Color(hex: "#B8701E")
        default: return Palette.bordeaux
        }
    }
}

/// Uniform bottle picture: same frame, same crop, same soft ground for every wine.
struct GreatWineImage: View {
    let wine: GreatWine
    var corner: CGFloat = 16
    var body: some View {
        ZStack {
            LinearGradient(colors: [wine.tint.opacity(0.18), wine.tint.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            if let p = wine.photo, let img = Photos.image(p) {
                Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill())
                    .clipped()
            } else {
                SilhouetteGlass(shape: wine.color == "sparkling" ? .flute : (wine.color == "white" ? .white : .red),
                                color: wine.tint, fill: 0.55, sparkling: wine.color == "sparkling")
                    .padding(28)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

struct GreatWinesScreen: View {
    var body: some View {
        let wines = ContentStore.shared.library.great ?? []
        let areas = wines.reduce(into: [String]()) { if !$0.contains($1.area) { $0.append($1.area) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: "Atlas", title: "Great wines to try",
                             subtitle: "\(wines.count) icons, region by region: what they are, why people love them, what they cost and how critics score them.")
                ForEach(areas, id: \.self) { a in
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: a)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)], spacing: 16) {
                            ForEach(wines.filter { $0.area == a }) { w in
                                NavigationLink(value: w) { tile(w) }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                Text("Prices are a rough US retail guide for a recent release; scores are the usual range critics give recent vintages. Photos: Wikimedia Commons.")
                    .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                Color.clear.frame(height: 10)
            }
            .padding(.horizontal, Metrics.margin)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: "great") } }
    }

    private func tile(_ w: GreatWine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GreatWineImage(wine: w)
                .overlay(alignment: .topTrailing) {
                    Text(w.scores).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                        .padding(.horizontal, 7).frame(height: 22)
                        .background(Capsule().fill(Palette.bordeaux.opacity(0.92)))
                        .padding(8)
                }
            Text(w.name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
            Text(w.priceText).font(.system(size: 12.5, weight: .medium).monospacedDigit()).foregroundStyle(Palette.inkSoft)
        }
    }
}

struct GreatWineDetail: View {
    let wine: GreatWine
    var body: some View {
        let w = wine
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    GreatWineImage(wine: w, corner: 20).frame(width: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(w.zone, color: Palette.wine)
                        Text(w.name).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(w.producer).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        Spacer(minLength: 4)
                        stat("Price", w.priceText, "tag")
                        stat("Critics", "\(w.scores) pts", "star.fill")
                    }
                }
                block("What it is", w.what)
                block("Why people love it", w.why)
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Vintages to know")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(w.vintages, id: \.self) { v in
                            Text(v).font(.system(size: 13.5, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                                .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Palette.wineSoft))
                        }
                    }
                }
                if !w.grapeInfos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Grapes")
                        HStack(spacing: 14) {
                            ForEach(w.grapeInfos) { g in
                                VStack(spacing: 4) {
                                    GrapeBadge(grape: g, size: 54)
                                    Text(g.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                if let r = w.regionInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Where it’s from")
                        WineLocationMap(region: r)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    }
                }
                if let p = w.photo, let c = Photos.creditLine(p) {
                    Text("Photo: " + c).font(.system(size: 10.5)).foregroundStyle(Palette.inkFaint)
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Palette.wine).frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(t).font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
                Text(v).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
            }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            Text(text).font(.system(size: 16)).foregroundStyle(Palette.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: 16)
    }
}
