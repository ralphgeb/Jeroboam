import SwiftUI

struct RegionListView: View {
    @State private var query = ""
    @State private var explore: MapRef? = nil

    var body: some View {
        let lib = ContentStore.shared.library
        let countries = lib.regions.filter { $0.kind == "country" }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: "Atlas", title: "Regions & maps",
                             subtitle: "Pick a country to see its wine regions on the map.")
                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Countries", detail: "\(countries.count)")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(countries) { c in
                                NavigationLink(value: c) { countryCard(c) }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                } else {
                    let hits = lib.regions.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.country.localizedCaseInsensitiveContains(query) }
                    GroupCard {
                        ForEach(Array(hits.prefix(60).enumerated()), id: \.element.id) { i, r in
                            NavigationLink(value: r) {
                                IconRow(title: r.name, detail: r.kind == "country" ? "Country" : r.country, last: i == min(hits.count, 60) - 1) {
                                    Image(systemName: r.kind == "country" ? "globe.europe.africa" : "mappin").font(.system(size: 15)).foregroundStyle(Palette.wine)
                                }
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.bottom, 24)
        }
        .background(Palette.paper.ignoresSafeArea())
        .searchable(text: $query, prompt: "Search regions")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $explore) { ref in MapExplorer(mapID: ref.id, highlight: ref.hl) }
    }

    private func countryCard(_ c: Region) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let m = c.map {
                    WineMapView(mapID: m, showLabels: false, showCities: false, fill: true)
                        .frame(height: 112)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .allowsHitTesting(false)
                } else {
                    Palette.cardAlt.frame(height: 112)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text("\(c.sub?.count ?? 0) regions").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
        .zoomSource(ZoomID.region(c.id))
    }
}

struct RegionDetailView: View {
    let region: Region
    @Environment(GameProgress.self) private var progress
    @State private var explore: MapRef? = nil
    @State private var openSub: Region? = nil

    var body: some View {
        let r = region
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader(eyebrow: r.kind == "country" ? "Country" : r.country, title: r.name, subtitle: r.summary)

                if let m = r.map {
                    let hl = Set(r.highlight ?? (r.kind == "country" ? [] : [r.id]))
                    let pinIDs = (r.kind == "country" ? (r.sub ?? []) : [])
                        .filter { id in MapGeometry.get(m)?.areas.contains { $0.id == id } ?? false }
                    VStack(alignment: .leading, spacing: 8) {
                        WineMapView(mapID: m, highlight: hl, pins: pinIDs, fill: true) { id in
                            if let sub = ContentStore.shared.region(id), sub.id != r.id { openSub = sub } else { explore = MapRef(id: m, hl: [id]) }
                        }
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                        if pinIDs.isEmpty { MapLegend(mapID: m) { id in explore = MapRef(id: m, hl: [id]) } }
                        HStack {
                            Text("Tap a number for its name, again to open").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
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
                                            GrapeBadge(grape: g, size: 52)
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
                                Text(rich(f)).font(.system(size: 15)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(3)
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
                                        Text("\(n + 1)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(Palette.mapColor(a.color).mix(with: .black, 0.28)))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                                        Text(s.grapes.prefix(3).compactMap { ContentStore.shared.grape($0)?.name }.joined(separator: " · "))
                                            .font(.system(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
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
        .navigationDestination(item: $openSub) { sub in RegionDetailView(region: sub) }
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
