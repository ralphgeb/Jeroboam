import SwiftUI

struct CellarRoute: Hashable {}

/// The whole cellar: what it is worth, and every bottle, filtered and sorted however you like.
struct CellarView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss

    private enum Sort: String, CaseIterable, Identifiable {
        case recent = "Recently added", priceHigh = "Price, high to low", priceLow = "Price, low to high", rating = "Rating",
             vintageNew = "Vintage, newest", vintageOld = "Vintage, oldest", name = "Name"
        var id: String { rawValue }
    }
    private static let colors: [(String, String)] = [("All", ""), ("Red", "red"), ("White", "white"), ("Rosé", "rose"), ("Sparkling", "sparkling"), ("Sweet", "sweet")]

    @State private var color = ""
    @State private var sort: Sort = .recent
    @State private var priceBand = 0            // 0 any, 1 under $25, 2 $25–50, 3 $50–100, 4 $100+
    @State private var minRating = 0            // 0 any, 80, 85, 90
    @State private var vintage = ""             // "" any
    @AppStorage("jero.cellarAsList") private var asList = false

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
        case .rating: list.sort { ($0.roughRating ?? 0) > ($1.roughRating ?? 0) }
        case .vintageNew: list.sort { $0.vintageText > $1.vintageText }
        case .vintageOld: list.sort { $0.vintageText < $1.vintageText }
        case .name: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

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
                    Picker("Layout", selection: $asList) {
                        Image(systemName: "square.grid.2x2").tag(false)
                        Image(systemName: "list.bullet").tag(true)
                    }
                    .pickerStyle(.segmented).frame(width: 96)
                    if filtersOn {
                        Button("Clear filters") { withAnimation(.smooth(duration: 0.25)) { color = ""; priceBand = 0; minRating = 0; vintage = "" } }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.wine)
                    }
                }
                if list.isEmpty {
                    Text("No bottles match these filters.").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if asList {
                    GroupCard {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, b in
                            DetailLink(value: b) { row(b, last: i == list.count - 1) }.buttonStyle(RowPressStyle())
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], alignment: .center, spacing: 12) {
                        ForEach(list) { b in
                            DetailLink(value: b) { tile(b) }.buttonStyle(PressableStyle())
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
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(money(value, cur), filtersOn ? "value of these" : "valuation today", highlight: true)
                statTile(avg > 0 ? money(avg, cur) : "–", "average bottle")
                statTile("\(n)", n == 1 ? "bottle" : "bottles")
            }
            if !paidBottles.isEmpty {
                let diff = worthOfPaid - paid
                let nPaid = paidBottles.reduce(0) { $0 + $1.quantity }
                HStack(spacing: 10) {
                    statTile(money(paid / Double(max(1, nPaid)), "USD"), "you paid per bottle")
                    statTile(money(paid, "USD"), "total paid (\(nPaid) \(nPaid == 1 ? "bottle" : "bottles"))")
                    statTile((diff >= 0 ? "+" : "−") + money(abs(diff), cur), diff >= 0 ? "gain" : "loss")
                }
            }
        }
    }
    private func statTile(_ v: String, _ label: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(v).font(.system(size: 20, weight: .bold).monospacedDigit()).foregroundStyle(highlight ? Palette.onWine : Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11.5)).foregroundStyle(highlight ? Palette.onWine.opacity(0.8) : Palette.inkSoft).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(highlight ? Palette.wine : Palette.card))
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
        HStack(spacing: 12) {
            Thumb(photo: b.photo, style: b.wine.style).frame(width: 46, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Text([b.wine.region, b.wine.country].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                HStack(spacing: 8) {
                    Text("Vintage \(b.vintageText)").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.wine)
                    if let r = b.roughRating { Text("\(r) pts").font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft) }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(b.price.map { $0.averageText } ?? "–").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                if let p = b.paidUSD { Text("paid " + money(p, "USD")).font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.inkSoft) }
                Text("× \(b.quantity)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 72) } }
        .contentShape(Rectangle())
    }
}
