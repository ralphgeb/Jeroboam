import SwiftUI

/// "Wine, explained in pictures": seven styles compared side by side.
struct StyleGuideScreen: View {
    struct Style: Identifiable {
        let id: String
        let name: String
        let color: Color
        let glassWidth: CGFloat
        let glassHeight: CGFloat
        let fill: CGFloat
        let sparkling: Bool
        let abv: String
        let temp: String
        let tempLevel: Double      // 0 cold … 1 room
        let keeps: String
        let keepsLevel: Double     // 0 … 1
        let calories: String
        let food: String
        let foods: String
        let wines: String
    }

    private let styles: [Style] = [
        Style(id: "sparkling", name: "Sparkling", color: Color(hex: "#EDE6B8"), glassWidth: 34, glassHeight: 118, fill: 0.78, sparkling: true,
              abv: "9–12.5%", temp: "6–10 °C", tempLevel: 0.1, keeps: "1–3 days", keepsLevel: 0.15, calories: "100–130",
              food: "Salty foods", foods: "Fries, oysters, popcorn, sushi", wines: "Champagne, Cava, Prosecco"),
        Style(id: "light-white", name: "Light white", color: Color(hex: "#EDE38E"), glassWidth: 50, glassHeight: 108, fill: 0.5, sparkling: false,
              abv: "10–12.5%", temp: "7–10 °C", tempLevel: 0.2, keeps: "3–5 days", keepsLevel: 0.4, calories: "110–125",
              food: "Vegetables", foods: "Salads, flaky fish, goat cheese", wines: "Sauvignon Blanc, Pinot Grigio, Albariño"),
        Style(id: "rich-white", name: "Rich white", color: Color(hex: "#E3BE55"), glassWidth: 56, glassHeight: 110, fill: 0.5, sparkling: false,
              abv: "13–14.5%", temp: "10–13 °C", tempLevel: 0.35, keeps: "3–5 days", keepsLevel: 0.4, calories: "120–150",
              food: "Creamy dishes", foods: "Lobster, roast chicken, risotto", wines: "Oaked Chardonnay, Viognier"),
        Style(id: "rose", name: "Rosé", color: Color(hex: "#EE9AA8"), glassWidth: 52, glassHeight: 108, fill: 0.5, sparkling: false,
              abv: "11–13%", temp: "7–10 °C", tempLevel: 0.2, keeps: "3–5 days", keepsLevel: 0.4, calories: "110–130",
              food: "Mediterranean", foods: "Charcuterie, grilled fish, mezze", wines: "Provence, Tavel, Navarra"),
        Style(id: "light-red", name: "Light red", color: Color(hex: "#B8263F"), glassWidth: 66, glassHeight: 112, fill: 0.42, sparkling: false,
              abv: "11.5–13.5%", temp: "12–14 °C", tempLevel: 0.5, keeps: "2–3 days", keepsLevel: 0.25, calories: "115–130",
              food: "Earthy dishes", foods: "Mushrooms, duck, salmon", wines: "Pinot Noir, Gamay, Valpolicella"),
        Style(id: "bold-red", name: "Bold red", color: Color(hex: "#4E0F27"), glassWidth: 70, glassHeight: 118, fill: 0.42, sparkling: false,
              abv: "13.5–15.5%", temp: "16–18 °C", tempLevel: 0.85, keeps: "3–5 days", keepsLevel: 0.4, calories: "130–170",
              food: "Red meat", foods: "Steak, barbecue, hard cheese", wines: "Cabernet, Syrah, Malbec"),
        Style(id: "dessert", name: "Dessert", color: Color(hex: "#B8701E"), glassWidth: 32, glassHeight: 82, fill: 0.6, sparkling: false,
              abv: "15–20%", temp: "8–16 °C", tempLevel: 0.45, keeps: "2–4 weeks", keepsLevel: 1.0, calories: "140–200*",
              food: "Desserts", foods: "Blue cheese, tarts, chocolate", wines: "Port, Sauternes, Sherry"),
    ]

    @State private var open: String? = "light-red"
    @Environment(\.windowWidth) private var width

    var body: some View {
        if width >= AdaptiveLayout.twoPaneThreshold { wideBody } else { narrowBody }
    }

