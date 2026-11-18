import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case grapes, regions, aromas, colors, styles, tasting, pairing, glossary, bottles, cards, boldness, labels, guide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grapes: return "Grapes"
        case .regions: return "Regions & maps"
        case .aromas: return "Aroma wheel"
        case .colors: return "Wine colors"
        case .styles: return "Wine styles"
        case .tasting: return "How to taste"
        case .pairing: return "Food & wine"
        case .glossary: return "Glossary"
        case .bottles: return "Bottle sizes"
        case .cards: return "Wine cards"
        case .boldness: return "Boldness scale"
        case .labels: return "Label decoder"
        case .guide: return "Style guide"
        }
    }
    var subtitle: String {
        let lib = ContentStore.shared.library
        switch self {
        case .grapes: return "\(lib.grapes.count) varieties"
        case .regions: return "\(lib.regions.count) places"
        case .aromas: return "\(ContentStore.shared.allAromaCategories().reduce(0) { $0 + $1.items.count }) descriptors"
        case .colors: return "White, rosé, red"
        case .styles: return "\(lib.styles.count) styles"
        case .tasting: return "The systematic approach"
        case .pairing: return "Principles that work"
        case .glossary: return "\(lib.glossary.count) terms"
        case .bottles: return "Piccolo to Nebuchadnezzar"
        case .cards: return "\(lib.grapes.count) varieties to swipe"
        case .boldness: return "Light to bold, red and white"
        case .labels: return "\(lib.labels?.count ?? 0) regions explained"
        case .guide: return "Glasses, temps & food"
        }
    }
}

struct LibraryView: View {
    @State private var path = NavigationPath()
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ScreenHeader(eyebrow: "Library", title: "Atlas",
                                 subtitle: "Every grape, place, aroma and term from the lessons.")
                    tileSection("Explore", [.regions, .grapes, .cards, .labels])
                    tileSection("Taste", [.aromas, .colors, .tasting, .boldness])
                    tileSection("Serve", [.guide, .styles, .pairing, .bottles])
                    link(.glossary) {
                        HStack(spacing: 14) {
                            Text("Aa").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.wine)
                                .frame(width: 44, height: 44).background(Circle().fill(Palette.wineSoft))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Glossary").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(LibrarySection.glossary.subtitle).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                        }
                        .cardStyle(padding: 14)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, Metrics.margin)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibrarySection.self) { s in destination(s).zoomDestination(ZoomID.section(s.rawValue), in: zoom) }
            .navigationDestination(for: Grape.self) { g in GrapeDetailView(grape: g).zoomDestination(ZoomID.grape(g.id), in: zoom) }
            .navigationDestination(for: Region.self) { r in RegionDetailView(region: r).zoomDestination(ZoomID.region(r.id), in: zoom) }
            .navigationDestination(for: WineStyle.self) { s in StyleDetailView(style: s).zoomDestination(ZoomID.style(s.id), in: zoom) }
            .debugDestinations()
            .onAppear {
                #if DEBUG
                DebugScreens.libraryHook { path.append($0) }
                #endif
            }
        }
        .environment(\.zoomNamespace, zoom)
    }

    private func link<V: View>(_ s: LibrarySection, @ViewBuilder _ label: () -> V) -> some View {
        NavigationLink(value: s) { label().zoomSource(ZoomID.section(s.rawValue)) }.buttonStyle(PressableStyle())
    }

    private func tileSection(_ title: String, _ items: [LibrarySection]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.self) { s in link(s) { tile(s) } }
            }
        }
    }

    @ViewBuilder private func destination(_ s: LibrarySection) -> some View {
        switch s {
        case .grapes: GrapeListView()
        case .regions: RegionListView()
        case .aromas: AromaWheelScreen()
        case .colors: ColorChartScreen()
        case .styles: StylesScreen()
        case .tasting: TastingScreen()
        case .pairing: PairingScreen()
        case .glossary: GlossaryScreen()
        case .bottles: BottlesScreen()
        case .cards: WineCardsScreen()
        case .boldness: BoldnessScreen()
        case .labels: LabelsScreen()
        case .guide: StyleGuideScreen()
        }
    }

    private func tile(_ s: LibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            art(s)
                .frame(width: 56, height: 56)
            Spacer(minLength: 12)
            Text(s.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.85)
            Text(s.subtitle).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .cardStyle(padding: 14)
    }

    /// Small illustration for each tile, all drawn on the same 56-pt disc.
    @ViewBuilder private func art(_ s: LibrarySection) -> some View {
        ZStack {
            Circle().fill(Palette.wineSoft.opacity(0.7))
            switch s {
            case .regions:
                WineMapView(mapID: "italy", showLabels: false, showCities: false, fill: true)
                    .clipShape(Circle()).allowsHitTesting(false)
            case .grapes:
                GrapeCluster(berry: .black, seed: 3).frame(width: 46, height: 46)
            case .cards:
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill([Color(hex: "#E9DDB0"), Color(hex: "#D98A9E"), Palette.bordeaux][i])
                            .frame(width: 18, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 0.75))
                            .rotationEffect(.degrees(Double(i - 1) * 14), anchor: .bottom)
                            .offset(x: CGFloat(i - 1) * 6)
                    }
                }
            case .labels:
                VStack(spacing: 2) {
                    Rectangle().fill(Palette.bordeaux).frame(width: 18, height: 1.5)
                    Text("Château").font(.system(size: 7.5, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
                    Text("1855").font(.system(size: 6, weight: .bold)).foregroundStyle(Palette.bordeaux)
                }
                .padding(.horizontal, 5).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#FBF6EC")))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.bordeaux.opacity(0.5), lineWidth: 0.5))
            case .aromas: AromaWheelMini().frame(width: 44, height: 44)
            case .colors:
                HStack(spacing: 2) {
                    ForEach(["#E6D68C", "#E9A6A2", "#7A1832"], id: \.self) { Rectangle().fill(Color(hex: $0)).frame(width: 8, height: 22) }
                }
            case .tasting: WineGlass(color: Color(hex: "#8E1E3F"), fill: 0.45).frame(width: 22, height: 36)
            case .boldness:
                Capsule().fill(LinearGradient(colors: ["#F0A39A", "#C8284D", "#4A0A24"].map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing))
                    .frame(width: 32, height: 6)
            case .guide:
                HStack(alignment: .bottom, spacing: 1) {
                    WineGlass(color: Color(hex: "#EDE6B8"), fill: 0.7, sparkling: true).frame(width: 9, height: 28)
                    WineGlass(color: Color(hex: "#E3BE55"), fill: 0.5).frame(width: 13, height: 26)
                    WineGlass(color: Color(hex: "#4E0F27"), fill: 0.45).frame(width: 16, height: 28)
                }
            case .styles: WineGlass(color: Color(hex: "#EADFA6"), fill: 0.75, sparkling: true).frame(width: 18, height: 36)
            case .pairing: Image(systemName: "fork.knife").font(.system(size: 19)).foregroundStyle(Palette.wine)
            case .bottles:
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach([14.0, 20.0, 26.0], id: \.self) { h in BottleShape().fill(Palette.wine).frame(width: h * 0.34, height: h) }
                }
            case .glossary: Text("Aa").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.wine)
            }
        }
    }
}

