import SwiftUI

/// A classic wine from the catalog (content/wines.yaml).
struct Wine: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let grapes: [String]
    let style: String
    let glass: String
    let body: Int
    let price: Int
    let summary: String
    let taste: [String]
    let food: [String]

    static func == (a: Wine, b: Wine) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var regionInfo: Region? { ContentStore.shared.library.regions.first { $0.id == region } }
    var styleInfo: WineStyle? { ContentStore.shared.library.styles.first { $0.id == style } }
    var colorInfo: WineColor? { ContentStore.shared.library.colors.first { $0.id == glass } }
    var grapeInfos: [Grape] { grapes.compactMap { id in ContentStore.shared.library.grapes.first { $0.id == id } } }
    var country: String { regionInfo?.country ?? "" }

    var kind: WineKind {
        let cat = styleInfo?.category ?? ""
        if cat.hasPrefix("Sparkling") { return .sparkling }
        if cat.hasPrefix("Sweet") || cat.hasPrefix("Fortified") { return .sweet }
        switch colorInfo?.family {
        case "rose": return .rose
        case "red": return .red
        default: return .white
        }
    }
}

enum WineKind: String, CaseIterable, Identifiable {
    case all, white, rose, red, sparkling, sweet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .white: return "White"
        case .rose: return "Rosé"
        case .red: return "Red"
        case .sparkling: return "Sparkling"
        case .sweet: return "Sweet & fortified"
        }
    }
}

extension ZoomID {
    static func wine(_ id: String) -> String { "w:" + id }
}

/// Small colored glass for a wine.
struct WineGlassIcon: View {
    let wine: Wine
    var height: CGFloat = 34
    var body: some View {
        let hex = wine.colorInfo?.hex ?? "#8E1E3F"
        WineGlass(color: Color(hex: hex), fill: 0.55, sparkling: wine.kind == .sparkling)
            .frame(width: height * 0.55, height: height)
    }
}

// MARK: - Catalog

struct WinesScreen: View {
    @State private var kind: WineKind = .all

    var body: some View {
        let all = ContentStore.shared.library.wines ?? []
        let shown = all.filter { kind == .all || $0.kind == kind }
        let countries = shown.reduce(into: [String]()) { if !$0.contains($1.country) { $0.append($1.country) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: "Atlas", title: "Wines of the world",
                             subtitle: "\(all.count) classics, from Chablis to Barossa Shiraz: where they come from, which grapes, and what to expect.")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(WineKind.allCases) { k in
                            Button { withAnimation(.snappy) { kind = k } } label: {
                                Text(k.title).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(kind == k ? Palette.onWine : Palette.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(kind == k ? Palette.wine : Palette.card))
                                    .overlay(Capsule().strokeBorder(Palette.line.opacity(kind == k ? 0 : 0.8), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -Metrics.margin).contentMargins(.horizontal, Metrics.margin, for: .scrollContent)

                ForEach(countries, id: \.self) { c in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: c)
                        let items = shown.filter { $0.country == c }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        GroupCard {
                            ForEach(items) { w in
                                DetailLink(value: w) {
                                    WineRow(wine: w, last: w == items.last)
                                }
                                .buttonStyle(RowPressStyle())
                            }
                        }
                    }
                }
                Color.clear.frame(height: 12)
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: "wines") } }
        .detailPane(first: shown.first.map { AnyHashable($0) })
    }
}

struct WineRow: View {
    let wine: Wine
    var last = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                WineGlassIcon(wine: wine, height: 34).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wine.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
            if !last { Hairline().padding(.leading, 68) }
        }
    }
    private var subtitle: String {
        let g = wine.grapeInfos.map(\.name).joined(separator: ", ")
        let r = wine.regionInfo?.name ?? ""
        return g.isEmpty ? r : "\(r) · \(g)"
    }
}

// MARK: - Detail

struct WineDetailView: View {
    let wine: Wine

    var body: some View {
        let w = wine
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top, spacing: 16) {
                    ScreenHeader(eyebrow: [w.regionInfo?.name, w.country].compactMap { $0 }.joined(separator: " · "),
                                 title: w.name, subtitle: w.summary)
                    WineGlassIcon(wine: w, height: 70).padding(.top, 22)
                }

