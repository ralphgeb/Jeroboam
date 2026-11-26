import SwiftUI

struct CollectionRoute: Hashable {}

/// What you have tried: only wines TASTED in the journal count (a bottle sitting in the cellar does not).
/// Grapes by grape id, places by region id, countries by name, and the classic wines of "Wines of the world" by id;
/// each with the tastings that stamped it, oldest first.
struct Tried {
    var grapes: [String: [JournalEntry]] = [:]
    var regions: [String: [JournalEntry]] = [:]
    var countries: [String: [JournalEntry]] = [:]
    var classics: [String: [JournalEntry]] = [:]

    static func countryKey(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().trimmingCharacters(in: .whitespaces)
    }
    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
    }

    // worked out once per change of the tastings (the lists ask for it on every card)
    private static var cacheKey: Int? = nil
    private static var cache = Tried()

    static func of(_ entries: [JournalEntry]) -> Tried {
        var h = Hasher()
        for e in entries { h.combine(e.id); h.combine(e.wine.name); h.combine(e.wine.region); h.combine(e.wine.country); h.combine(e.wine.grapes) }
        let k = h.finalize()
        if k == cacheKey { return cache }
        let t = build(entries)
        cache = t; cacheKey = k
        return t
    }

    private static func build(_ entries: [JournalEntry]) -> Tried {
        var t = Tried()
        let classics = ContentStore.shared.library.wines ?? []
        for e in entries.sorted(by: { $0.date < $1.date }) where !e.wine.name.isEmpty || !e.wine.grapes.isEmpty {
            let gids = Set(e.wine.grapes.compactMap(matchGrape).map(\.id))
            for g in gids { t.grapes[g, default: []].append(e) }
            if !e.wine.country.isEmpty { t.countries[countryKey(e.wine.country), default: []].append(e) }
            let region = e.wine.region.isEmpty ? nil : ContentStore.shared.regionMatching(e.wine.region, country: e.wine.country)
            if let r = region, r.kind != "country" { t.regions[r.id, default: []].append(e) }
            // a classic: its name on the label, or its place with one of its grapes
            let label = fold(e.wine.name + " " + e.wine.region)
            for w in classics {
                let byName = label.contains(fold(w.name))
                let byPlace = region?.id == w.region && (gids.isEmpty || !gids.isDisjoint(with: w.grapes))
                if byName || byPlace { t.classics[w.id, default: []].append(e) }
            }
        }
        return t
    }
}

/// A small round tick on anything you have tasted.
struct TriedTick: View {
    var size: CGFloat = 20
    var body: some View {
        Image(systemName: "checkmark").font(.system(size: size * 0.48, weight: .bold)).foregroundStyle(Palette.onWine)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.wine))
            .overlay(Circle().strokeBorder(Palette.card, lineWidth: 1.5))
            .accessibilityLabel("Tasted")
    }
}

/// Collection milestones; each is also a badge in Achievements.
struct CollectionMilestone: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let target: Int
    let count: (Tried) -> Int

    static let bordeaux = ["cabernet-sauvignon", "merlot", "cabernet-franc", "petit-verdot", "malbec"]

    static let all: [CollectionMilestone] = [
        CollectionMilestone(id: "tried-grapes-5", title: "First five grapes", detail: "Taste 5 different grapes", icon: "leaf", target: 5) { $0.grapes.count },
        CollectionMilestone(id: "tried-grapes-15", title: "Grape explorer", detail: "Taste 15 different grapes", icon: "leaf.fill", target: 15) { $0.grapes.count },
        CollectionMilestone(id: "tried-grapes-30", title: "Ampelophile", detail: "Taste 30 different grapes", icon: "laurel.leading", target: 30) { $0.grapes.count },
        CollectionMilestone(id: "bordeaux-five", title: "The Bordeaux five", detail: "Taste all five Bordeaux red grapes", icon: "seal.fill", target: 5) { t in
            bordeaux.filter { t.grapes[$0] != nil }.count
        },
        CollectionMilestone(id: "tried-places-10", title: "Ten places", detail: "Taste wines from 10 regions", icon: "mappin.and.ellipse", target: 10) { $0.regions.count },
        CollectionMilestone(id: "tried-countries-8", title: "Passport stamps", detail: "Taste wines from 8 countries", icon: "globe.europe.africa", target: 8) { $0.countries.count },
        CollectionMilestone(id: "classics-5", title: "Classic taster", detail: "Taste 5 classic wines", icon: "wineglass", target: 5) { $0.classics.count },
        CollectionMilestone(id: "classics-20", title: "Connoisseur", detail: "Taste 20 classic wines", icon: "crown", target: 20) { $0.classics.count },
    ]
}

