import SwiftUI

// MARK: - Wine card (one per grape)

struct WineCardView: View {
    let grape: Grape
    var index: Int? = nil
    var compact = false

    static func tint(for g: Grape) -> Color {
        switch g.berry {
        case .black: return Color(hex: "#C2185B")
        case .white: return Color(hex: "#D9B22E")
        case .pink: return Color(hex: "#E8708A")
        }
    }

    static func styleLine(for g: Grape) -> String {
        let color = g.berry == .black ? "red" : "white"
        let body = g.body >= 4 ? "Full-bodied" : (g.body <= 2 ? "Light-bodied" : "Medium-bodied")
        if g.sweetness >= 4 { return "Sweet \(color)" }
        return "\(body) \(color)"
    }

    var body: some View {
        let tint = Self.tint(for: grape)
        let glassColor = ContentStore.shared.color(grape.glass).map { Color(hex: $0.hex) } ?? tint
        VStack(alignment: .leading, spacing: 0) {
            // header band
            ZStack(alignment: .topLeading) {
                Rectangle().fill(LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if let i = index {
                                Text(String(format: "%02d", i)).font(.display(14, .heavy)).foregroundStyle(tint)
                            }
                            Text(Self.styleLine(for: grape).uppercased()).font(.system(size: 10.5, weight: .heavy)).kerning(1.2)
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Text(grape.name.uppercased())
                            .font(.display(compact ? 34 : 44, .black))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2).minimumScaleFactor(0.5)
                            .fixedSize(horizontal: false, vertical: true)
                        if let p = grape.pronounce {
                            Text(p).font(.system(size: 12, weight: .medium).italic()).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                    BottleView(style: BottleView.style(for: grape), glass: BottleView.glass(for: grape), label: grape.name,
                               labelTint: grape.berry == .black ? Palette.bordeaux : Color(hex: "#A07A1E"))
                        .frame(height: compact ? 130 : 170)
                        .offset(y: compact ? 16 : 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .frame(height: compact ? 150 : 190)
            .clipped()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PRIMARY FLAVORS").font(.system(size: 10.5, weight: .heavy)).kerning(1.3).foregroundStyle(Palette.inkSoft)
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(grape.aromas.prefix(5), id: \.self) { a in
                            VStack(spacing: 6) {
                                FlavorIcon(aroma: a, size: compact ? 26 : 30)
                                Text(a).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("TASTE PROFILE").font(.system(size: 10.5, weight: .heavy)).kerning(1.3).foregroundStyle(Palette.inkSoft)
                    StructureBars(grape: grape)
                }
                if !compact {
                    HStack(spacing: 10) {
                        WineGlass(color: glassColor, fill: 0.5).frame(width: 26, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SERVE WITH").font(.system(size: 10, weight: .heavy)).kerning(1.2).foregroundStyle(Palette.inkSoft)
                            Text(grape.food.prefix(3).joined(separator: " · ")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.card))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }
}

/// Swipeable deck of wine cards.
struct WineCardsScreen: View {
    @State private var filter = 0
    @State private var page = 0

    var body: some View {
        let all = ContentStore.shared.library.grapes.sorted { ($0.level, $0.name) < ($1.level, $1.name) }
        let grapes = all.filter { filter == 0 || (filter == 1 ? $0.berry == .black : $0.berry != .black) }
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("\(grapes.count) cards")
                Text("WINE CARDS").font(.display(40)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, Metrics.margin)
            Picker("Filter", selection: $filter) {
                Text("All").tag(0)
                Text("Red").tag(1)
                Text("White").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Metrics.margin)
            .onChange(of: filter) { _, _ in page = 0 }

            TabView(selection: $page) {
                ForEach(Array(grapes.enumerated()), id: \.element.id) { i, g in
                    NavigationLink(value: g) {
                        WineCardView(grape: g, index: i + 1)
                            .padding(.horizontal, Metrics.margin)
                            .padding(.bottom, 40)
                    }
                    .buttonStyle(.plain)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .id(filter)

            Text("\(min(page + 1, grapes.count)) / \(grapes.count)  ·  swipe for more")
                .font(.numeric(12, .semibold)).foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Boldness scale (scroll to move along the gradient)

struct BoldnessScreen: View {
    @State private var reds = true
    @State private var current: String? = nil

    static func score(_ g: Grape) -> Double {
        if g.berry == .black {
            return Double(g.body) * 2 + Double(g.tannin) * 1.6 + Double(g.alcohol) * 0.8 - Double(g.acidity) * 0.2
        }
        return Double(g.body) * 2 + Double(g.alcohol) * 0.8 + Double(g.sweetness) * 0.6 - Double(g.acidity) * 0.4
    }

    var body: some View {
        let list = ContentStore.shared.library.grapes
            .filter { reds ? $0.berry == .black : $0.berry != .black }
            .sorted { Self.score($0) < Self.score($1) }
        let colors: [Color] = reds ? ["#F0827A", "#E0284F", "#A3163C", "#5E0F2E", "#3A0A22"].map { Color(hex: $0) }
                                   : ["#F2EEC4", "#EBDD86", "#E2C24E", "#D69A2C", "#B8701E"].map { Color(hex: $0) }
        let idx = list.firstIndex { $0.id == current } ?? 0
        let frac = list.count > 1 ? CGFloat(idx) / CGFloat(list.count - 1) : 0

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(reds ? "RED WINE\nBOLDNESS" : "WHITE WINE\nBOLDNESS").font(.display(40)).foregroundStyle(Palette.ink)
                    .lineSpacing(-6)
                Picker("Type", selection: $reds) {
                    Text("Red").tag(true)
                    Text("White").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                // the gradient band with a moving marker
                GeometryReader { geo in
                    let h = geo.size.height
                    ZStack(alignment: .top) {
                        Capsule().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                            .frame(width: 26)
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, _ in
                            Circle().fill(.white.opacity(0.85)).frame(width: 4, height: 4)
                                .offset(y: 14 + (h - 28) * CGFloat(i) / CGFloat(max(1, list.count - 1)) - 2)
                        }
                        Circle().fill(Palette.card).frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                            .offset(y: (h - 28) * frac - 3)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: frac)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) { Text("LIGHTER").font(.system(size: 9, weight: .heavy)).kerning(1).rotationEffect(.degrees(-90)).offset(x: -26, y: 30).foregroundStyle(Palette.inkSoft) }
                    .overlay(alignment: .bottom) { Text("BOLDER").font(.system(size: 9, weight: .heavy)).kerning(1).rotationEffect(.degrees(-90)).offset(x: -26, y: -30).foregroundStyle(Palette.inkSoft) }
                }
                .frame(width: 70)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(list) { g in
                            row(g, active: g.id == (current ?? list.first?.id))
                                .id(g.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 220)
                }
                .scrollPosition(id: $current, anchor: .center)
                .scrollIndicators(.hidden)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                             .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            }
            .padding(.trailing, Metrics.margin)

            if let g = list.first(where: { $0.id == (current ?? list.first?.id) }) {
                NavigationLink(value: g) {
                    HStack(spacing: 14) {
                        GrapeCluster(berry: g.berry).frame(width: 30, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WineCardView.styleLine(for: g).uppercased()).font(.system(size: 10, weight: .heavy)).kerning(1).foregroundStyle(Palette.inkSoft)
                            Text(g.aromas.prefix(3).joined(separator: " · ")).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.wine)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 10)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: reds) { _, _ in current = nil }
        .onChange(of: current) { _, _ in Haptics.tap() }
    }

    private func row(_ g: Grape, active: Bool) -> some View {
        Text(g.name)
            .font(active ? .display(34, .black) : .system(size: 19, weight: .semibold))
            .foregroundStyle(active ? Palette.ink : Palette.inkFaint)
            .padding(.vertical, active ? 10 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.2), value: active)
    }
}

// MARK: - Color chart (poster)

struct ColorChartScreen: View {
    @State private var family = "white"

    var body: some View {
        let colors = ContentStore.shared.library.colors.filter { $0.chart == true && $0.family == family }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("WINE\nCOLOR CHART").font(.display(46)).foregroundStyle(Palette.ink).lineSpacing(-8)
                Rectangle().fill(Palette.ink).frame(height: 2)
                Text("Tilt the glass over something white. Judge depth at the core and hue at the rim, where age shows first.")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.inkSoft)
                Picker("Family", selection: $family) {
                    Text("White").tag("white")
                    Text("Rosé").tag("rose")
                    Text("Red").tag("red")
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                          alignment: .leading, spacing: 20) {
                    ForEach(Array(colors.enumerated()), id: \.element.id) { i, c in
                        VStack(alignment: .leading, spacing: 7) {
                            ColorSwatch(core: Color(hex: c.hex), rim: Color(hex: c.rim)).aspectRatio(1, contentMode: .fit)
                            Text(String(format: "%02d", i + 1)).font(.display(13, .heavy)).foregroundStyle(Palette.inkSoft)
                            Text(c.name.uppercased()).font(.display(15, .heavy)).foregroundStyle(Palette.ink)
                                .lineLimit(2).minimumScaleFactor(0.8)
                            if let e = c.examples {
                                Text(e).font(.system(size: 10.5, weight: .medium).italic()).foregroundStyle(Palette.inkSoft).lineLimit(3)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: family)

                Text("ALL YOU NEED IS GOOD WINE").font(.system(size: 12, weight: .heavy)).kerning(3).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 30)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 8)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
