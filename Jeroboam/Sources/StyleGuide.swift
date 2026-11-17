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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Wine, explained in pictures")
                    Text("STYLE GUIDE").font(.display(46)).foregroundStyle(Palette.ink)
                    Text("Seven styles side by side. Swipe across the poster.").font(.system(size: 14.5, weight: .medium)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, Metrics.margin)

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ribbon("Wine glasses")
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(styles) { s in
                                VStack(spacing: 8) {
                                    WineGlass(color: s.color, fill: s.fill, sparkling: s.sparkling)
                                        .frame(width: s.glassWidth, height: s.glassHeight)
                                    Text(s.name.uppercased()).font(.display(14, .heavy)).foregroundStyle(Palette.ink)
                                }
                                .frame(width: 112)
                            }
                        }
                        .padding(.vertical, 14)
                        rowDivider
                        metricRow("ALCOHOL") { s in Text(s.abv).font(.display(20, .black)).foregroundStyle(Palette.ink) }
                        rowDivider
                        metricRow("SERVE AT") { s in
                            VStack(spacing: 6) {
                                Thermometer(level: s.tempLevel).frame(width: 12, height: 40)
                                Text(s.temp).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                        }
                        rowDivider
                        metricRow("KEEPS OPEN") { s in
                            VStack(spacing: 6) {
                                ClockGlyph(level: s.keepsLevel).frame(width: 30, height: 30)
                                Text(s.keeps).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                        }
                        rowDivider
                        metricRow("CALORIES") { s in
                            VStack(spacing: 2) {
                                Text(s.calories).font(.display(18, .black)).foregroundStyle(Palette.ink)
                                Text("per 150 ml").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                        }
                        ribbon("Wine with food").padding(.top, 18)
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(styles) { s in
                                VStack(spacing: 10) {
                                    ZStack {
                                        BottleShape(style: s.sparkling ? .sparkling : .bordeaux)
                                            .fill(s.color.opacity(0.85))
                                            .frame(width: 44, height: 150)
                                        Text(s.name.uppercased()).font(.display(13, .black))
                                            .foregroundStyle(s.id == "bold-red" || s.id == "light-red" ? Color.white : Palette.ink.opacity(0.85))
                                            .fixedSize()
                                            .rotationEffect(.degrees(-90))
                                            .offset(y: 22)
                                    }
                                    Text(s.food).font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                                    Text(s.foods).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                                    Text(s.wines).font(.system(size: 10.5, weight: .semibold).italic()).foregroundStyle(Palette.pink)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 112)
                                .padding(.vertical, 12)
                            }
                        }
                        Text("* Dessert wines per 75 ml serving. Figures are typical ranges.")
                            .font(.system(size: 10.5)).foregroundStyle(Palette.inkFaint).padding(.top, 6)
                    }
                    .padding(.horizontal, Metrics.margin)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rowDivider: some View {
        Rectangle().fill(Palette.line).frame(width: CGFloat(styles.count) * 112, height: 1)
    }

    private func ribbon(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
            .padding(.leading, 12).padding(.trailing, 22).padding(.vertical, 6)
            .background(RibbonShape().fill(Palette.pink))
    }

    private func metricRow<C: View>(_ title: String, @ViewBuilder _ content: @escaping (Style) -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9.5, weight: .heavy)).kerning(1.4).foregroundStyle(Palette.inkSoft)
            HStack(alignment: .center, spacing: 0) {
                ForEach(styles) { s in content(s).frame(width: 112) }
            }
        }
        .padding(.vertical, 12)
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
