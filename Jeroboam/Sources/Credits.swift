import SwiftUI

/// Settings > "Map and photo credits": the data behind the regions and maps, and every photo used, with their licenses.
struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Source: Identifiable {
        let id = UUID()
        let name: String, license: String, used: String
        var url: String? = nil
    }
    private let sources: [Source] = [
        Source(name: "Natural Earth", license: "Public domain",
               used: "Coastlines, countries, lakes and rivers on every map.", url: "https://www.naturalearthdata.com"),
        Source(name: "geoBoundaries (gbOpen)", license: "CC BY 4.0",
               used: "Administrative units (provinces, states, districts) that the regions of Portugal, Spain, Germany, Austria, Hungary, Greece, Chile, Argentina, Australia, New Zealand, South Africa, Lebanon and the extra maps follow. Runfola et al., 2020.",
               url: "https://www.geoboundaries.org"),
        Source(name: "EU wine appellation boundaries (PDO)", license: "CC BY 4.0",
               used: "Official outlines of European appellations. Candiago et al., 2022, Scientific Data.",
               url: "https://doi.org/10.1038/s41597-022-01122-8"),
        Source(name: "OpenStreetMap contributors", license: "ODbL",
               used: "Detailed coastlines and land outlines.", url: "https://www.openstreetmap.org/copyright"),
        Source(name: "UC Davis Library, American Viticultural Areas", license: "Open data",
               used: "Boundaries of the American Viticultural Areas (AVAs) in the United States.", url: "https://github.com/UCDavisLibrary/ava"),
        Source(name: "WineRegions (adynak)", license: "CC0",
               used: "Australian geographical indications and Argentine wine regions.", url: "https://github.com/adynak/WineRegions"),
        Source(name: "France-geojson (Gregoire David)", license: "Open data from the French government",
               used: "French communes, which make up the village and appellation areas in France.", url: "https://github.com/gregoiredavid/france-geojson"),
        Source(name: "geojson-italy (openpolis)", license: "Open data",
               used: "Italian municipalities (ISTAT data), which make up the zones and appellations in Italy.", url: "https://github.com/openpolis/geojson-italy"),
    ]

    private var photoList: [(String, Photos.Credit)] {
        Photos.credits.map { ($0.key, $0.value) }.sorted { $0.1.title.localizedCaseInsensitiveCompare($1.1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        ScreenHeader(eyebrow: "Settings", title: "Credits",
                                     subtitle: "The data and photos behind the regions and maps.")
                        Spacer(minLength: 8)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                                .frame(width: 34, height: 34).background(Circle().fill(Palette.card))
                        }
                        .accessibilityLabel("Close")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Regions and maps")
                        GroupCard {
                            ForEach(Array(sources.enumerated()), id: \.element.id) { i, s in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(s.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Spacer(minLength: 8)
                                        Text(s.license).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.wine)
                                    }
                                    Text(s.used).font(.system(size: 13)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                                    if let u = s.url, let url = URL(string: u) {
                                        Link(u.replacingOccurrences(of: "https://", with: ""), destination: url)
                                            .font(.system(size: 12)).foregroundStyle(Palette.inkFaint).lineLimit(1)
                                    }
                                }
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottom) { if i < sources.count - 1 { Hairline().padding(.leading, 14) } }
                            }
                        }
                        Text("Appellation areas follow the official administrative units, appellation boundaries or AVA outlines that contain them, so edges are approximate. Maps are simplified for the screen.")
                            .font(.system(size: 12)).foregroundStyle(Palette.inkFaint).fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Photos", detail: "\(photoList.count)")
                        Text("Photos come from Wikimedia Commons, under the licenses shown. Each one is also credited where it appears.")
                            .font(.system(size: 12)).foregroundStyle(Palette.inkFaint).fixedSize(horizontal: false, vertical: true)
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(photoList, id: \.0) { id, c in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title.replacingOccurrences(of: "File:", with: "")).font(.system(size: 13)).foregroundStyle(Palette.ink).lineLimit(2)
                                    Text([c.artist.isEmpty ? "Wikimedia Commons" : c.artist, c.license].joined(separator: " · "))
                                        .font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft).lineLimit(2)
                                }
                                .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                                Hairline()
                            }
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Metrics.margin).padding(.top, 16)
                .readable(720)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
