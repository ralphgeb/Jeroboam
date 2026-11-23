import SwiftUI

/// "Maps beyond the atlas": wine places that are not in the course, mapped and described in the same style as the atlas.
/// Opened from Settings; the Journal also finds them when a scanned wine comes from one of these places.
struct ExtraAtlasView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var all: [Region] { ContentStore.shared.extraRegions }
    private var countries: [Region] { all.filter { $0.kind == "country" && $0.atlas != true } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(eyebrow: "Beyond the atlas", title: "More wine maps",
                                 subtitle: "Places that are not in the course, mapped with their regions and appellations. The Journal uses them too.")
                    SearchBar(text: $query, prompt: "Search these places")
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        VStack(alignment: .leading, spacing: 22) {
                            let oldIDs = ["switzerland", "croatia", "slovenia", "romania", "bulgaria", "armenia", "turkey", "cyprus"]
                            let usFirst = ["new-york", "mid-atlantic", "texas-southwest", "mountain-west"]
                            let oldWorld = countries.filter { oldIDs.contains($0.id) }.sorted { (oldIDs.firstIndex(of: $0.id) ?? 99) < (oldIDs.firstIndex(of: $1.id) ?? 99) }
                            let newWorld = countries.filter { !oldIDs.contains($0.id) }.sorted { (usFirst.firstIndex(of: $0.id) ?? 50) < (usFirst.firstIndex(of: $1.id) ?? 50) }
                            ForEach([("Old World", oldWorld), ("New World", newWorld)], id: \.0) { title, list in
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionTitle(text: title, detail: "\(list.count)")
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                                        ForEach(list) { c in
                                            NavigationLink(value: c) { ExtraCountryCard(country: c) }.buttonStyle(PressableStyle())
                                        }
                                    }
                                }
                            }
                            Text("Map sources: geoBoundaries (CC BY 4.0), UC Davis AVA project, Natural Earth, © OpenStreetMap contributors (ODbL). Appellation areas follow the official administrative units or AVA boundaries that contain them, so edges are approximate.")
                                .font(.system(size: 11)).foregroundStyle(Palette.inkFaint).padding(.top, 10)
                        }
                    } else {
                        AtlasSearchResults(query: query, onlyExtras: true)
                    }
                }
            .padding(.horizontal, Metrics.margin).padding(.top, 54).padding(.bottom, 24)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                        .frame(width: 34, height: 34).background(Circle().fill(Palette.card))
                        .overlay(Circle().strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
                }
                .accessibilityLabel("Close")
                .padding(.trailing, Metrics.margin).padding(.top, 10)
            }
            .navigationDestination(for: Region.self) { RegionDetailView(region: $0) }
            .navigationDestination(for: Grape.self) { GrapeDetailView(grape: $0) }
        }
        .environment(\.hasRail, false)
        .plusSheetHost()
    }
}

struct ExtraCountryCard: View {
    let country: Region
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let m = country.map {
                    WineMapView(mapID: m, showLabels: false, showCities: false, fill: true, thumbnail: true, tightThumb: true)
                        .frame(height: 112).frame(maxWidth: .infinity).clipped().allowsHitTesting(false)
                } else {
                    Palette.cardAlt.frame(height: 112)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text("\(country.sub?.count ?? 0) regions").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}
