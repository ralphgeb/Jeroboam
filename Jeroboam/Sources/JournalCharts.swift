import SwiftUI
import Charts

/// The Journal's richer charts: your taste fingerprint, the months you drank in, your blind-tasting progress, your grapes as a
/// ring and when your cellar is ready. Each is a card like the others in "Your wine world"; cards without data stay hidden.

private func chartCard<C: View>(_ title: String, _ sub: String, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(sub).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(padding: 16)
}

// MARK: one sentence about you

enum TasteInsight {
    /// A short sentence from what you have tasted, or nil with too little to say.
    static func sentence(entries: [JournalEntry]) -> String? {
        guard entries.count >= 3 else { return nil }
        let n = Double(entries.count)
        let acid = Double(entries.map(\.acidity).reduce(0, +)) / n
        let body = Double(entries.map(\.body).reduce(0, +)) / n
        let reds = entries.filter { $0.wine.style.lowercased().contains("red") }.count
        let whites = entries.filter { $0.wine.style.lowercased().contains("white") }.count
        var grapes: [String: Int] = [:]
        for e in entries { if let g = e.wine.grapes.first { grapes[g, default: 0] += 1 } }
        let top = grapes.max { $0.value < $1.value }
        let kind = reds > whites * 2 ? "reds" : (whites > reds * 2 ? "whites" : "wines")
        let feel = body >= 3.6 ? "full-bodied" : (body <= 2.4 ? "light, delicate" : "medium-bodied")
        let fresh = acid >= 3.6 ? ", with plenty of freshness" : (acid <= 2.4 ? ", soft rather than sharp" : "")
        var s = "You lean towards \(feel) \(kind)\(fresh)."
        if let t = top, t.value >= 2 { s += " \(t.key) comes up most." }
        return s
    }
}

struct InsightSentenceCard: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(Palette.wine).padding(.top, 2)
            Text(text).font(.jero(size: 15.5, weight: .medium)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.wineSoft))
    }
}

// MARK: taste fingerprint (radar)

struct TasteFingerprintCard: View {
    let entries: [JournalEntry]
    @State private var shown = false

    private var axes: [(String, Double)] {
        let n = Double(max(1, entries.count))
        func avg(_ k: KeyPath<JournalEntry, Int>) -> Double { Double(entries.map { $0[keyPath: k] }.reduce(0, +)) / n }
        return [("Sweetness", min(5, avg(\.sweetness) * 5 / 4)), ("Acidity", avg(\.acidity)), ("Tannin", avg(\.tannin)),
                ("Body", avg(\.body)), ("Finish", avg(\.finish))]
    }

    var body: some View {
        chartCard("Your taste fingerprint", "The average of the \(entries.count) \(entries.count == 1 ? "wine" : "wines") you have tasted. It shifts as your taste does.") {
            let values = axes
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 4)
                let R = min(geo.size.width, geo.size.height) / 2 - 26
                let pt: (Int, Double) -> CGPoint = { i, v in
                    let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(values.count)
                    let r = R * CGFloat(v / 5)
                    return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
                }
                ZStack {
                    // rings and spokes
                    ForEach(1...5, id: \.self) { ring in
                        Path { p in
                            for i in values.indices { i == 0 ? p.move(to: pt(i, Double(ring))) : p.addLine(to: pt(i, Double(ring))) }
                            p.closeSubpath()
                        }
                        .stroke(Palette.line, lineWidth: ring == 5 ? 1 : 0.6)
                    }
                    ForEach(values.indices, id: \.self) { i in
                        Path { p in p.move(to: c); p.addLine(to: pt(i, 5)) }.stroke(Palette.line, lineWidth: 0.6)
                    }
                    // your shape
                    let shape = Path { p in
                        for (i, v) in values.enumerated() {
                            let q = pt(i, shown ? v.1 : 0.4)
                            i == 0 ? p.move(to: q) : p.addLine(to: q)
                        }
                        p.closeSubpath()
                    }
                    shape.fill(Palette.wine.opacity(0.22))
                    shape.stroke(Palette.wine, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    ForEach(values.indices, id: \.self) { i in
                        Text(values[i].0).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.inkSoft)
                            .position(pt(i, 6.1))
                    }
                }
            }
            .frame(height: 210)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(values.map { "\($0.0) \(StructureBars.level(Int($0.1.rounded())))" }.joined(separator: ", "))
            .onAppear { withAnimation(.spring(duration: 0.8)) { shown = true } }
        }
    }
}