/// Row highlight on press (for rows inside grouped cards).
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Palette.ink.opacity(configuration.isPressed ? 0.05 : 0))
    }
}

// MARK: - Shared screen scaffold

// MARK: - Colors

struct ColorsScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                ScreenHeader(eyebrow: "Appearance", title: "Wine colors",
                             subtitle: "Tilt the glass over something white and look at the core and the rim. Color hints at grape, age and winemaking: whites deepen toward gold and amber, reds fade from purple to garnet and tawny.")
                ForEach([("white", "White"), ("rose", "Rosé"), ("red", "Red")], id: \.0) { fam in
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(text: fam.1)
                        ColorLadder(family: fam.0)
                        VStack(spacing: 0) {
                            ForEach(ContentStore.shared.library.colors.filter { $0.family == fam.0 }) { c in
                                HStack(alignment: .top, spacing: 14) {
                                    Circle().fill(Color(hex: c.hex)).frame(width: 16, height: 16)
                                        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.5)).padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(c.note).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 12)
                                Hairline()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Styles

struct StylesScreen: View {
    var body: some View {
        let styles = ContentStore.shared.library.styles
        let cats = styles.reduce(into: [String]()) { if !$0.contains($1.category) { $0.append($1.category) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(eyebrow: "Styles", title: "Wine styles", subtitle: "Still, sparkling, sweet and fortified: how each style is made and what to expect in the glass.")
                ForEach(cats, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: cat).padding(.bottom, 8)
                        ForEach(styles.filter { $0.category == cat }) { s in
                            NavigationLink(value: s) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(s.summary).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Hairline()
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StyleDetailView: View {
    let style: WineStyle
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: style.category, title: style.name, subtitle: style.summary)
                if let v = style.visual { VisualView(spec: v).cardStyle() }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "How it’s made")
                    Text(rich(style.how)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                }
                if let t = style.taste {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "In the glass")
                        Text(rich(t)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Look for")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(style.examples, id: \.self) { e in
                            Text(e).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(Palette.cardAlt))
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tasting (SAT)

struct TastingScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(eyebrow: "Systematic approach", title: "How to taste",
                             subtitle: "Look, smell, taste, conclude. The same four steps every time make your notes consistent and comparable, the way professional tasters work.")
                if let f = ContentStore.shared.flow("tasting") { FlowDiagram(flow: f).cardStyle() }
                ForEach(ContentStore.shared.library.sat) { sec in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: sec.icon).font(.system(size: 16)).foregroundStyle(Palette.wine)
                            SectionTitle(text: sec.title)
                        }
                        ForEach(sec.items, id: \.name) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                HStack(spacing: 4) {
                                    ForEach(Array(item.scale.enumerated()), id: \.offset) { i, s in
                                        Text(s).font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Palette.ink.opacity(0.8))
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                            .padding(.vertical, 6).frame(maxWidth: .infinity)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Palette.wine.opacity(0.06 + 0.1 * Double(i) / Double(max(1, item.scale.count - 1)))))
                                    }
                                }
                                Text(rich(item.tip)).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Hairline()
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pairing

struct PairingScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: "Food & wine", title: "Pairing principles",
                             subtitle: "Food changes how wine tastes. Learn the few interactions that matter and pairing stops being guesswork.")
                ForEach(ContentStore.shared.library.pairings) { p in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: p.icon).font(.system(size: 17)).foregroundStyle(Palette.wine)
                            .frame(width: 40, height: 40).background(Circle().fill(Palette.wineSoft))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(p.food).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(rich(p.effect)).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.85)).lineSpacing(2.5)
                            Text(rich(p.tip)).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                        }
                    }
                    Hairline()
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Glossary

