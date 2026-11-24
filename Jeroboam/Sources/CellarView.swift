import SwiftUI

struct CellarRoute: Hashable {}

/// The whole cellar: what it is worth, and every bottle, filtered and sorted however you like.
struct CellarView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss

    private enum Sort: String, CaseIterable, Identifiable {
        case recent = "Recently added", priceHigh = "Value, high to low", priceLow = "Value, low to high",
             paidHigh = "Price paid, high to low", paidLow = "Price paid, low to high", rating = "Rating",
             vintageNew = "Vintage, newest", vintageOld = "Vintage, oldest", name = "Name"
        var id: String { rawValue }
    }
    private static let colors: [(String, String)] = [("All", ""), ("Red", "red"), ("White", "white"), ("Rosé", "rose"), ("Sparkling", "sparkling"), ("Sweet", "sweet")]

    @State private var color = ""
    @State private var sort: Sort = .recent
    @State private var priceBand = 0            // 0 any, 1 under $25, 2 $25–50, 3 $50–100, 4 $100+
    @State private var minRating = 0            // 0 any, 80, 85, 90
    @State private var vintage = ""             // "" any
    @AppStorage("jero.cellarCompact") private var asList = true      // the compact list is the first view
    @State private var openStat: CellarStat? = nil
    @State private var opened: CellarBottle? = nil

    private func family(_ s: String) -> String {
        let t = s.lowercased()
        if t.contains("spark") || t.contains("champ") { return "sparkling" }
        if t.contains("ros") { return "rose" }
        if t.contains("sweet") || t.contains("fortif") || t.contains("dessert") { return "sweet" }
        if t.contains("white") || t.contains("orange") { return "white" }
        return "red"
    }
    private func usd(_ b: CellarBottle) -> Double? { b.price.map { $0.currency == "USD" || $0.currency.isEmpty ? $0.average : Currency.convert($0.average, from: $0.currency, to: "USD") } }

    private var vintages: [String] {
        Array(Set(journal.cellar.map(\.vintageText))).sorted { $0 > $1 }
    }

    private var shown: [CellarBottle] {
        var list = journal.cellar.filter { b in
            if !color.isEmpty, family(b.wine.style) != color { return false }
            if priceBand > 0 {
                guard let p = usd(b) else { return false }
                switch priceBand { case 1: if p >= 25 { return false }; case 2: if p < 25 || p >= 50 { return false }
                                   case 3: if p < 50 || p >= 100 { return false }; default: if p < 100 { return false } }
            }
            if minRating > 0, (b.roughRating ?? 0) < minRating { return false }
            if !vintage.isEmpty, b.vintageText != vintage { return false }
            return true
        }
        switch sort {
        case .recent: list.sort { $0.added > $1.added }
        case .priceHigh: list.sort { (usd($0) ?? -1) > (usd($1) ?? -1) }
        case .priceLow: list.sort { (usd($0) ?? .infinity) < (usd($1) ?? .infinity) }
        case .paidHigh: list.sort { ($0.paidUSD ?? -1) > ($1.paidUSD ?? -1) }
        case .paidLow: list.sort { ($0.paidUSD ?? .infinity) < ($1.paidUSD ?? .infinity) }
        case .rating: list.sort { ($0.roughRating ?? 0) > ($1.roughRating ?? 0) }
        case .vintageNew: list.sort { $0.vintageText > $1.vintageText }
        case .vintageOld: list.sort { $0.vintageText < $1.vintageText }
        case .name: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    /// What you paid is shown next to the value only while the cellar is sorted by it.
    private var showPaid: Bool { sort == .paidHigh || sort == .paidLow }
    private var filtersOn: Bool { !color.isEmpty || priceBand > 0 || minRating > 0 || !vintage.isEmpty }

    var body: some View {
        let list = shown
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Your wines", title: "Cellar", subtitle: "Every bottle you own, what it is worth and how it scores.")
                stats(list)
                chips
                filterBar
                if !journal.duplicateGroups.isEmpty {
                    let n = journal.duplicateGroups.reduce(0) { $0 + $1.count - 1 }
                    Button { withAnimation { journal.mergeDuplicates() } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.on.square").foregroundStyle(Palette.wine)
                            Text("\(n) \(n == 1 ? "wine is" : "wines are") in your cellar twice. Merge them into one card each.")
                                .font(.system(size: 13.5)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Text("Merge").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.onWine)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Palette.wine))
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wineSoft))
                    }.buttonStyle(.plain)
                }
                HStack {
                    Text("\(list.count) \(list.count == 1 ? "wine" : "wines")\(filtersOn ? " match" : "")").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                    Spacer()
                    layoutToggle
                    if filtersOn {
                        Button("Clear filters") { withAnimation(.smooth(duration: 0.25)) { color = ""; priceBand = 0; minRating = 0; vintage = "" } }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.wine)
                    }
                }
                Color.clear.frame(height: 2)
                if list.isEmpty {
                    Text("No bottles match these filters.").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if asList {
                    GroupCard {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, b in
                            Button { opened = b } label: { row(b, last: i == list.count - 1) }.buttonStyle(RowPressStyle())
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], alignment: .center, spacing: 12) {
                        ForEach(list) { b in
                            Button { opened = b } label: { tile(b) }.buttonStyle(PressableStyle())
                        }
                    }
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, Metrics.margin)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
        .animation(.smooth(duration: 0.25), value: color)
        .navigationDestination(item: $opened) { CellarDetailView(bottleID: $0.id) }
    }

    // total value, average price, bottle count
    private func stats(_ list: [CellarBottle]) -> some View {
        let value = list.reduce(0.0) { $0 + ($1.price?.average ?? 0) * Double($1.quantity) }
        let n = list.reduce(0) { $0 + $1.quantity }
        let priced = list.filter { $0.price != nil }
        let bottlesPriced = priced.reduce(0) { $0 + $1.quantity }
        let avg = bottlesPriced == 0 ? 0 : priced.reduce(0.0) { $0 + ($1.price?.average ?? 0) * Double($1.quantity) } / Double(bottlesPriced)
        let cur = journal.cellarCurrency
        let paidBottles = list.filter { $0.paidUSD != nil }
        let paid = paidBottles.reduce(0.0) { $0 + ($1.paidTotal ?? 0) }
        let worthOfPaid = paidBottles.reduce(0.0) { $0 + $1.value }
        let diff = worthOfPaid - paid
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(money(value, cur), filtersOn ? "value of these" : "valuation today", .value, highlight: true)
                statTile(avg > 0 ? money(avg, cur) : "–", "average bottle\n\(n) \(n == 1 ? "bottle" : "bottles")", .average)
                if !paidBottles.isEmpty {
                    statTile((diff >= 0 ? "+" : "−") + money(abs(diff), cur), diff >= 0 ? "gain on\nwhat you paid" : "loss on\nwhat you paid", .gain)
                }
            }
            if let s = openStat {
                CellarChartPanel(stat: s, bottles: list, currency: cur).transition(.unfold)
            }
        }
        .animation(.smooth(duration: 0.35), value: openStat)
    }
    /// Two big buttons (list first). Big enough to press, and nothing under them reacts to a press that lands on them.
    private var layoutToggle: some View {
        HStack(spacing: 0) {
            toggleButton("list.bullet", compact: true)
            toggleButton("square.grid.2x2", compact: false)
        }
        .padding(3).background(Capsule().fill(Palette.cardAlt))
        .padding(.bottom, 6)
        .zIndex(2)
    }
    private func toggleButton(_ icon: String, compact: Bool) -> some View {
        let on = asList == compact
        return Button { Haptics.tap(); withAnimation(.smooth(duration: 0.2)) { asList = compact } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Palette.onWine : Palette.ink)
                .frame(width: 46, height: 34)
                .background(Capsule().fill(on ? Palette.wine : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(compact ? "Compact list" : "Cards")
    }

    private func statTile(_ v: String, _ label: String, _ stat: CellarStat, highlight: Bool = false) -> some View {
        let on = openStat == stat
        return Button { Haptics.tap(); openStat = on ? nil : stat } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(v).font(.system(size: 20, weight: .bold).monospacedDigit()).foregroundStyle(highlight ? Palette.onWine : Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(highlight ? Palette.onWine.opacity(0.7) : Palette.inkFaint)
                }
                Text(label).font(.system(size: 11.5)).foregroundStyle(highlight ? Palette.onWine.opacity(0.8) : Palette.inkSoft).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(highlight ? Palette.wine : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.wine : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.colors, id: \.0) { name, key in
                    let on = color == key
                    Button { Haptics.tap(); color = key } label: {
                        HStack(spacing: 6) {
                            if !key.isEmpty { Circle().fill(styleColor(key == "rose" ? "rose" : key)).frame(width: 9, height: 9) }
                            Text(name).font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(on ? Palette.onWine : Palette.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(on ? Palette.wine : Palette.card))
                        .overlay(Capsule().strokeBorder(on ? .clear : Palette.line.opacity(0.7), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                menu(icon: "arrow.up.arrow.down", title: sort.rawValue, active: sort != .recent) {
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases) { Text($0.rawValue).tag($0) } }
                }
                menu(icon: "tag", title: ["Any price", "Under $25", "$25–50", "$50–100", "$100+"][priceBand], active: priceBand > 0) {
                    Picker("Price", selection: $priceBand) {
                        Text("Any price").tag(0); Text("Under $25").tag(1); Text("$25–50").tag(2); Text("$50–100").tag(3); Text("$100+").tag(4)
                    }
                }
                menu(icon: "star", title: minRating == 0 ? "Any rating" : "\(minRating)+ pts", active: minRating > 0) {
                    Picker("Rating", selection: $minRating) {
                        Text("Any rating").tag(0); Text("90+ points").tag(90); Text("85+ points").tag(85); Text("80+ points").tag(80)
                    }
                }
                menu(icon: "calendar", title: vintage.isEmpty ? "Any vintage" : vintage, active: !vintage.isEmpty) {
                    Picker("Vintage", selection: $vintage) {
                        Text("Any vintage").tag("")
                        ForEach(vintages, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        }
    }

    private func menu<C: View>(icon: String, title: String, active: Bool, @ViewBuilder _ content: () -> C) -> some View {
        Menu { content() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(active ? Palette.wine : Palette.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(active ? Palette.wineSoft : Palette.cardAlt))
        }
    }

    private func tile(_ b: CellarBottle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Thumb(photo: b.photo, style: b.wine.style).frame(height: 150).frame(maxWidth: .infinity).clipped()
                if b.quantity > 1 {
                    Text("× \(b.quantity)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Palette.bordeaux.opacity(0.92))).padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(b.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2, reservesSpace: true)
                Text([b.vintageText, b.wine.region].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                HStack {
                    Text(b.price.map { $0.averageText } ?? "–").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                    if showPaid { Text(b.paidUSD.map { "paid " + money($0, "USD") } ?? "paid –").font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.inkSoft).lineLimit(1) }
                    Spacer()
                    if let r = b.roughRating { Text("\(r)").font(.system(size: 11.5, weight: .bold).monospacedDigit()).foregroundStyle(Palette.inkSoft) }
                }
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    }

    private func row(_ b: CellarBottle, last: Bool) -> some View {
        // compact: the same two-line row as the Journal tab (small picture, title, one detail line, value on the right)
        HStack(spacing: 10) {
            Thumb(photo: b.photo, style: b.wine.style).frame(width: 34, height: 44).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(b.title).font(.system(size: 14.5, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Text([b.vintageText, b.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text(b.price.map { $0.averageText } ?? "–").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                Text(showPaid ? (b.paidUSD.map { "paid " + money($0, "USD") + " · ×\(b.quantity)" } ?? "paid – · ×\(b.quantity)") : "× \(b.quantity)")
                    .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 56) } }
        .contentShape(Rectangle())
    }
}