// MARK: months (how many wines, and how much you liked them)

struct MonthsCard: View {
    let wines: [InsightWine]

    private struct Month: Identifiable { let id: Date; let count: Int; let score: Double? }

    private var months: [Month] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -11, to: cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()) ?? Date()
        return (0..<12).compactMap { k in
            guard let m = cal.date(byAdding: .month, value: k, to: start), let next = cal.date(byAdding: .month, value: 1, to: m) else { return nil }
            let ws = wines.filter { $0.date >= m && $0.date < next }
            let rated = ws.compactMap(\.rating).map { $0 <= 10 ? 50 + $0 * 5 : $0 }
            return Month(id: m, count: ws.count, score: rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count))
        }
    }

    var body: some View {
        let ms = months
        let busiest = ms.max { $0.count < $1.count }
        chartCard("Month by month", busiest.map { $0.count > 0 ? "Busiest: \($0.id.formatted(.dateTime.month(.wide))), with \($0.count)" : "The last twelve months" } ?? "") {
            Chart {
                ForEach(ms) { m in
                    BarMark(x: .value("Month", m.id, unit: .month), y: .value("Wines", m.count))
                        .foregroundStyle(Palette.wine.opacity(0.85).gradient).cornerRadius(4)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .chartYAxis(.hidden)
            .frame(height: 110)
            let scored = ms.filter { $0.score != nil }
            if scored.count >= 2 {
                Text("Your average score").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft).padding(.top, 2)
                Chart(scored) { m in
                    LineMark(x: .value("Month", m.id, unit: .month), y: .value("Score", m.score ?? 0))
                        .interpolationMethod(.catmullRom).foregroundStyle(Palette.brass).lineStyle(StrokeStyle(lineWidth: 2.2))
                    PointMark(x: .value("Month", m.id, unit: .month), y: .value("Score", m.score ?? 0))
                        .foregroundStyle(Palette.brass).symbolSize(26)
                }
                .chartYScale(domain: max(50, (scored.compactMap(\.score).min() ?? 80) - 4)...min(100, (scored.compactMap(\.score).max() ?? 95) + 3))
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .frame(height: 80)
            }
        }
    }
}

// MARK: blind tasting progress

struct BlindProgressCard: View {
    let blind: [JournalEntry]

    var body: some View {
        let pts = blind.compactMap { e in e.score.map { (date: e.date, score: Double($0)) } }.sorted { $0.date < $1.date }
        let n = Double(pts.count)
        // least-squares trend through the scores, by tasting number
        let xs = pts.indices.map(Double.init), ys = pts.map(\.score)
        let mx = xs.reduce(0, +) / max(1, n), my = ys.reduce(0, +) / max(1, n)
        let sxx = xs.map { ($0 - mx) * ($0 - mx) }.reduce(0, +)
        let slope = sxx > 0 ? zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / sxx : 0
        let trend = slope > 0.8 ? "You are getting sharper: about +\(Int(slope.rounded())) points a tasting" :
                    (slope < -0.8 ? "A dip lately: tough wines happen" : "Steady around \(Int(my.rounded())) / 100")
        chartCard("Blind tasting", trend) {
            Chart {
                ForEach(Array(pts.enumerated()), id: \.offset) { i, p in
                    LineMark(x: .value("Tasting", i + 1), y: .value("Score", p.score), series: .value("Line", "Scores"))
                        .interpolationMethod(.monotone).foregroundStyle(Palette.wine)
                    PointMark(x: .value("Tasting", i + 1), y: .value("Score", p.score)).foregroundStyle(Palette.wine).symbolSize(30)
                }
                if pts.count >= 3 {
                    // the trend, as a dashed straight line from the first tasting to the last
                    ForEach([1, pts.count], id: \.self) { x in
                        LineMark(x: .value("Tasting", x), y: .value("Score", my + slope * (Double(x - 1) - mx)), series: .value("Line", "Trend"))
                            .foregroundStyle(Palette.brass).lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(6, pts.count))) }
            .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) }
            .frame(height: 140)
        }
    }
}