struct GlossaryScreen: View {
    @State private var query = ""
    var body: some View {
        let terms = ContentStore.shared.library.glossary
            .filter { query.isEmpty || $0.term.localizedCaseInsensitiveContains(query) || $0.def.localizedCaseInsensitiveContains(query) }
            .sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        let letters = terms.reduce(into: [String]()) { acc, t in
            let l = String(t.term.folding(options: .diacriticInsensitive, locale: nil).prefix(1)).uppercased()
            if !acc.contains(l) { acc.append(l) }
        }
        List {
            ForEach(letters, id: \.self) { letter in
                Section {
                    ForEach(terms.filter { String($0.term.folding(options: .diacriticInsensitive, locale: nil).prefix(1)).uppercased() == letter }) { t in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.term).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(rich(t.def)).font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Palette.card)
                    }
                } header: {
                    Text(letter).font(.serif(18)).foregroundStyle(Palette.wine)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("Glossary")
        .searchable(text: $query, prompt: "Search terms")
    }
}

// MARK: - Bottles

struct BottlesScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: "Formats", title: "Bottle sizes",
                             subtitle: "Large formats age more slowly because there is less oxygen per drop of wine. Most are named after Biblical kings; a **Jeroboam** holds 3 litres in Champagne and Burgundy (4.5 litres in Bordeaux).")
                BottleSizesDiagram().cardStyle()
                VStack(spacing: 0) {
                    ForEach(rows, id: \.0) { r in
                        HStack {
                            Text(r.0).font(.system(size: 15, weight: r.0 == "Jeroboam" ? .semibold : .regular))
                                .foregroundStyle(r.0 == "Jeroboam" ? Palette.wine : Palette.ink)
                            Spacer()
                            Text(r.1).font(.numeric(14, .regular)).foregroundStyle(Palette.inkSoft)
                            Text(r.2).font(.numeric(14, .regular)).foregroundStyle(Palette.inkSoft).frame(width: 92, alignment: .trailing)
                        }
                        .padding(.vertical, 11)
                        Hairline()
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private let rows: [(String, String, String)] = [
        ("Piccolo / Split", "0.1875 L", "¼ bottle"), ("Demi / Half", "0.375 L", "½ bottle"), ("Standard", "0.75 L", "1 bottle"),
        ("Magnum", "1.5 L", "2 bottles"), ("Jeroboam", "3 L", "4 bottles"), ("Rehoboam", "4.5 L", "6 bottles"),
        ("Methuselah", "6 L", "8 bottles"), ("Salmanazar", "9 L", "12 bottles"), ("Balthazar", "12 L", "16 bottles"),
        ("Nebuchadnezzar", "15 L", "20 bottles")
    ]
}