/// The stamp album: every grape, country and classic wine, in colour once you have tasted it. Lives in the Journal and in
/// your Profile. On a wide window (the Duo opened sideways) the album sits on the left and the stamp you pick on the right.
struct CollectionView: View {
    @Environment(JournalStore.self) private var journal
    @Environment(GameProgress.self) private var progress
    @Environment(\.windowWidth) private var width
    @State private var tab = 0          // 0 grapes, 1 countries, 2 classics
    @State private var picked: Stamp? = nil
    @State private var sheet: Stamp? = nil

    private var wide: Bool { width >= AdaptiveLayout.twoPaneThreshold }
    private var tried: Tried { Tried.of(journal.persist ? journal.entries : []) }

    struct Stamp: Identifiable, Hashable {
        enum Kind: Hashable { case grape, country, classic }
        let kind: Kind
        let id: String
        let title: String
        let subtitle: String
    }

    private var grapes: [Grape] { ContentStore.shared.library.grapes.sorted { $0.name < $1.name } }
    private var countries: [Region] {
        let atlas = ContentStore.shared.library.regions.filter { $0.kind == "country" }
        let extra = ContentStore.shared.extraRegions.filter { $0.kind == "country" }
        var seen = Set<String>()
        return (atlas + extra).filter { seen.insert(Tried.countryKey($0.country.isEmpty ? $0.name : $0.country)).inserted }
            .sorted { $0.name < $1.name }
    }
    private var classics: [Wine] { ContentStore.shared.library.wines ?? [] }
    private func key(_ c: Region) -> String { Tried.countryKey(c.country.isEmpty ? c.name : c.country) }

