import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case grapes, regions, wines, great, aromas, colors, styles, tasting, pairing, glossary, bottles, cards, boldness, labels, guide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grapes: return "Grapes"
        case .regions: return "Regions & maps"
        case .wines: return "Wines of the world"
        case .great: return "Great wines to try"
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
        case .wines: return "\(lib.wines?.count ?? 0) classics"
        case .great: return "\((lib.great?.count ?? 0).formatted()) wines, region by region"
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
    @Environment(\.isWide) private var isWide

    var body: some View {
        NavigationStack(path: $path) {
            CollapsingPage(eyebrow: "Library", title: "Atlas", subtitle: "Every grape, place, aroma and term from the lessons.") {
                if isWide {
                    // wide: the groups sit side by side, each one a tidy block of two-up tiles
                    HStack(alignment: .top, spacing: 28) {
                        tileSection("Explore", [.regions, .great, .wines, .grapes, .labels, .cards], columns: 2)
                        VStack(alignment: .leading, spacing: 22) {
                            tileSection("Taste", [.aromas, .colors, .tasting, .boldness], columns: 2)
                            tileSection("Serve", [.guide, .styles, .pairing, .bottles], columns: 2)
                            glossaryLink
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.bottom, 12)
                } else {
                    tileSection("Explore", [.regions, .great, .wines, .grapes, .labels, .cards])
                    tileSection("Taste", [.aromas, .colors, .tasting, .boldness])
                    tileSection("Serve", [.guide, .styles, .pairing, .bottles])
                    glossaryLink
                    Color.clear.frame(height: 12)
                }
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .background(NavCapture(tab: 2))
            .navigationDestination(for: LibrarySection.self) { s in destination(s).zoomDestination(ZoomID.section(s.rawValue), in: zoom) }
            .navigationDestination(for: Grape.self) { g in PlusGate(quota: "grapes", id: g.id) { GrapeDetailView(grape: g) }.zoomDestination(ZoomID.grape(g.id), in: zoom) }
            .navigationDestination(for: Region.self) { r in PlusGate(country: r.gateCountry, reason: "Every country and appellation comes with Jero Plus.") { RegionDetailView(region: r) }.zoomDestination(ZoomID.region(r.id), in: zoom) }
            .navigationDestination(for: Wine.self) { w in PlusGate(quota: "wines", id: w.id) { WineDetailView(wine: w) } }
            .navigationDestination(for: GreatWine.self) { w in PlusGate(quota: "great", id: w.id) { GreatWinePager(wine: w) } }
            .navigationDestination(for: WineStyle.self) { s in PlusGate(quota: "styles", id: s.id) { StyleDetailView(style: s) }.zoomDestination(ZoomID.style(s.id), in: zoom) }
            .debugDestinations()
            .onAppear {
                #if DEBUG
                DebugScreens.libraryHook { path.append($0) }
                #endif
            }
        }
        .environment(\.zoomNamespace, zoom)
    }

    private var glossaryLink: some View {
        link(.glossary) {
                        HStack(spacing: 14) {
                            Text("Aa").font(.jero(size: 20, weight: .semibold)).foregroundStyle(Palette.wine)
                                .frame(width: 44, height: 44).background(Circle().fill(Palette.wineSoft))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Glossary").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(LibrarySection.glossary.subtitle).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                        }
                        .cardStyle(padding: 14)
                    }
    }

    private func link<V: View>(_ s: LibrarySection, @ViewBuilder _ label: () -> V) -> some View {
        NavigationLink(value: s) { label().zoomSource(ZoomID.section(s.rawValue)) }.buttonStyle(PressableStyle())
    }

    private func tileSection(_ title: String, _ items: [LibrarySection], columns: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            LazyVGrid(columns: columns.map { n in Array(repeating: GridItem(.flexible(), spacing: 12), count: n) } ?? [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.self) { s in link(s) { tile(s) } }
            }
        }
    }

    @ViewBuilder private func destination(_ s: LibrarySection) -> some View {
        switch s {
        case .grapes: GrapeListView()
        case .regions: RegionListView()
        case .wines: WinesScreen()
        case .great: GreatWinesScreen()
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
                .scaleEffect(1.05)
                .frame(width: 60, height: 60)
            Spacer(minLength: 8)
            Text(s.title).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.85)
            Text(s.subtitle).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1).padding(.top, 1)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .cardStyle(padding: 12)
    }

    /// Small illustration for each tile, all drawn on the same disc.
    @ViewBuilder private func art(_ s: LibrarySection) -> some View {
        ZStack {
            Circle().fill(Palette.wineSoft.opacity(0.7)).frame(width: 56, height: 56)
            switch s {
            case .regions:
                Image(systemName: "globe.europe.africa").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.wine)
            case .great:
                WineStamp().frame(width: 44, height: 50)
            case .wines:
                HStack(alignment: .bottom, spacing: -3) {
                    WineGlass(color: Color(hex: "#E3CF7A"), fill: 0.55).frame(width: 15, height: 28)
                    WineGlass(color: Color(hex: "#7A1832"), fill: 0.55).frame(width: 19, height: 34)
                }
            case .grapes:
                GrapeArt(id: "cabernet-sauvignon", size: 48)
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
            case .glossary: Text("Aa").font(.jero(size: 18, weight: .semibold)).foregroundStyle(Palette.wine)
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
                                        Text(c.name).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(c.note).font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
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
        .pageChrome()
    }
}

// MARK: - Styles

struct StylesScreen: View {
    var body: some View {
        let styles = ContentStore.shared.library.styles
        let cats = styles.reduce(into: [String]()) { if !$0.contains($1.category) { $0.append($1.category) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: "Styles", title: "Wine styles", subtitle: "Still, sparkling, sweet and fortified. Tap a style to see how it is made and which wines to try.")
                ForEach(cats, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: cat)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            ForEach(styles.filter { $0.category == cat }) { st in
                                DetailLink(value: st) { StyleTile(style: st) }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
        .toolbar { QuotaToolbar(section: "styles") }
        .detailPane(first: styles.first.map { AnyHashable($0) })
    }
}

struct StyleTile: View {
    let style: WineStyle
    var body: some View {
        let count = (ContentStore.shared.library.wines ?? []).filter { $0.style == style.id }.count
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                StyleTile.tint(style).opacity(0.14)
                SilhouetteGlass(shape: StyleTile.shape(style), color: StyleTile.tint(style), fill: 0.55,
                                sparkling: style.category.hasPrefix("Sparkling"))
                    .frame(height: 70)
            }
            .frame(height: 96)
            VStack(alignment: .leading, spacing: 3) {
                Text(style.name).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(count > 0 ? "\(count) wines to try" : style.summary).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            .padding(12)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    }

    static func tint(_ s: WineStyle) -> Color {
        if let v = s.visual, v.hasPrefix("glass:"), let c = ContentStore.shared.library.colors.first(where: { $0.id == String(v.dropFirst(6)) }) {
            return Color(hex: c.hex)
        }
        switch s.id {
        case let id where id.contains("rose"): return Color(hex: "#EE9AA8")
        case let id where id.contains("red") || id.contains("port-ruby"): return Color(hex: "#7A1832")
        case let id where id.contains("tawny") || id.contains("madeira") || id.contains("oxidative"): return Color(hex: "#A0602A")
        case let id where id.contains("sweet") || id.contains("icewine") || id.contains("vdn") || id.contains("asti"): return Color(hex: "#D9A23B")
        default: return Color(hex: "#E3D48A")
        }
    }
    static func shape(_ s: WineStyle) -> GlassArt.Shape {
        if s.category.hasPrefix("Sparkling") { return .flute }
        if s.id.contains("red") { return .red }
        if s.category.hasPrefix("Fortified") || s.category.hasPrefix("Sweet") { return .tasting }
        return .white
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
                    Text(rich(style.how)).font(.jero(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                }
                if let t = style.taste {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "In the glass")
                        Text(rich(t)).font(.jero(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                    }
                }
                let wines = (ContentStore.shared.library.wines ?? []).filter { $0.style == style.id }
                if !wines.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Wines to try")
                        GroupCard {
                            ForEach(wines) { w in
                                NavigationLink(value: w) { WineRow(wine: w, last: w == wines.last) }
                                    .buttonStyle(RowPressStyle())
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: wines.isEmpty ? "Look for" : "Also look for")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(style.examples, id: \.self) { e in
                            Text(e).font(.jero(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(Palette.cardAlt))
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
    }
}

// MARK: - Tasting (SAT)

struct TastingScreen: View {
    @State private var open: TastingStep? = nil
    @Environment(\.isWide) private var isWide

    var body: some View {
        let secs = ContentStore.shared.library.sat
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: "Systematic approach", title: "How to taste",
                             subtitle: "Four steps, the same every time. Tap a step to learn what to look for.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isWide ? 4 : 2), spacing: 12) {
                    ForEach(Array(TastingStep.all.enumerated()), id: \.offset) { i, step in
                        Button { open = step } label: { TastingStepCard(step: step, number: i + 1) }
                            .buttonStyle(PressableStyle())
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Remember it as")
                    HStack(spacing: 8) {
                        ForEach(["Look", "Smell", "Taste", "Conclude"], id: \.self) { w in
                            VStack(spacing: 2) {
                                Text(String(w.prefix(1))).font(.jero(size: 26, weight: .bold)).foregroundStyle(Palette.wine)
                                Text(w).font(.jero(size: 11.5)).foregroundStyle(Palette.inkSoft)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                        }
                    }
                    Text("Write a word or two for each step and your notes become comparable from one bottle to the next.")
                        .font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
            .readable(720)
        }
        .background(Palette.paper.ignoresSafeArea())
        .halfPage()
        .pageChrome()
        .sheet(item: $open) { step in
            TastingStepSheet(step: step, section: secs.first { $0.title == step.satTitle })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            #if DEBUG
            if DebugScreens.screen == "tastestep" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { open = TastingStep.all[1] } }
            #endif
        }
    }
}

struct TastingStep: Identifiable, Hashable {
    let id: String
    let title: String
    let satTitle: String
    let icon: String
    let line: String
    let how: [String]
    let tint: String

    static let all: [TastingStep] = [
        TastingStep(id: "look", title: "Look", satTitle: "Appearance", icon: "eye", line: "Clarity, depth and color",
                    how: ["Tilt the glass over something white.", "Check it is clear, then judge how deep the color is at the core.",
                          "Read the rim: wines turn paler and browner there first as they age."], tint: "#C9A227"),
        TastingStep(id: "smell", title: "Smell", satTitle: "Nose", icon: "nose", line: "Condition, intensity, aromas",
                    how: ["Sniff once before swirling, then swirl to release more aroma.", "Take short sniffs: is it clean, light or pronounced?",
                          "Work through families: fruit, flowers, herbs, spice, then oak and age."], tint: "#D8285A"),
        TastingStep(id: "taste", title: "Taste", satTitle: "Palate", icon: "mouth", line: "Sweetness, acid, tannin, body",
                    how: ["Take a medium sip and move it around your whole mouth.", "Sweetness on the tip, acidity on the sides, tannin on the gums.",
                          "Feel the alcohol's warmth and the body's weight, then time the finish."], tint: "#8B1538"),
        TastingStep(id: "conclude", title: "Conclude", satTitle: "Conclusions", icon: "checkmark.seal", line: "Quality and readiness",
                    how: ["Use BLIC: Balance, Length, Intensity, Complexity.", "The more boxes ticked, the higher the quality.",
                          "Decide whether it will improve with age or is best now."], tint: "#2E9C97"),
    ]
}

struct TastingStepCard: View {
    let step: TastingStep
    let number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle().fill(Color(hex: step.tint).opacity(0.12))
                illustration
            }
            .frame(width: 64, height: 64)
            Spacer(minLength: 14)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number)").font(.jero(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Color(hex: step.tint))
                Text(step.title).font(.jero(size: 18, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            Text(step.line).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(2, reservesSpace: true).padding(.top, 2)
            HStack(spacing: 4) {
                Text("Learn").font(.jero(size: 12.5, weight: .semibold))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Palette.wine).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 186, alignment: .topLeading)
        .cardStyle(padding: 14)
    }

    @ViewBuilder private var illustration: some View {
        switch step.id {
        case "look":
            WineGlass(color: Color(hex: "#E3C766"), fill: 0.5).frame(width: 26, height: 44).rotationEffect(.degrees(-28))
        case "smell":
            ZStack {
                WineGlass(color: Color(hex: "#7A1832"), fill: 0.4).frame(width: 24, height: 40).offset(y: 6)
                Image(systemName: "wind").font(.system(size: 14, weight: .medium)).foregroundStyle(Color(hex: step.tint)).offset(x: 6, y: -18)
            }
        case "taste":
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([10.0, 18.0, 26.0, 14.0, 22.0], id: \.self) { h in
                    Capsule().fill(Color(hex: step.tint).opacity(0.35 + h / 60)).frame(width: 5, height: h)
                }
            }
        default:
            Image(systemName: step.icon).font(.system(size: 26, weight: .regular)).foregroundStyle(Color(hex: step.tint))
        }
    }
}

struct TastingStepSheet: View {
    let step: TastingStep
    let section: SATSection?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: step.icon).font(.system(size: 20)).foregroundStyle(Color(hex: step.tint))
                        .frame(width: 46, height: 46).background(Circle().fill(Color(hex: step.tint).opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow("Step \((TastingStep.all.firstIndex(of: step) ?? 0) + 1) of 4")
                        Text(step.title).font(.jero(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                }
                PhotoView(id: "taste-" + step.id, height: 200)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(step.how.enumerated()), id: \.offset) { i, t in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").font(.jero(size: 12, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 22, height: 22).background(Circle().fill(Color(hex: step.tint)))
                            Text(t).font(.jero(size: 15)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .cardStyle(padding: 16)
                if let section {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "What to note")
                        Text("Tap a level to see what it means.").font(.jero(size: 13)).foregroundStyle(Palette.inkSoft)
                        ForEach(section.items, id: \.name) { item in SATScaleRow(item: item, tint: Color(hex: step.tint)) }
                    }
                }
            }
            .padding(Metrics.margin).padding(.top, 8)
        }
        .background(Palette.paper.ignoresSafeArea())
    }
}

struct SATScaleRow: View {
    let item: SATItem
    let tint: Color
    @State private var picked: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
            HStack(spacing: 4) {
                ForEach(Array(item.scale.enumerated()), id: \.offset) { i, s in
                    let on = picked == i
                    Button { withAnimation(.snappy) { picked = on ? nil : i } } label: {
                        Text(s).font(.jero(size: 11, weight: on ? .semibold : .medium))
                            .foregroundStyle(on ? .white : Palette.ink.opacity(0.8))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.vertical, 8).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(on ? tint : tint.opacity(0.06 + 0.14 * Double(i) / Double(max(1, item.scale.count - 1)))))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(rich(item.tip)).font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
    }
}

// MARK: - Pairing

struct PairingScreen: View {
    @State private var open: Pairing? = nil
    @State private var dish = "Red meat"
    private let dishes: [(String, String, [String])] = [
        ("Red meat", "flame", ["steak", "ribeye", "beef", "asado", "lamb", "game", "venison"]),
        ("Chicken", "bird", ["chicken", "turkey", "pork"]),
        ("Fish", "fish", ["salmon", "trout", "fish", "sushi"]),
        ("Shellfish", "drop", ["oyster", "shellfish", "seafood", "lobster", "prawn", "scallop"]),
        ("Pasta & pizza", "circle.dashed", ["pizza", "pasta", "ragù", "risotto"]),
        ("Spicy", "flame.fill", ["spicy", "curr", "thai", "asian"]),
        ("Cheese", "square.grid.3x3", ["cheese", "comté", "stilton", "manchego", "parmesan"]),
        ("Dessert", "birthday.cake", ["dessert", "tart", "chocolate", "crème brûlée", "foie gras"]),
    ]

    var body: some View {
        let lib = ContentStore.shared.library
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(eyebrow: "Food & wine", title: "Pairing made simple",
                             subtitle: "Pick a dish to see what to pour, then learn the few effects that make a match work.")
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Pick your dish")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                        ForEach(dishes, id: \.0) { d in
                            let on = dish == d.0
                            Button { withAnimation(.snappy) { dish = d.0 } } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: d.1).font(.system(size: 19))
                                        .foregroundStyle(on ? Palette.onWine : Palette.wine)
                                        .frame(width: 54, height: 54)
                                        .background(Circle().fill(on ? Palette.wine : Palette.wineSoft.opacity(0.7)))
                                    Text(d.0).font(.jero(size: 12, weight: on ? .semibold : .regular))
                                        .foregroundStyle(on ? Palette.ink : Palette.inkSoft)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    let keys = dishes.first { $0.0 == dish }?.2 ?? []
                    let matches = Array((lib.wines ?? []).filter { w in w.food.contains { f in keys.contains { f.lowercased().contains($0) } } }.prefix(5))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("With \(dish.lowercased()), try").font(.jero(size: 14, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                            .padding(.top, 4)
                        if matches.isEmpty {
                            Text("No classic match in the catalog yet.").font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
                        } else {
                            GroupCard {
                                ForEach(matches) { w in
                                    NavigationLink(value: w) { WineRow(wine: w, last: w == matches.last) }.buttonStyle(RowPressStyle())
                                }
                            }
                            .id(dish)
                            .transition(.opacity)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "What food does to wine")
                    GroupCard {
                        ForEach(Array(lib.pairings.enumerated()), id: \.element.id) { i, p in
                            Button { open = p } label: {
                                IconRow(title: p.food, detail: headline(p.effect), last: i == lib.pairings.count - 1) {
                                    Image(systemName: p.icon).font(.system(size: 17)).foregroundStyle(Palette.wine)
                                }
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
            .readable(720)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .halfPage()
        .pageChrome()
        .sheet(item: $open) { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: p.icon).font(.system(size: 22)).foregroundStyle(Palette.wine)
                            .frame(width: 52, height: 52).background(Circle().fill(Palette.wineSoft))
                        Text(p.food).font(.jero(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("What it does")
                        Text(rich(p.effect)).font(.jero(size: 16)).foregroundStyle(Palette.ink).lineSpacing(3)
                    }
                    .cardStyle(padding: 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("What to pour")
                        Text(rich(p.tip)).font(.jero(size: 16)).foregroundStyle(Palette.ink).lineSpacing(3)
                    }
                    .cardStyle(padding: 16)
                }
                .padding(Metrics.margin).padding(.top, 10)
            }
            .background(Palette.paper.ignoresSafeArea())
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func headline(_ effect: String) -> String {
        effect.replacingOccurrences(of: "**", with: "")
    }
}

// MARK: - Glossary

struct GlossaryScreen: View {
    @State private var query = ""
    var body: some View {
        let terms = ContentStore.shared.library.glossary
            .filter { Search.matches(query, $0.term, $0.def) }
            .sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        let letters = terms.reduce(into: [String]()) { acc, t in
            let l = String(t.term.folding(options: .diacriticInsensitive, locale: nil).prefix(1)).uppercased()
            if !acc.contains(l) { acc.append(l) }
        }
        VStack(spacing: 0) {
        SearchBar(text: $query, prompt: "Search terms").padding(.horizontal, 16).padding(.vertical, 10)
        List {
            ForEach(letters, id: \.self) { letter in
                Section {
                    ForEach(terms.filter { String($0.term.folding(options: .diacriticInsensitive, locale: nil).prefix(1)).uppercased() == letter }) { t in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.term).font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(rich(t.def)).font(.jero(size: 14.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
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
        }
        .background(Palette.paper.ignoresSafeArea())
        .halfPage()
        .navigationTitle("Glossary")
    }
}

// MARK: - Bottles

struct BottlesScreen: View {
    private struct Format: Identifiable {
        let name: String; let liters: Double; let bottles: String; let note: String
        var id: String { name }
    }
    private let formats: [Format] = [
        Format(name: "Piccolo", liters: 0.1875, bottles: "¼", note: "A single glass of fizz, the airline and minibar size."),
        Format(name: "Half bottle", liters: 0.375, bottles: "½", note: "Common for sweet wines like Sauternes and Tokaji."),
        Format(name: "Standard", liters: 0.75, bottles: "1", note: "Six glasses. The size almost every wine is made in."),
        Format(name: "Magnum", liters: 1.5, bottles: "2", note: "Collectors' favorite: ages more slowly and gracefully."),
        Format(name: "Jeroboam", liters: 3, bottles: "4", note: "A king of Israel, and this app's namesake. 4.5 L in Bordeaux."),
        Format(name: "Rehoboam", liters: 4.5, bottles: "6", note: "Son of Solomon. Mostly Champagne."),
        Format(name: "Methuselah", liters: 6, bottles: "8", note: "The longest-lived man in the Bible. Called Imperial in Bordeaux."),
        Format(name: "Salmanazar", liters: 9, bottles: "12", note: "An Assyrian king. A whole case in one bottle."),
        Format(name: "Balthazar", liters: 12, bottles: "16", note: "One of the three wise men."),
        Format(name: "Nebuchadnezzar", liters: 15, bottles: "20", note: "King of Babylon. Takes two people to pour."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(eyebrow: "Formats", title: "Bottle sizes",
                             subtitle: "Big bottles age more slowly: there is less air per drop of wine. Most are named after Biblical kings.")
                    .padding(.bottom, 8)
                ForEach(formats) { f in row(f) }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
            .readable(720)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .halfPage()
        .pageChrome()
    }

    private func row(_ f: Format) -> some View {
        let isJ = f.name == "Jeroboam"
        // height grows with the cube root of the volume, like real bottles
        let h = 30 + 70 * (pow(f.liters / 15, 1.0 / 3) - pow(0.1875 / 15, 1.0 / 3)) / (1 - pow(0.1875 / 15, 1.0 / 3))
        return HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .bottom) {
                Color.clear.frame(width: 54, height: 104)
                BottleShape().fill(isJ ? Palette.bordeaux : Palette.ink.opacity(0.82))
                    .frame(width: h * 0.34, height: h)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(f.name).font(.jero(size: 17, weight: .semibold)).foregroundStyle(isJ ? Palette.wine : Palette.ink)
                    Text(f.liters < 1 ? String(format: "%.0f cl", f.liters * 100) : String(format: f.liters == floor(f.liters) ? "%.0f L" : "%.1f L", f.liters))
                        .font(.system(size: 13, weight: .medium).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                }
                Text(f.note).font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                Text("= \(f.bottles) standard bottle\(f.bottles == "1" || f.bottles.contains("¼") || f.bottles.contains("½") ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.wine)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Palette.wineSoft))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(isJ ? Palette.wine.opacity(0.5) : Palette.line.opacity(0.6), lineWidth: isJ ? 1.2 : 0.5))
    }
}


/// A postage stamp with a heart on it: the mark for "Great wines to try".
struct StampShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 1.5)
        // perforations: small half-circles cut out along the four edges
        let step: CGFloat = r.width / 7
        let d: CGFloat = step * 0.46
        var cuts = Path()
        var x = step / 2
        while x < r.width {
            cuts.addEllipse(in: CGRect(x: r.minX + x - d / 2, y: r.minY - d / 2, width: d, height: d))
            cuts.addEllipse(in: CGRect(x: r.minX + x - d / 2, y: r.maxY - d / 2, width: d, height: d))
            x += step
        }
        let stepY = r.height / 8
        var y = stepY / 2
        while y < r.height {
            cuts.addEllipse(in: CGRect(x: r.minX - d / 2, y: r.minY + y - d / 2, width: d, height: d))
            cuts.addEllipse(in: CGRect(x: r.maxX - d / 2, y: r.minY + y - d / 2, width: d, height: d))
            y += stepY
        }
        p = p.subtracting(cuts)
        return p
    }
}

struct WineStamp: View {
    var body: some View {
        ZStack {
            StampShape().fill(Color(hex: "#FBF3E4"))
            StampShape().stroke(Palette.bordeaux.opacity(0.35), lineWidth: 0.6)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .strokeBorder(Palette.bordeaux.opacity(0.55), lineWidth: 0.8)
                .padding(5)
            VStack(spacing: 1) {
                Image(systemName: "heart.fill").font(.system(size: 17)).foregroundStyle(Palette.bordeaux)
                Text("TRY").font(.system(size: 6.5, weight: .heavy)).kerning(1.2).foregroundStyle(Palette.bordeaux)
            }
        }
        .rotationEffect(.degrees(-5))
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
    }
}
