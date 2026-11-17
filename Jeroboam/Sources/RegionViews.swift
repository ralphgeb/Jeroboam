import SwiftUI

struct RegionListView: View {
    @State private var query = ""
    @State private var explore: MapRef? = nil

    var body: some View {
        let lib = ContentStore.shared.library
        let countries = lib.regions.filter { $0.kind == "country" }
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: "Atlas", title: "Regions & maps",
                             subtitle: "Most quality vineyards lie between 30° and 50° latitude, north and south. Tap a country to explore its regions.")
                WineMapView(mapID: "world", showCities: false)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture { explore = MapRef(id: "world", hl: []) }

                ForEach(countries.filter { query.isEmpty || matches($0) }) { c in
                    countrySection(c)
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .searchable(text: $query, prompt: "Search regions")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $explore) { ref in MapExplorer(mapID: ref.id, highlight: ref.hl) }
    }

    private func matches(_ c: Region) -> Bool {
        if c.name.localizedCaseInsensitiveContains(query) { return true }
        return children(of: c).contains { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func children(of c: Region) -> [Region] {
        (c.sub ?? []).compactMap { ContentStore.shared.region($0) }
    }

    private func countrySection(_ c: Region) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: c) {
                HStack(alignment: .center, spacing: 14) {
                    if let m = c.map {
                        WineMapView(mapID: m, showLabels: false, showCities: false)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .allowsHitTesting(false)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.name).font(.serif(22, .medium)).foregroundStyle(Palette.ink)
                        Text(c.grapes.prefix(4).compactMap { ContentStore.shared.grape($0)?.name }.joined(separator: " · "))
                            .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            let subs = children(of: c).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || c.name.localizedCaseInsensitiveContains(query) }
            ForEach(subs) { r in
                NavigationLink(value: r) {
                    HStack {
                        Text(r.name).font(.system(size: 15.5)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(r.grapes.prefix(2).compactMap { ContentStore.shared.grape($0)?.name }.joined(separator: ", "))
                            .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    .padding(.vertical, 11)
                    .padding(.leading, 78)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Hairline().padding(.leading, 78)
            }
        }
    }
}

struct RegionDetailView: View {
    let region: Region
    @Environment(GameProgress.self) private var progress
    @State private var explore: MapRef? = nil

    var body: some View {
        let r = region
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(r.kind == "country" ? "Country" : r.country, color: Palette.wine)
                    Text(r.name).font(.serif(36)).foregroundStyle(Palette.ink).lineLimit(2).minimumScaleFactor(0.7)
                    Text(rich(r.summary)).font(.system(size: 17)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }

                if let m = r.map {
                    let hl = Set(r.highlight ?? (r.kind == "country" ? [] : [r.id]))
                    let pinIDs = (r.kind == "country" ? (r.sub ?? []) : [])
                        .filter { id in MapGeometry.get(m)?.areas.contains { $0.id == id } ?? false }
                    VStack(alignment: .leading, spacing: 8) {
                        WineMapView(mapID: m, highlight: hl, pins: pinIDs) { id in
                            explore = MapRef(id: m, hl: [id])
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        HStack {
                            Text("Tap a region to explore").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                            Spacer()
                            Button {
                                explore = MapRef(id: m, hl: hl)
                            } label: {
                                Label("Full map", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Palette.wine)
                        }
                    }
                }

                if let c = r.climate {
                    infoRow(icon: "thermometer.medium", title: "Climate", text: c)
                }

                let grapes = ContentStore.shared.grapes(inRegion: r.id)
                if !grapes.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(text: "Key grapes")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(grapes) { g in
                                    NavigationLink(value: g) {
                                        VStack(spacing: 8) {
                                            GrapeCluster(berry: g.berry, leaf: false, seed: g.name.count).frame(width: 60, height: 60)
                                            Text(g.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
                                                .lineLimit(2).multilineTextAlignment(.center)
                                        }
                                        .frame(width: 96)
                                        .padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }

                if let s = r.styles { textBlock("Styles", s) }
                if let c = r.classification { textBlock("Classification", c) }
                if let l = ContentStore.shared.label(forRegion: r.id) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(text: "How to read the label")
                        LabelDecoderCard(label: l)
                    }
                }

                if let facts = r.facts, !facts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "Worth knowing")
                        ForEach(facts, id: \.self) { f in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle().fill(Palette.wine).frame(width: 4.5, height: 4.5).offset(y: -3)
                                Text(rich(f)).font(.system(size: 15.5)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                let subs = (r.sub ?? []).compactMap { ContentStore.shared.region($0) }
                if !subs.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: r.kind == "country" ? "Regions" : "Inside \(r.name)").padding(.bottom, 8)
                        let pinned = (r.kind == "country" ? (r.sub ?? []) : [])
                            .filter { id in r.map.flatMap { MapGeometry.get($0) }?.areas.contains { $0.id == id } ?? false }
                        ForEach(subs) { s in
                            NavigationLink(value: s) {
                                HStack(spacing: 12) {
                                    if let n = pinned.firstIndex(of: s.id), let m = r.map, let a = MapGeometry.get(m)?.areas.first(where: { $0.id == s.id }) {
                                        Text("\(n + 1)").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                                            .frame(width: 26, height: 26)
                                            .background(Circle().fill(Palette.mapColor(a.color).mix(with: .black, 0.15)))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                                        Text(s.grapes.prefix(3).compactMap { ContentStore.shared.grape($0)?.name }.joined(separator: " · "))
                                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Hairline()
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $explore) { ref in MapExplorer(mapID: ref.id, highlight: ref.hl) }
        .onAppear {
            progress.noteViewed(region: r.id)
            #if DEBUG
            if DebugScreens.screen == "explorer", r.id == "bordeaux" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { explore = MapRef(id: "bordeaux", hl: ["pauillac"]) }
            }
            #endif
        }
    }

    private func infoRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Palette.wine).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(rich(text)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func textBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            Text(rich(text)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