                GroupCard {
                    factRow("Body") { SegmentMeter(value: w.body, tint: Palette.wine).frame(width: 120) }
                    Hairline().padding(.leading, 14)
                    factRow("Price") {
                        HStack(spacing: 1) {
                            ForEach(1...4, id: \.self) { i in
                                Text("$").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(i <= w.price ? Palette.wine : Palette.inkFaint.opacity(0.5))
                            }
                        }
                    }
                    if let c = w.colorInfo {
                        Hairline().padding(.leading, 14)
                        factRow("Color") {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: c.hex)).frame(width: 12, height: 12)
                                Text(c.name).font(.system(size: 14)).foregroundStyle(Palette.ink)
                            }
                        }
                    }
                }

                if !w.taste.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "In the glass")
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(w.taste.prefix(4), id: \.self) { n in
                                VStack(spacing: 6) {
                                    FlavorIcon(aroma: n, size: 30)
                                    Text(n.prefix(1).uppercased() + n.dropFirst()).font(.system(size: 12)).foregroundStyle(Palette.ink)
                                        .multilineTextAlignment(.center).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .cardStyle(padding: 14)
                    }
                }

                if !w.grapeInfos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: w.grapeInfos.count == 1 ? "The grape" : "The grapes")
                        GroupCard {
                            ForEach(w.grapeInfos) { g in
                                NavigationLink(value: g) {
                                    IconRow(title: g.name, detail: g.berry == .white ? "White grape" : "Black grape", last: g == w.grapeInfos.last) {
                                        GrapeBadge(grape: g, size: 34, disc: false)
                                    }
                                }
                                .buttonStyle(RowPressStyle())
                            }
                        }
                    }
                }

                if let r = w.regionInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Where it’s from")
                        VStack(alignment: .leading, spacing: 0) {
                            WineLocationMap(region: r)
                            NavigationLink(value: r) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(r.country).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RowPressStyle())
                        }
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                    }
                }

                if let s = w.styleInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Style")
                        GroupCard {
                            NavigationLink(value: s) {
                                IconRow(title: s.name, detail: s.category, last: true) {
                                    Image(systemName: "wineglass").font(.system(size: 16)).foregroundStyle(Palette.wine)
                                }
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                }

                if !w.food.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Try it with")
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(w.food, id: \.self) { f in
                                Label(f.prefix(1).uppercased() + f.dropFirst(), systemImage: "fork.knife")
                                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Palette.cardAlt))
                            }
                        }
                    }
                }
                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func factRow<V: View>(_ title: String, @ViewBuilder _ value: () -> V) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
            Spacer()
            value()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

/// Where a wine comes from: the whole country, with only its appellation (or the region holding it) highlighted;
/// everything else stays a quiet outline. Tap to open the zoomable map on the appellation itself.
struct WineLocationMap: View {
    let region: Region
    @State private var explore = false

    var body: some View {
        let lib = ContentStore.shared.library
        let r = region
        let own = Set(r.highlight ?? [r.id])
        let countryMap = lib.regions.first { $0.kind == "country" && $0.country == r.country }?.map
        // the country map shows the appellation itself, or failing that the nearest region that contains it
        let shown: (String, Set<String>)? = {
            guard let cm = countryMap, let g = MapGeometry.get(cm) else { return r.map.map { ($0, own) } }
            let ids = Set(g.areas.map(\.id))
            if !own.intersection(ids).isEmpty { return (cm, own.intersection(ids)) }
            var cur = r.id
            for _ in 0..<4 {
                guard let parent = lib.regions.first(where: { $0.kind != "country" && ($0.sub ?? []).contains(cur) }) else { break }
                if ids.contains(parent.id) { return (cm, [parent.id]) }
                cur = parent.id
            }
            return r.map.map { ($0, own) }
        }()
        if let (mapID, hl) = shown {
            ZStack(alignment: .bottomTrailing) {
                WineMapView(mapID: mapID, highlight: hl, showCities: true, labelScale: 0.85, fill: true,
                            thumbnail: true, focusOnly: true)
                    .frame(height: 220)
                    .allowsHitTesting(false)
                if r.map != nil {
                    Label("Zoom in", systemImage: "plus.magnifyingglass").font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.wine)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.card.opacity(0.92)))
                        .padding(10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if r.map != nil { explore = true } }
            .fullScreenCover(isPresented: $explore) {
                if let m = r.map { MapExplorer(mapID: m, highlight: own) }
            }
        }
    }
}