    var body: some View {
        let t = tried
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: "Your collection", title: "Collection",
                             subtitle: "Every grape, country and classic wine you have tasted. Taste one in the journal to stamp it.")
                HStack(spacing: 10) {
                    counter(0, "Grapes", t.grapes.count, grapes.count)
                    counter(1, "Countries", countries.filter { t.countries[key($0)] != nil }.count, countries.count)
                    counter(2, "Classics", t.classics.count, classics.count)
                }
                milestones(t)
                Picker("Collection", selection: $tab) {
                    Text("Grapes").tag(0)
                    Text("Countries").tag(1)
                    Text("Classics").tag(2)
                }
                .pickerStyle(.segmented)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12, alignment: .top)], spacing: 16) {
                    switch tab {
                    case 0:
                        ForEach(grapes) { g in
                            stampButton(Stamp(kind: .grape, id: g.id, title: g.name, subtitle: g.berry == .black ? "Black grape" : "White grape"),
                                        on: t.grapes[g.id] != nil) { GrapeBadge(grape: g, size: 52, disc: false) }
                        }
                    case 1:
                        ForEach(countries) { c in
                            stampButton(Stamp(kind: .country, id: key(c), title: c.name, subtitle: "Country"), on: t.countries[key(c)] != nil) {
                                Text(Flag.emoji(for: c.country.isEmpty ? c.name : c.country)).font(.system(size: 34))
                            }
                        }
                    default:
                        ForEach(classics) { w in
                            stampButton(Stamp(kind: .classic, id: w.id, title: w.name, subtitle: w.regionInfo?.name ?? ""), on: t.classics[w.id] != nil) {
                                WineGlassIcon(wine: w, height: 44)
                            }
                        }
                    }
                }
                if tab == 1 && !t.regions.isEmpty {
                    // the regions inside those countries, as a list of names
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Regions you have tasted", detail: "\(t.regions.count)")
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(t.regions.keys.sorted(), id: \.self) { id in
                                Text((ContentStore.shared.region(id) ?? ContentStore.shared.extraRegions.first { $0.id == id })?.name ?? id)
                                    .font(.jero(size: 13.5, weight: .medium)).foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Palette.wineSoft))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
        .onAppear { progress.checkAchievements() }
        .rightPane {
            if let s = picked { StampDetail(stamp: s).id(s) } else { emptyDetail }
        }
        .sheet(item: $sheet) { s in
            NavigationStack { StampDetail(stamp: s) }
                .presentationDetents([.medium, .large])
                .plusSheetHost()
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 10) {
            Image(systemName: "seal").font(.system(size: 40, weight: .light)).foregroundStyle(Palette.inkFaint)
            Text("Pick a stamp").font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("See when you tasted it and with which wine.").font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func counter(_ i: Int, _ label: String, _ n: Int, _ of: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { tab = i } } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(n)").font(.numeric(22, .semibold)).foregroundStyle(Palette.ink)
                    + Text(" / \(of)").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                Text(label).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule().fill(Palette.wine).frame(width: max(4, geo.size.width * CGFloat(n) / CGFloat(max(1, of))))
                    }
                }
                .frame(height: 4).padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tab == i ? Palette.wineSoft : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tab == i ? Palette.wine.opacity(0.5) : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func milestones(_ t: Tried) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Milestones", detail: "\(CollectionMilestone.all.filter { $0.count(t) >= $0.target }.count)/\(CollectionMilestone.all.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CollectionMilestone.all) { m in
                        let n = min(m.target, m.count(t))
                        let got = progress.data.achievements.contains(m.id) || n >= m.target
                        Button {
                            if got, let a = Achievement.all.first(where: { $0.id == m.id }) {
                                BadgeCelebration.shared.play(a, date: progress.data.achievementDates?[m.id])
                            }
                        } label: {
                            VStack(spacing: 6) {
                                if let a = Achievement.all.first(where: { $0.id == m.id }) {
                                    AchievementBadge(achievement: a, unlocked: got, size: 64).frame(width: 64, height: 64)
                                }
                                Text(m.title).font(.jero(size: 12, weight: .semibold)).foregroundStyle(got ? Palette.ink : Palette.inkSoft)
                                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                                Text(got ? "Earned" : "\(n) of \(m.target)").font(.jero(size: 11)).foregroundStyle(got ? Palette.wine : Palette.inkFaint)
                            }
                            .frame(width: 96)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func stampButton<Art: View>(_ s: Stamp, on: Bool, @ViewBuilder art: () -> Art) -> some View {
        Button {
            Haptics.tap()
            if wide { picked = s } else { sheet = s }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    StampShape().fill(on ? Color(hex: "#FBF3E4") : Palette.cardAlt)
                    StampShape().stroke(on ? Palette.bordeaux.opacity(0.35) : Palette.line, lineWidth: 0.6)
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .strokeBorder(on ? Palette.bordeaux.opacity(0.5) : Palette.line, lineWidth: 0.8).padding(6)
                    art().saturation(on ? 1 : 0).opacity(on ? 1 : 0.35)
                }
                .frame(width: 78, height: 92)
                .rotationEffect(.degrees(on ? -3 : 0))
                .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1.5, y: 1)
                .overlay(alignment: .topTrailing) { if on { TriedTick(size: 20).offset(x: 6, y: -6) } }
                .overlay { if picked == s && wide { RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.wine, lineWidth: 2).padding(-4) } }
                Text(s.title).font(.jero(size: 11.5, weight: on ? .semibold : .regular)).foregroundStyle(on ? Palette.ink : Palette.inkSoft)
                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.title + (on ? ", tasted" : ", not tasted yet"))
    }
}

