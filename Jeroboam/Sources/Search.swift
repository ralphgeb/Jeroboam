import SwiftUI

/// One way of matching text everywhere in the app: capitals, accents and punctuation do not matter ("cotes du rhone" finds
/// "Côtes du Rhône"), every word you type must start a word of the text, and short typing finds long names.
enum Search {
    static func fold(_ s: String) -> String {
        let f = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
        var out = ""
        var lastSpace = true
        for ch in f {
            if ch.isLetter || ch.isNumber { out.append(ch); lastSpace = false }
            else if !lastSpace { out.append(" "); lastSpace = true }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func matches(_ query: String, _ fields: String?...) -> Bool {
        let q = fold(query).split(separator: " ").map(String.init)
        guard !q.isEmpty else { return true }
        let text = fold(fields.compactMap { $0 }.joined(separator: " "))
        let words = text.split(separator: " ").map(String.init)
        return q.allSatisfy { t in words.contains { $0.hasPrefix(t) } || (t.count >= 3 && text.contains(t)) }
    }

    /// How well a name fits what was typed: lower is better (exact, then starting with it, then the rest).
    static func rank(_ query: String, _ name: String) -> Int {
        let q = fold(query), n = fold(name)
        if n == q { return 0 }
        if n.hasPrefix(q) { return 1 }
        if n.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 2 }
        return 3
    }
}

/// The search field used on every list page: always visible, with a clear button. (The system search drawer is hidden by the
/// foldable layout, which has no navigation bar, and only appears after pulling down on a phone.)
struct SearchBar: View {
    @Binding var text: String
    var prompt = "Search"
    var onSubmit: (() -> Void)? = nil
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.inkSoft)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).focused($focused)
                .font(.system(size: 16)).foregroundStyle(Palette.ink)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button { text = ""; focused = true } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Palette.inkFaint)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.cardAlt))
    }
}

/// What the Atlas search finds: places with a small map of where they are, and grapes.
struct AtlasSearchResults: View {
    let query: String
    /// Only the places of "Maps beyond the atlas" (no grapes).
    var onlyExtras = false

    /// The places that match (atlas and beyond), best first. Static so it can be tested.
    static func places(_ query: String, onlyExtras: Bool = false) -> [Region] {
        let c = ContentStore.shared
        var seen = Set<String>()
        let all = ((onlyExtras ? [] : c.library.regions) + c.extraRegions).filter { seen.insert($0.id).inserted }
        let hits = all.filter { r in
            Search.matches(query, r.name, r.country) || Search.matches(query, r.name, (r.local ?? []).joined(separator: " "))
        }
        return hits.sorted { a, b in
            let ra = Search.rank(query, a.name), rb = Search.rank(query, b.name)
            if ra != rb { return ra < rb }
            let ka = a.kind == "country" ? 0 : (a.kind == "region" ? 1 : 2), kb = b.kind == "country" ? 0 : (b.kind == "region" ? 1 : 2)
            if ka != kb { return ka < kb }
            return a.name < b.name
        }
    }

    static func grapes(_ query: String) -> [Grape] {
        ContentStore.shared.library.grapes.filter { Search.matches(query, $0.name, ($0.aka ?? []).joined(separator: " ")) }
            .sorted { Search.rank(query, $0.name) < Search.rank(query, $1.name) }
    }

    private var places: [Region] { Self.places(query, onlyExtras: onlyExtras) }
    private var grapes: [Grape] { onlyExtras ? [] : Self.grapes(query) }

    var body: some View {
        let p = places, g = grapes
        VStack(alignment: .leading, spacing: 22) {
            if p.isEmpty && g.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.inkFaint)
                    Text("Nothing found for \u{201C}\(query)\u{201D}").font(.jero(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                    Text("Try a region, an appellation, a country or a grape.").font(.jero(size: 13)).foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            if !p.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Places", detail: "\(p.count)")
                    LazyVStack(spacing: 10) {
                        ForEach(Array(p.prefix(40).enumerated()), id: \.element.id) { _, r in
                            DetailLink(value: r) { PlaceResultRow(region: r) }.buttonStyle(PressableStyle())
                        }
                    }
                }
            }
            if !g.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Grapes", detail: "\(g.count)")
                    GroupCard {
                        ForEach(Array(g.prefix(12).enumerated()), id: \.element.id) { i, gr in
                            NavigationLink(value: gr) {
                                IconRow(title: gr.name, detail: gr.berry == .black ? "Black grape" : "White grape", last: i == min(g.count, 12) - 1) {
                                    GrapeBadge(grape: gr, size: 26)
                                }
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                }
            }
        }
    }
}

/// A search hit: a small map with the place marked, its name and where it is.
struct PlaceResultRow: View {
    let region: Region
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let m = region.map {
                    WineMapView(mapID: m, highlight: Set(region.highlight ?? []), showLabels: false, showCities: false, fill: true, thumbnail: region.kind == "country", tightThumb: true)
                        .allowsHitTesting(false)
                } else {
                    Palette.cardAlt
                }
            }
            .frame(width: 92, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(region.name).font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(region.kind == "country" ? "Country" : region.country).font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                if !region.summary.isEmpty {
                    Text(region.summary).font(.jero(size: 12)).foregroundStyle(Palette.inkFaint).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}
