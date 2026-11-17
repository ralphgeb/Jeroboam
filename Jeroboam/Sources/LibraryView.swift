import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case grapes, regions, aromas, colors, styles, tasting, pairing, glossary, bottles
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
        }
    }
}

struct LibraryView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Library")
                        Text("The wine atlas").font(.serif(34)).foregroundStyle(Palette.ink)
                        Text("Every grape, place, aroma and term you meet in the lessons, in one place.")
                            .font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                    }
                    .padding(.top, 20)

                    NavigationLink(value: LibrarySection.grapes) { featureGrapes }
                        .buttonStyle(PressableStyle()).padding(.top, 24)

                    NavigationLink(value: LibrarySection.regions) { featureRegions }
                        .buttonStyle(PressableStyle()).padding(.top, 14)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach([LibrarySection.aromas, .colors, .styles, .tasting, .pairing, .bottles], id: \.self) { s in
                            NavigationLink(value: s) { tile(s) }.buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.top, 14)

                    NavigationLink(value: LibrarySection.glossary) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Glossary").font(.serif(20)).foregroundStyle(Palette.ink)
                                Text(LibrarySection.glossary.subtitle).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            Text("A–Z").font(.serif(26, .light)).foregroundStyle(Palette.wine.opacity(0.6))
                        }
                        .cardStyle(padding: 18)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 12)
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, Metrics.margin)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibrarySection.self) { s in destination(s) }
            .navigationDestination(for: Grape.self) { g in GrapeDetailView(grape: g) }
            .navigationDestination(for: Region.self) { r in RegionDetailView(region: r) }
            .navigationDestination(for: WineStyle.self) { s in StyleDetailView(style: s) }
            .onAppear {
                #if DEBUG
                DebugScreens.libraryHook { path.append($0) }
                #endif
            }
        }
    }

    @ViewBuilder private func destination(_ s: LibrarySection) -> some View {
        switch s {
        case .grapes: GrapeListView()
        case .regions: RegionListView()
        case .aromas: AromaWheelScreen()
        case .colors: ColorsScreen()
        case .styles: StylesScreen()
        case .tasting: TastingScreen()
        case .pairing: PairingScreen()
        case .glossary: GlossaryScreen()
        case .bottles: BottlesScreen()
        }
    }

    private var featureGrapes: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Ampelography", color: Palette.wine)
                Text("Grapes").font(.serif(28)).foregroundStyle(Palette.ink)
                Text(LibrarySection.grapes.subtitle).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            HStack(spacing: -26) {
                GrapeCluster(berry: .white, leaf: false, seed: 2).frame(width: 76, height: 76)
                GrapeCluster(berry: .pink, leaf: false, seed: 5).frame(width: 76, height: 76)
                GrapeCluster(berry: .black, leaf: true, seed: 9).frame(width: 86, height: 86)
            }
        }
        .cardStyle(padding: 20)
    }

    private var featureRegions: some View {
        VStack(alignment: .leading, spacing: 14) {
            WineMapView(mapID: "world", showLabels: false, showCities: false)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Atlas", color: Palette.wine)
                    Text("Regions & maps").font(.serif(24)).foregroundStyle(Palette.ink)
                }
                Spacer()
                Text(LibrarySection.regions.subtitle).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            }
        }
        .cardStyle(padding: 16)
    }

    private func tile(_ s: LibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                switch s {
                case .aromas: AromaWheelMini().frame(width: 58, height: 58)
                case .colors:
                    HStack(spacing: -6) {
                        WineGlass(color: Color(hex: "#E3D48A"), fill: 0.5).frame(height: 56)
                        WineGlass(color: Color(hex: "#E8A3A0"), fill: 0.5).frame(height: 56)
                        WineGlass(color: Color(hex: "#6E1630"), fill: 0.5).frame(height: 56)
                    }
                case .styles: WineGlass(color: Color(hex: "#EADFA6"), fill: 0.75, sparkling: true).frame(height: 58)
                case .tasting: Image(systemName: "eye").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.wine).frame(height: 58)
                case .pairing: Image(systemName: "fork.knife").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.wine).frame(height: 58)
                case .bottles:
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach([26.0, 36.0, 46.0, 56.0], id: \.self) { h in
                            BottleShape().fill(h == 46 ? Palette.wine : Palette.ink.opacity(0.75)).frame(width: h * 0.32, height: h)
                        }
                    }
                    .frame(height: 58, alignment: .bottom)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(s.subtitle).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }
}

// MARK: - Shared screen scaffold

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(eyebrow)
            Text(title).font(.serif(32)).foregroundStyle(Palette.ink)
            if let s = subtitle {
                Text(rich(s)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.serif(21, .medium)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
