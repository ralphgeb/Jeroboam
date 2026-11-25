import SwiftUI

/// The lower half of the Journal: palate passport, tonight's challenge, how it works and classics to try.
struct JournalExtras: View {
    @Environment(JournalStore.self) private var journal
    var onBlind: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if journal.cellar.isEmpty && journal.entries.isEmpty {
                howItWorks
            } else {
                passport
            }
            challenge
            classics
        }
    }

    // MARK: passport

    private var countries: [String] {
        let all = journal.cellar.map(\.wine.country) + journal.entries.map(\.wine.country)
        return Array(Set(all.filter { !$0.isEmpty })).sorted()
    }
    private var grapes: [(String, Int)] {
        var counts: [String: Int] = [:]
        for g in journal.cellar.flatMap(\.wine.grapes) + journal.entries.flatMap(\.wine.grapes) { counts[g, default: 0] += 1 }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    private static let wineCountries = 15

    private var passport: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your palate")
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(countries.count)").font(.jero(size: 28, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                    Text("of \(Self.wineCountries) wine countries explored").font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.cardAlt)
                        Capsule().fill(Palette.wine).frame(width: geo.size.width * min(1, CGFloat(countries.count) / CGFloat(Self.wineCountries)))
                    }
                }
                .frame(height: 6)
                if !countries.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(countries, id: \.self) { c in
                            Text(c).font(.jero(size: 12.5, weight: .medium)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Palette.wineSoft))
                        }
                    }
                }
                if !grapes.isEmpty {
                    Hairline()
                    Text("Most poured grapes").font(.jero(size: 13, weight: .medium)).foregroundStyle(Palette.inkSoft)
                    let top = grapes.first?.1 ?? 1
                    ForEach(grapes, id: \.0) { g, n in
                        let known = matchGrape(g)
                        HStack(spacing: 10) {
                            if let known { GrapeBadge(grape: known, size: 24, disc: false) } else { Image(systemName: "leaf").frame(width: 24) }
                            Text(g).font(.system(size: 14)).foregroundStyle(Palette.ink).frame(width: 128, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                Capsule().fill(Palette.wine.opacity(0.75)).frame(width: max(6, geo.size.width * CGFloat(n) / CGFloat(top)))
                            }
                            .frame(height: 6)
                            Text("\(n)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSoft).frame(width: 18, alignment: .trailing)
                        }
                    }
                }
            }
            .cardStyle(padding: 16)
        }
    }

    // MARK: how it works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "How it works")
            GroupCard {
                step(1, "camera.viewfinder", "Snap the label", "Jero reads it and finds the wine, its grapes and region.", last: false)
                step(2, "tag", "See what it’s worth", "An average price from Wine-Searcher or CellarTracker.", last: false)
                step(3, "square.stack.3d.up", "Build your cellar", "Keep count of bottles and what your cellar is worth.", last: false)
                step(4, "eye.slash", "Or taste blind", "Guess the grape and country, then reveal and get a score out of 100.", last: true)
            }
        }
    }

    private func step(_ n: Int, _ icon: String, _ title: String, _ text: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Palette.wineSoft)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Palette.wine)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.jero(size: 15.5, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(text).font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("\(n)").font(.jero(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 66) } }
    }

    // MARK: tonight's challenge

    private static let challenges: [(String, String)] = [
        ("Sauvignon Blanc vs Chardonnay", "Pour one of each blind. Look for grass and grapefruit versus apple, butter or oak."),
        ("Old World or New World?", "Taste a French and a Californian Pinot Noir. Which is earthier, which is riper?"),
        ("Find the oak", "Compare an unoaked Chablis with a barrel-fermented Chardonnay. Note vanilla and toast."),
        ("Tannin ladder", "Line up Pinot Noir, Merlot and Cabernet Sauvignon. Rank them by how dry your gums feel."),
        ("Acid test", "Taste a Riesling and a Viognier. Which makes your mouth water more?"),
        ("Bubbles side by side", "Prosecco against Champagne: fruit and flowers, or brioche and toast?"),
        ("Guess the country", "Ask a friend to pour a Malbec, Shiraz or Rioja. Use structure and fruit to place it."),
    ]

    private var challenge: some View {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let c = Self.challenges[day % Self.challenges.count]
        return Button(action: onBlind) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TONIGHT’S CHALLENGE").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.onWine.opacity(0.75))
                    Text(c.0).font(.jero(size: 18, weight: .semibold)).foregroundStyle(Palette.onWine)
                    Text(c.1).font(.jero(size: 13.5)).foregroundStyle(Palette.onWine.opacity(0.85)).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Start a blind tasting", systemImage: "arrow.right").labelStyle(TrailingIconLabel())
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.onWine).padding(.top, 4)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: -4) {
                    WineGlass(color: Color(hex: "#E8D27A"), fill: 0.5, outline: .white).frame(width: 22, height: 44)
                    WineGlass(color: Color(hex: "#F3E7B0"), fill: 0.5, outline: .white).frame(width: 22, height: 44)
                }
                .opacity(0.95)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(LinearGradient(colors: [Palette.bordeaux, Palette.bordeaux.mix(with: .black, 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: classics

    private var classics: some View {
        let ids = ["champagne-brut", "sancerre", "chablis", "red-burgundy", "chateauneuf", "barolo", "rioja-reserva", "mendoza-malbec", "marlborough-sb", "napa-cab"]
        let all = ContentStore.shared.library.wines ?? []
        let picks = ids.compactMap { id in all.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(text: "Classics to try")
                Spacer()
                Text("Tap to learn more").font(.jero(size: 12)).foregroundStyle(Palette.inkFaint)
            }
            ScrollView(.horizontal) {
                // lazy: only the cards on screen are built when the Journal tab opens
                LazyHStack(spacing: 12) {
                    ForEach(picks) { w in
                        NavigationLink(value: w) { ClassicCard(wine: w) }.buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Metrics.margin).contentMargins(.horizontal, Metrics.margin, for: .scrollContent)
        }
    }
}

private struct ClassicCard: View {
    let wine: Wine
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                (Color(hex: wine.colorInfo?.hex ?? "#8E1E3F")).opacity(0.16)
                WineGlassIcon(wine: wine, height: 62)
            }
            .frame(height: 96)
            VStack(alignment: .leading, spacing: 3) {
                Text(wine.name).font(.jero(size: 14.5, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2, reservesSpace: true)
                Text(wine.country).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 150, alignment: .leading)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}

struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}
