import SwiftUI

/// Reference wine maps (openly licensed images from Wikimedia Commons, bundled as Photos/map-*.jpg)
/// shown in lessons instead of the drawn maps; the atlas map stays one tap away.
enum RefMaps {
    private static let groups: [String: [String: [String]]] = [
        "bordeaux": ["map-medoc": ["medoc", "haut-medoc", "saint-estephe", "pauillac", "saint-julien", "margaux", "listrac", "moulis"]],
        "burgundy": ["map-beaujolais": ["beaujolais", "moulin-a-vent", "fleurie", "morgon", "brouilly", "julienas", "saint-amour", "chiroubles", "regnie", "chenas", "cote-de-brouilly"],
                     "map-chablis": ["chablis"]],
        "spain": ["map-rioja": ["rioja", "es-la-rioja"]],
        "italy": ["map-valpolicella": ["veneto"]],
        "tuscany": ["map-chianti": ["chianti", "chianti-classico", "chianti-rufina", "colli-fiorentini", "colli-senesi"]],
        "new-zealand": ["map-marlborough": ["marlborough"]],
    ]
    private static let byMap: [String: String] = [
        "napa-sonoma": "map-napa", "pacific-northwest": "map-oregon", "south-australia": "map-australia",
        "chile": "map-south-america", "argentina": "map-south-america",
    ]
    static func image(for mapID: String, highlight: Set<String>) -> String? {
        for h in highlight.sorted() where Photos.image("map-" + h) != nil { return "map-" + h }
        for (img, ids) in groups[mapID] ?? [:] where !highlight.isDisjoint(with: ids) && Photos.image(img) != nil { return img }
        for id in ["map-" + mapID, byMap[mapID]].compactMap({ $0 }) where Photos.image(id) != nil { return id }
        return nil
    }
}

struct RefMapCard: View {
    let imageID: String
    let mapID: String
    let highlight: Set<String>
    @State private var zoom = false
    @State private var atlas = false

    var body: some View {
        if let img = Photos.image(imageID) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft).padding(7).background(Circle().fill(.white.opacity(0.9))).padding(8)
                    }
                    .onTapGesture { zoom = true }
                HStack(alignment: .center) {
                    if let c = Photos.creditLine(imageID) {
                        Text(c.replacingOccurrences(of: "Photo:", with: "Map:")).font(.system(size: 10)).foregroundStyle(Palette.inkFaint).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button { atlas = true } label: {
                        Label("Open in the atlas", systemImage: "map").font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Palette.wine)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Palette.wineSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fullScreenCover(isPresented: $zoom) { ZoomableImage(image: img, credit: Photos.creditLine(imageID)) }
            .railCover(isPresented: $atlas) { MapExplorer(mapID: mapID, highlight: highlight) }
        }
    }
}

/// Full-screen image with pinch to zoom and drag.
struct ZoomableImage: View {
    let image: UIImage
    var credit: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit()
                .scaleEffect(scale).offset(offset)
                .gesture(MagnificationGesture()
                    .onChanged { scale = max(1, min(6, base * $0)) }
                    .onEnded { _ in base = scale; if scale <= 1.01 { withAnimation { offset = .zero }; baseOffset = .zero } })
                .simultaneousGesture(DragGesture()
                    .onChanged { v in if scale > 1 { offset = CGSize(width: baseOffset.width + v.translation.width, height: baseOffset.height + v.translation.height) } }
                    .onEnded { _ in baseOffset = offset })
                .onTapGesture(count: 2) { withAnimation(.spring) { if scale > 1 { scale = 1; base = 1; offset = .zero; baseOffset = .zero } else { scale = 2.5; base = 2.5 } } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40).background(Circle().fill(Palette.card)).shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            }
            .padding(16)
            if let credit {
                Text(credit).font(.system(size: 10)).foregroundStyle(Palette.inkFaint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 12)
            }
        }
    }
}

/// "Where it grows": the grape's home region on a reference map (or the atlas map), plus its key regions.
/// Where a grape grows, shown after the grape itself: one or two places get their name and their own map each;
/// more places are listed by name, then shown together on the map that holds most of them.
struct GrapeHomeMap: View {
    let grape: Grape
    var body: some View {
        let lib = ContentStore.shared.library
        let regions = grape.regions.compactMap { id in lib.regions.first { $0.id == id } }
        let mapped = regions.filter { $0.map != nil }
        if !mapped.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Where it grows")
                if mapped.count <= 2 {
                    ForEach(mapped) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(r.country).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                            }
                            LessonMap(mapID: r.map!, highlight: Self.areas(r), compact: true)
                        }
                    }
                } else {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(regions.prefix(10)) { r in
                            Text(r.name).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(Palette.cardAlt))
                        }
                    }
                    let counts = Dictionary(grouping: mapped, by: { $0.map! })
                    if let best = counts.max(by: { a, b in
                        a.value.count != b.value.count ? a.value.count < b.value.count
                            : (mapped.firstIndex { $0.map == a.key } ?? 0) > (mapped.firstIndex { $0.map == b.key } ?? 0)
                    }) {
                        LessonMap(mapID: best.key, highlight: Set(best.value.flatMap(Self.areas)), compact: true)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    static func areas(_ r: Region) -> Set<String> {
        if let h = r.highlight, !h.isEmpty { return Set(h) }
        return r.kind == "country" ? [] : [r.id]
    }
}

/// Lesson map: our map zoomed onto the areas being taught (others as outlines), with the atlas and the printed map one tap away.
struct LessonMap: View {
    let mapID: String
    let highlight: Set<String>
    var compact = false
    @State private var atlas = false
    @State private var printed: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WineMapView(mapID: mapID, highlight: highlight, showCities: !compact, labelScale: compact ? 0.9 : 1, fill: true,
                        autoCallout: highlight.count == 1, focusOnly: true)
                .frame(height: compact ? 230 : 270)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture { atlas = true }
            HStack(spacing: 8) {
                Button { atlas = true } label: { chip("Open in the atlas", "map") }.buttonStyle(.plain)
                if let ref = RefMaps.image(for: mapID, highlight: highlight) {
                    Button { printed = ref } label: { chip("Printed map", "photo") }.buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .railCover(isPresented: $atlas) { MapExplorer(mapID: mapID, highlight: highlight) }
        .fullScreenCover(item: Binding(get: { printed.map { IDBox(id: $0) } }, set: { printed = $0?.id })) { box in
            if let img = Photos.image(box.id) { ZoomableImage(image: img, credit: Photos.creditLine(box.id)) }
        }
    }

    private func chip(_ t: String, _ icon: String) -> some View {
        Label(t, systemImage: icon).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.wine)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Palette.wineSoft))
    }
}

struct IDBox: Identifiable { let id: String }
