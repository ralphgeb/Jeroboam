import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case grapes, regions, wines, aromas, colors, styles, tasting, pairing, glossary, bottles, cards, boldness, labels, guide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grapes: return "Grapes"
        case .regions: return "Regions & maps"
        case .wines: return "Wines of the world"
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
            CollapsingPage(eyebrow: "Library", title: "Atlas", subtitle: "Every grape, place, aroma and term from the lessons.") {
                    tileSection("Explore", [.regions, .wines, .grapes, .labels])
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
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibrarySection.self) { s in destination(s).zoomDestination(ZoomID.section(s.rawValue), in: zoom) }
            .navigationDestination(for: Grape.self) { g in GrapeDetailView(grape: g).zoomDestination(ZoomID.grape(g.id), in: zoom) }
            .navigationDestination(for: Region.self) { r in RegionDetailView(region: r).zoomDestination(ZoomID.region(r.id), in: zoom) }
            .navigationDestination(for: Wine.self) { w in WineDetailView(wine: w) }
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
        case .wines: WinesScreen()
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
                WineMapView(mapID: "italy", showLabels: false, showCities: false, fill: true, thumbnail: true)
                    .clipShape(Circle()).allowsHitTesting(false)
            case .wines:
                HStack(alignment: .bottom, spacing: -3) {
                    WineGlass(color: Color(hex: "#E3CF7A"), fill: 0.55).frame(width: 15, height: 28)
                    WineGlass(color: Color(hex: "#7A1832"), fill: 0.55).frame(width: 19, height: 34)
                }
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
    @State private var open: TastingStep? = nil

    var body: some View {
        let secs = ContentStore.shared.library.sat
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: "Systematic approach", title: "How to taste",
                             subtitle: "Four steps, the same every time. Tap a step to learn what to look for.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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
                                Text(String(w.prefix(1))).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.wine)
                                Text(w).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
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
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
                Text("\(number)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Color(hex: step.tint))
                Text(step.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            Text(step.line).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(2, reservesSpace: true).padding(.top, 2)
            HStack(spacing: 4) {
                Text("Learn").font(.system(size: 12.5, weight: .semibold))
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
                        Text(step.title).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(step.how.enumerated()), id: \.offset) { i, t in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 22, height: 22).background(Circle().fill(Color(hex: step.tint)))
                            Text(t).font(.system(size: 15)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .cardStyle(padding: 16)
                if let section {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "What to note")
                        Text("Tap a level to see what it means.").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
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
            Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
            HStack(spacing: 4) {
                ForEach(Array(item.scale.enumerated()), id: \.offset) { i, s in
                    let on = picked == i
                    Button { withAnimation(.snappy) { picked = on ? nil : i } } label: {
                        Text(s).font(.system(size: 11, weight: on ? .semibold : .medium))
                            .foregroundStyle(on ? .white : Palette.ink.opacity(0.8))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.vertical, 8).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(on ? tint : tint.opacity(0.06 + 0.14 * Double(i) / Double(max(1, item.scale.count - 1)))))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(rich(item.tip)).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
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