/// One stamp: when you first tasted it, every tasting that counts, and its page in the atlas.
struct StampDetail: View {
    let stamp: CollectionView.Stamp
    @Environment(JournalStore.self) private var journal
    @State private var open: Opened? = nil

    private struct Opened: Identifiable { let id = UUID(); let value: AnyHashable }

    private var tastings: [JournalEntry] {
        let t = Tried.of(journal.persist ? journal.entries : [])
        switch stamp.kind {
        case .grape: return t.grapes[stamp.id] ?? []
        case .country: return t.countries[stamp.id] ?? []
        case .classic: return t.classics[stamp.id] ?? []
        }
    }

    private var page: AnyHashable? {
        let lib = ContentStore.shared.library
        switch stamp.kind {
        case .grape: return lib.grapes.first { $0.id == stamp.id }.map { AnyHashable($0) }
        case .classic: return lib.wines?.first { $0.id == stamp.id }.map { AnyHashable($0) }
        case .country:
            return (lib.regions + ContentStore.shared.extraRegions).first {
                $0.kind == "country" && Tried.countryKey($0.country.isEmpty ? $0.name : $0.country) == stamp.id
            }.map { AnyHashable($0) }
        }
    }

    var body: some View {
        let list = tastings
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: stamp.subtitle, title: stamp.title,
                             subtitle: list.first.map { "First tasted on " + $0.date.formatted(date: .long, time: .omitted) }
                                 ?? "Not tasted yet. Taste one in the journal to stamp it.")
                if let p = page {
                    Button { open = Opened(value: p) } label: {
                        Label(stamp.kind == .grape ? "Open the grape page" : (stamp.kind == .country ? "Open the country page" : "Open the wine page"),
                              systemImage: "book").font(.jero(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(Palette.wine)
                            .background(Capsule().strokeBorder(Palette.wine.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if !list.isEmpty {
                    SectionTitle(text: list.count == 1 ? "Your tasting" : "Your tastings", detail: "\(list.count)")
                    VStack(spacing: 0) {
                        ForEach(list.reversed()) { e in
                            Button { open = Opened(value: AnyHashable(e)) } label: {
                                HStack(spacing: 12) {
                                    Thumb(photo: e.photo, style: e.wine.style).frame(width: 44, height: 54)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.title).font(.jero(size: 15, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                                        Text(e.date.formatted(date: .abbreviated, time: .omitted) + (e.isBlind ? " · blind" : ""))
                                            .font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer(minLength: 6)
                                    Text("\(e.points)").font(.numeric(16, .semibold)).foregroundStyle(Palette.wine)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RowPressStyle())
                            if e.id != list.first?.id { Hairline().padding(.leading, 70) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .sheet(item: $open) { o in
            NavigationStack { DetailDestination(value: o.value) }
                .plusSheetHost()
        }
    }
}

/// The way into the Collection from the Journal and the Profile: three counts and the stamps you have.
struct CollectionCard: View {
    @Environment(JournalStore.self) private var journal

    var body: some View {
        let t = Tried.of(journal.persist ? journal.entries : [])
        NavigationLink(value: CollectionRoute()) {
            HStack(spacing: 14) {
                ZStack {
                    StampShape().fill(Color(hex: "#FBF3E4"))
                    StampShape().stroke(Palette.bordeaux.opacity(0.35), lineWidth: 0.6)
                    Image(systemName: "seal.fill").font(.system(size: 18)).foregroundStyle(Palette.bordeaux)
                }
                .frame(width: 40, height: 48).rotationEffect(.degrees(-5))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your collection").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("\(t.grapes.count) grapes · \(t.countries.count) countries · \(t.classics.count) classics tasted")
                        .font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Profile: collection and achievements as two cards

struct AchievementsRoute: Hashable {}

/// Profile: "Your collection" and "Achievements" side by side, each a tap away from its full page.
struct CollectionAndAchievementsTiles: View {
    @Environment(JournalStore.self) private var journal
    @Environment(GameProgress.self) private var progress
    /// Duo sideways: the card shown on the right (0 collection, 1 achievements) and what a tap does instead of opening a page.
    var selected: Int? = nil
    var onPick: ((Int) -> Void)? = nil

    var body: some View {
        let t = Tried.of(journal.persist ? journal.entries : [])
        let got = progress.data.achievements
        // the latest badges first, as a little fan on the card
        let recent = Achievement.all.filter { got.contains($0.id) }
            .sorted { (progress.data.achievementDates?[$0.id] ?? .distantPast) > (progress.data.achievementDates?[$1.id] ?? .distantPast) }
        HStack(alignment: .top, spacing: 12) {
            link(0, CollectionRoute()) {
                tile(0, title: "Your collection",
                     detail: "\(t.grapes.count) grapes · \(t.countries.count) countries · \(t.classics.count) classics") {
                    HStack(spacing: -10) {
                        ForEach(0..<3, id: \.self) { i in
                            ZStack {
                                StampShape().fill(Color(hex: ["#FBF3E4", "#F3E6EA", "#EAF0E4"][i]))
                                StampShape().stroke(Palette.bordeaux.opacity(0.35), lineWidth: 0.6)
                                Image(systemName: ["seal.fill", "globe.europe.africa.fill", "star.fill"][i])
                                    .font(.system(size: 15)).foregroundStyle(Palette.bordeaux)
                            }
                            .frame(width: 38, height: 46).rotationEffect(.degrees([-8, 2, 10][i]))
                        }
                    }
                }
            }
            link(1, AchievementsRoute()) {
                tile(1, title: "Achievements", detail: "\(got.count) of \(Achievement.all.count) earned") {
                    HStack(spacing: -14) {
                        if recent.isEmpty {
                            AchievementBadge(achievement: Achievement.all[0], unlocked: false, size: 48).frame(width: 48, height: 48)
                        } else {
                            ForEach(recent.prefix(3)) { a in
                                AchievementBadge(achievement: a, unlocked: true, size: 48).frame(width: 48, height: 48)
                            }
                        }
                    }
                }
            }
        }
    }

    /// A page to open on a phone; on the Duo sideways a tap shows it on the right instead.
    @ViewBuilder private func link<R: Hashable, L: View>(_ i: Int, _ route: R, @ViewBuilder label: () -> L) -> some View {
        if let onPick {
            Button { onPick(i) } label: { label() }.buttonStyle(PressableStyle())
        } else {
            NavigationLink(value: route) { label() }.buttonStyle(PressableStyle())
        }
    }

    private func tile<Art: View>(_ i: Int, title: String, detail: String, @ViewBuilder art: () -> Art) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            art().frame(height: 52, alignment: .leading)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(title).font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                }
                Text(detail).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .strokeBorder(selected == i ? Palette.wine : Palette.line.opacity(0.7), lineWidth: selected == i ? 1.5 : 0.5))
        .contentShape(Rectangle())
    }
}

/// Every badge, earned or still to win (tap an earned one to see it again).
struct AchievementsView: View {
    @Environment(GameProgress.self) private var progress

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "Profile", title: "Achievements",
                             subtitle: "\(progress.data.achievements.count) of \(Achievement.all.count) earned. Tap a badge you have won to see it again.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12, alignment: .top)], alignment: .center, spacing: 18) {
                    ForEach(Achievement.all) { a in
                        let got = progress.data.achievements.contains(a.id)
                        Button {
                            if got { BadgeCelebration.shared.play(a, date: progress.data.achievementDates?[a.id]) }
                        } label: {
                            VStack(spacing: 6) {
                                AchievementBadge(achievement: a, unlocked: got, size: 78)
                                    .frame(width: 78, height: 78)
                                Text(a.title).font(.jero(size: 12, weight: .semibold)).foregroundStyle(got ? Palette.ink : Palette.inkSoft)
                                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                                Text(a.detail).font(.jero(size: 10.5)).foregroundStyle(Palette.inkFaint)
                                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
    }
}
