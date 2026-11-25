import SwiftUI

// MARK: - Wine card (one per grape)

struct WineCardView: View {
    let grape: Grape
    var index: Int? = nil
    var compact = false

    static func tint(for g: Grape) -> Color {
        switch g.berry {
        case .black: return Color.dynamic("#8B1538", "#E07A93")
        case .white: return Color.dynamic("#B08A1E", "#E3C25E")
        case .pink: return Color.dynamic("#C25A74", "#E896AB")
        }
    }

    /// Berry gradient for the grape illustration (top → bottom).
    static func berryGradient(for g: Grape) -> [Color] {
        switch g.berry {
        case .black: return ["#B9536F", "#7E1A3D", "#4A0C26", "#2C0718"].map { Color(hex: $0) }
        case .white: return ["#EFEBB8", "#D9D27A", "#B8B24A", "#8F8A2E"].map { Color(hex: $0) }
        case .pink: return ["#F2C6CF", "#DA8EA0", "#B85C76", "#8E3A55"].map { Color(hex: $0) }
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if let i = index {
                            Text(String(format: "No. %02d", i)).font(.jero(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                        }
                        Text(Self.styleLine(for: grape).uppercased()).font(.jero(size: 10.5, weight: .semibold)).kerning(1)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Text(grape.name)
                        .font(.system(size: compact ? 24 : 28, weight: .bold)).kerning(-0.3)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2).minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                    if let p = grape.pronounce {
                        Text(p).font(.jero(size: 13).italic()).foregroundStyle(Palette.inkSoft)
                    } else {
                        Text(grape.origin).font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                GrapeBadge(grape: grape, size: compact ? 64 : 76)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 18)

            Hairline().padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Primary flavors")
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(grape.aromas.prefix(5), id: \.self) { a in
                            VStack(spacing: 6) {
                                FlavorIcon(aroma: a, size: compact ? 30 : 34)
                                Text(a).font(.jero(size: 10.5)).foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Taste profile")
                    StructureBars(grape: grape)
                }
                if !compact {
                    HStack(spacing: 12) {
                        WineGlass(color: glassColor, fill: 0.5).frame(width: 22, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow("Serve with")
                            Text(grape.food.prefix(3).joined(separator: " · ")).font(.jero(size: 13.5)).foregroundStyle(Palette.ink)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

/// Rendered bunch image for a grape (Resources/Grapes/<id>.png), cached.
enum GrapeImages {
    private static var cache: [String: UIImage] = [:]
    static func image(_ id: String) -> UIImage? {
        if let i = cache[id] { return i }
        guard let url = Bundle.main.url(forResource: id, withExtension: "png", subdirectory: "Grapes")
                ?? Bundle.main.url(forResource: id, withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[id] = img
        return img
    }
}

/// The grape picture used on cards and lists: the rendered bunch, on a soft tinted disc.
struct GrapeBadge: View {
    let grape: Grape
    var size: CGFloat = 76
    var disc = true
    var body: some View {
        ZStack {
            if disc { Circle().fill(WineCardView.tint(for: grape).opacity(0.07)) }
            if let img = GrapeImages.image(grape.id) {
                Image(uiImage: img).resizable().interpolation(.high).scaledToFit()
                    .frame(width: size * 0.9, height: size * 0.9)
                    .shadow(color: .black.opacity(0.12), radius: size * 0.04, y: size * 0.03)
            } else {
                GrapeCluster(berry: grape.berry, seed: grape.name.count * 31 + grape.id.count)
                    .frame(width: size * 0.86, height: size * 0.86)
            }
        }
        .frame(width: size, height: size)
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
            ScreenHeader(eyebrow: "\(grapes.count) cards", title: "Wine cards")
                .padding(.horizontal, Metrics.margin)
                .readable(720)
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
                            .padding(.top, 6)
                            .padding(.bottom, 30)
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
        .halfPage()
        .pageChrome()
    }
}

// MARK: - Boldness scale (scroll the list; the marker travels along the gradient)

struct BoldnessScreen: View {
    @State private var reds = true
    @State private var current: String? = nil

    static func score(_ g: Grape) -> Double {
        if g.berry == .black {
            return Double(g.body) * 2 + Double(g.tannin) * 1.6 + Double(g.alcohol) * 0.8 - Double(g.acidity) * 0.2
        }
        return Double(g.body) * 2 + Double(g.alcohol) * 0.8 + Double(g.sweetness) * 0.6 - Double(g.acidity) * 0.4
    }

    static func gradient(reds: Bool) -> [Color] {
        reds ? ["#F3B3A8", "#E0607A", "#B0234B", "#6E0F33", "#36081C"].map { Color(hex: $0) }
             : ["#F4F0CF", "#EADF96", "#DCC25C", "#C99A33", "#A26A1F"].map { Color(hex: $0) }
    }

    var body: some View {
        let list = ContentStore.shared.library.grapes
            .filter { reds ? $0.berry == .black : $0.berry != .black }
            .sorted { Self.score($0) < Self.score($1) }
        let colors = Self.gradient(reds: reds)
        let activeID = current ?? list.first?.id
        let idx = list.firstIndex { $0.id == activeID } ?? 0
        let frac = list.count > 1 ? CGFloat(idx) / CGFloat(list.count - 1) : 0

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(eyebrow: "Boldness scale", title: reds ? "Red wines" : "White wines",
                             subtitle: "From light and delicate to rich and bold. Scroll to move along the scale.")
                Picker("Type", selection: $reds) {
                    Text("Red").tag(true)
                    Text("White").tag(false)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 6)

            HStack(spacing: 0) {
                GeometryReader { geo in
                    let h = geo.size.height
                    let inset: CGFloat = 40
                    ZStack(alignment: .top) {
                        Capsule().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: h - inset * 2).offset(y: inset)
                        Circle().fill(Palette.card).frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            .offset(y: inset + (h - inset * 2) * frac - 9)
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: frac)
                        Text("Light").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.inkSoft).offset(y: 14)
                        Text("Bold").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.inkSoft).offset(y: h - 26)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 56)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(list) { g in
                            row(g, active: g.id == activeID).id(g.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 200)
                }
                .scrollPosition(id: $current, anchor: .center)
                .scrollIndicators(.hidden)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                             .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            }
            .padding(.trailing, Metrics.margin)

            if let g = list.first(where: { $0.id == activeID }) {
                NavigationLink(value: g) {
                    HStack(spacing: 14) {
                        GrapeBadge(grape: g, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(WineCardView.styleLine(for: g)).font(.jero(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft)
                            HStack(spacing: 10) {
                                ForEach(g.aromas.prefix(4), id: \.self) { a in FlavorIcon(aroma: a, size: 22) }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                    .zoomSource(ZoomID.grape(g.id))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 10)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
        .onChange(of: reds) { _, _ in current = nil }
        .onChange(of: current) { _, _ in Haptics.tap() }
        .rightPane {
            if let g = list.first(where: { $0.id == activeID }) { GrapeDetailView(grape: g).id(g.id) }
        }
    }

    private func row(_ g: Grape, active: Bool) -> some View {
        Text(g.name)
            .font(.system(size: active ? 26 : 17, weight: active ? .bold : .regular))
            .foregroundStyle(active ? Palette.ink : Palette.inkFaint)
            .padding(.vertical, active ? 10 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.2), value: active)
    }
}

// MARK: - Color chart (square swatches, four per row)


/// The owner's grape photo cutout as a small icon (falls back to the drawn bunch).
struct GrapeArt: View {
    let id: String
    var size: CGFloat = 44
    var body: some View {
        if let img = GrapeImages.image(id) {
            Image(uiImage: img).resizable().interpolation(.high).scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
        } else {
            GrapeCluster(berry: .black, seed: 3).frame(width: size, height: size)
        }
    }
}
