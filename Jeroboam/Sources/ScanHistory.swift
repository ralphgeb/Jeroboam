import SwiftUI

struct HistoryRoute: Hashable {}

private struct HistoryItem: Identifiable {
    let entry: WineDB.Entry
    var id: String { WineDB.key(entry.identity) }
}

/// Every wine you have ever scanned, with the date: removing a bottle from the cellar or a tasting never removes it from here.
struct ScanHistoryView: View {
    @State private var items: [WineDB.Entry] = []
    @State private var open: HistoryItem? = nil
    @State private var query = ""

    private var shown: [WineDB.Entry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? items : items.filter { Search.matches(q, $0.identity.name, $0.identity.producer, $0.identity.region, $0.identity.country, $0.identity.vintage) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(eyebrow: "Your wines", title: "Everything you've scanned",
                             subtitle: "\(items.count) \(items.count == 1 ? "wine" : "wines"), newest first. Removing a bottle from your cellar never removes it from here.")
                if !items.isEmpty { SearchBar(text: $query, prompt: "Search your scans") }
                if items.isEmpty {
                    Text("Wines you scan will be listed here with the date you scanned them.").font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    GroupCard {
                        ForEach(Array(shown.enumerated()), id: \.offset) { i, e in
                            Button { open = HistoryItem(entry: e) } label: { row(e, last: i == shown.count - 1) }.buttonStyle(RowPressStyle())
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
        .onAppear { items = WineDB.shared.history() }
        .sheet(item: $open) { item in HistoryDetail(entry: item.entry) }
    }

    private func row(_ e: WineDB.Entry, last: Bool) -> some View {
        let w = e.identity
        return HStack(spacing: 12) {
            Group {
                if let d = e.thumb, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill() }
                else { ZStack { styleColor(w.style).opacity(0.14); WineGlass(color: styleColor(w.style), fill: 0.5).padding(10) } }
            }
            .frame(width: 46, height: 58).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(w.name).font(.jero(size: 15, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Text([w.producer, w.region, w.country].filter { !$0.isEmpty }.joined(separator: " · ")).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                Text("Scanned " + (e.lastSeen ?? e.saved).formatted(date: .abbreviated, time: .omitted) + ((e.scans ?? 1) > 1 ? " · \(e.scans ?? 1) times" : ""))
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.wine).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(w.vintage.isEmpty ? "NV" : w.vintage).font(.jero(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                if let p = e.price { Text(p.averageText).font(.jero(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSoft) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 72) } }
        .contentShape(Rectangle())
    }
}

private struct HistoryDetail: View {
    let entry: WineDB.Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalStore.self) private var journal
    @State private var added = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let d = entry.thumb, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    }
                    ScreenHeader(eyebrow: "Scanned " + (entry.lastSeen ?? entry.saved).formatted(date: .long, time: .omitted),
                                 title: entry.identity.name, subtitle: entry.identity.producer)
                    WineGlance(wine: entry.identity, price: entry.price)
                    WineInfoCard(wine: entry.identity)
                    if let p = entry.price { PriceCard(price: p, wine: entry.identity) }
                    ScoreLinkCard(wine: entry.identity, score: entry.identity.dbScore, link: entry.identity.dbScoreLink)
                    Button {
                        var b = CellarBottle(); b.wine = entry.identity; b.price = entry.price
                        if let d = entry.thumb, let img = UIImage(data: d) { b.photo = journal.savePhoto(img, id: b.id) }
                        journal.upsert(b); added = true
                    } label: { Label(added ? "Added to your cellar" : "Add to cellar", systemImage: added ? "checkmark" : "plus") }
                        .buttonStyle(PrimaryButtonStyle(enabled: !added)).disabled(added)
                }
                .padding(.horizontal, Metrics.margin).padding(.top, 20).padding(.bottom, 30)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .environment(\.hasRail, false)
    }
}