    /// Duo: the seven styles listed on the left, the chosen one in full on the right.
    private var wideBody: some View {
        let st = styles.first { $0.id == open } ?? styles[0]
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ScreenHeader(eyebrow: "Wine, explained in pictures", title: "Style guide",
                                 subtitle: "Seven styles from light to rich. Tap one to see how to serve it and what to eat with it.")
                        .padding(.bottom, 6)
                    ForEach(styles) { s in
                        Button { withAnimation(.smooth(duration: 0.25)) { open = s.id } } label: {
                            HStack(spacing: 14) {
                                SilhouetteGlass(shape: shape(s), color: s.color, fill: s.fill, sparkling: s.sparkling).frame(width: 30, height: 52)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                    Text(s.wines).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(open == s.id ? Palette.wineSoft : Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .strokeBorder(open == s.id ? s.color.opacity(0.6) : Palette.line.opacity(0.6), lineWidth: open == s.id ? 1.2 : 0.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .frame(width: width / 2)
            Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 18) {
                        SilhouetteGlass(shape: shape(st), color: st.color, fill: st.fill, sparkling: st.sparkling).frame(width: 64, height: 110)
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Style")
                            Text(st.name).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(st.wines).font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    meter("Serve at", st.temp, st.tempLevel, icon: "thermometer.medium", from: Color(hex: "#5BA4D9"), to: Color(hex: "#E5484D"))
                    meter("Keeps once open", st.keeps, st.keepsLevel, icon: "clock", from: Palette.wineSoft, to: Palette.wine)
                    HStack(spacing: 12) {
                        stat("Alcohol", st.abv, "drop")
                        stat("Calories", st.calories + " / glass", "flame")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Great with " + st.food.lowercased(), systemImage: "fork.knife").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(st.foods).font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                    }
                    .cardStyle(padding: 14)
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
                .id(st.id)
            }
            .scrollIndicators(.hidden)
            .frame(width: width / 2 - 0.5)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var narrowBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(eyebrow: "Wine, explained in pictures", title: "Style guide",
                             subtitle: "Seven styles from light to rich. Tap one to see how to serve it and what to eat with it.")
                    .padding(.bottom, 8)
                ForEach(styles) { st in styleCard(st) }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
            .readable(720)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shape(_ st: Style) -> GlassArt.Shape {
        st.sparkling ? .flute : (st.id.contains("red") ? .red : (st.id == "dessert" ? .flute : .white))
    }

    private func styleCard(_ st: Style) -> some View {
        let isOpen = open == st.id
        return VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.smooth(duration: 0.32)) { open = isOpen ? nil : st.id } } label: {
                HStack(spacing: 14) {
                    SilhouetteGlass(shape: shape(st), color: st.color, fill: st.fill, sparkling: st.sparkling)
                        .frame(width: 34, height: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(st.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(st.wines).font(.system(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text(st.abv).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Palette.wineSoft))
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Always laid out at full size and revealed by the card's own height, so the text stays fixed to the card.
            VStack(alignment: .leading, spacing: 14) {
                    Hairline()
                    meter("Serve at", st.temp, st.tempLevel, icon: "thermometer.medium", from: Color(hex: "#5BA4D9"), to: Color(hex: "#E5484D"))
                    meter("Keeps once open", st.keeps, st.keepsLevel, icon: "clock", from: Palette.wineSoft, to: Palette.wine)
                    HStack(spacing: 12) {
                        stat("Alcohol", st.abv, "drop")
                        stat("Calories", st.calories + " / glass", "flame")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Great with " + st.food.lowercased(), systemImage: "fork.knife").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(st.foods).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: isOpen ? nil : 0, alignment: .top)
                .opacity(isOpen ? 1 : 0)
                .clipped()
                .allowsHitTesting(isOpen)
        }
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(isOpen ? st.color.opacity(0.6) : Palette.line.opacity(0.6), lineWidth: isOpen ? 1.2 : 0.5))
    }

    private func meter(_ title: String, _ value: String, _ level: Double, icon: String, from: Color, to: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(value).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cardAlt)
                    Capsule().fill(LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * level))
                }
            }
            .frame(height: 6)
        }
    }

    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(t, systemImage: icon).font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            Text(v).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.cardAlt.opacity(0.6)))
    }
}

struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 10, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct Thermometer: View {
    let level: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let tint = Color.blue.mix(with: Palette.flame, level)
            ZStack(alignment: .bottom) {
                Capsule().strokeBorder(Palette.ink, lineWidth: 1.5).frame(width: w * 0.55, height: h - w * 0.4)
                    .frame(maxHeight: .infinity, alignment: .top)
                Capsule().fill(tint).frame(width: w * 0.3, height: max(4, (h - w) * CGFloat(0.25 + 0.75 * level)))
                    .padding(.bottom, w * 0.5)
                Circle().fill(tint).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5)).frame(width: w, height: w)
            }
            .frame(width: w, height: h)
        }
    }
}

struct ClockGlyph: View {
    let level: Double
    var body: some View {
        ZStack {
            Circle().fill(Palette.brass.opacity(0.18))
            Circle().trim(from: 0, to: level).stroke(Palette.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                .padding(2)
            Circle().strokeBorder(Palette.ink, lineWidth: 1.5)
            Rectangle().fill(Palette.ink).frame(width: 1.5, height: 8).offset(y: -4)
            Rectangle().fill(Palette.ink).frame(width: 6, height: 1.5).offset(x: 3)
        }
    }
}