// MARK: grapes as a ring (tap a slice)

struct GrapeRingCard: View {
    let wines: [InsightWine]
    @State private var pick: Int? = nil

    private static let colors: [Color] = [Color(hex: "#8B1538"), Color(hex: "#C25A74"), Color(hex: "#B07A2A"), Color(hex: "#6E8B5E"),
                                          Color(hex: "#5A6E9C"), Color(hex: "#B8AFA6")]

    var body: some View {
        var tally: [String: Int] = [:]
        for w in wines { for g in w.grapes.prefix(1) { tally[g, default: 0] += 1 } }
        let sorted = tally.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
        var slices = Array(sorted.prefix(5)).map { (name: $0.key, n: $0.value) }
        let rest = sorted.dropFirst(5).map(\.value).reduce(0, +)
        if rest > 0 { slices.append(("Others", rest)) }
        let total = slices.map(\.n).reduce(0, +)
        let chosen = selectedSlice(slices)
        return chartCard("Your grapes", "Tap the ring to see each one's share") {
            HStack(spacing: 16) {
                Chart(Array(slices.enumerated()), id: \.offset) { i, s in
                    SectorMark(angle: .value("Wines", s.n), innerRadius: .ratio(0.62), outerRadius: .ratio(chosen?.name == s.name ? 1 : 0.92), angularInset: 1.5)
                        .foregroundStyle(Self.colors[i % Self.colors.count])
                        .opacity(chosen == nil || chosen?.name == s.name ? 1 : 0.45)
                }
                .chartAngleSelection(value: $pick)
                .chartBackground { _ in
                    VStack(spacing: 0) {
                        Text(chosen.map { "\(Int((Double($0.n) / Double(max(1, total)) * 100).rounded()))%" } ?? "\(total)")
                            .font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundStyle(Palette.ink)
                        Text(chosen == nil ? "wines" : "of wines").font(.system(size: 10.5)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(slices.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 7) {
                            Circle().fill(Self.colors[i % Self.colors.count]).frame(width: 8, height: 8)
                            Text(s.name).font(.system(size: 13, weight: chosen?.name == s.name ? .semibold : .regular))
                                .foregroundStyle(Palette.ink).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(s.n)").font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
            }
        }
    }

    /// The slice under the selected angle value (Charts reports a running total).
    private func selectedSlice(_ slices: [(name: String, n: Int)]) -> (name: String, n: Int)? {
        guard let v = pick else { return nil }
        var run = 0
        for s in slices { run += s.n; if v <= run { return s } }
        return nil
    }
}

// MARK: when the cellar is ready

struct CellarReadinessCard: View {
    let cellar: [CellarBottle]

    var body: some View {
        var young = 0, ready = 0, past = 0, unknown = 0
        for b in cellar {
            switch DrinkWindow.phase(b.wine.drinkWindow) {
            case .young?: young += b.quantity
            case .ready?: ready += b.quantity
            case .past?: past += b.quantity
            case nil: unknown += b.quantity
            }
        }
        let parts: [(String, Int, Color)] = [("Ready now", ready, Palette.correct), ("Wait", young, Palette.brass),
                                             ("Past its best", past, Palette.wrong), ("Unknown", unknown, Palette.line)].filter { $0.1 > 0 }
        let total = max(1, parts.map(\.1).reduce(0, +))
        return chartCard("When to open them", ready > 0 ? "\(ready) \(ready == 1 ? "bottle is" : "bottles are") ready to drink now" : "Nothing at its best yet: patience") {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.0) { p in
                        Rectangle().fill(p.2).frame(width: max(4, (geo.size.width - CGFloat(parts.count - 1) * 2) * CGFloat(p.1) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            FlowLayout(spacing: 12, lineSpacing: 6) {
                ForEach(parts, id: \.0) { p in
                    HStack(spacing: 5) {
                        Circle().fill(p.2).frame(width: 8, height: 8)
                        Text("\(p.0) \(p.1)").font(.system(size: 12.5)).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
    }
}
