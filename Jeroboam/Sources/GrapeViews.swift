import SwiftUI

struct GrapeListView: View {
    @State private var filter = 0      // 0 all, 1 black, 2 white
    @State private var query = ""

    var body: some View {
        let all = ContentStore.shared.library.grapes.sorted { $0.name < $1.name }
        let grapes = all.filter { g in
            (filter == 0 || (filter == 1 && g.berry == .black) || (filter == 2 && g.berry != .black))
            && (query.isEmpty || g.name.localizedCaseInsensitiveContains(query) || (g.aka ?? []).contains { $0.localizedCaseInsensitiveContains(query) })
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Ampelography", title: "Grapes",
                             subtitle: "The variety is the single biggest influence on how a wine smells and tastes. Start with the classics, then explore.")
                Picker("Filter", selection: $filter) {
                    Text("All").tag(0)
                    Text("Black").tag(1)
                    Text("White").tag(2)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(grapes) { g in
                        NavigationLink(value: g) { card(g) }.buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search grapes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: "grapes") } }
    }

    private func card(_ g: Grape) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                GrapeBadge(grape: g, size: 74, disc: false)
                Spacer()
                if g.level == 1 {
                    Text("Classic").font(.system(size: 10, weight: .semibold)).kerning(0.5).textCase(.uppercase)
                        .foregroundStyle(Palette.wine).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.wineSoft))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(g.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text(g.aromas.prefix(2).joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .zoomSource(ZoomID.grape(g.id))
    }
}

struct GrapeDetailView: View {
    let grape: Grape
    @Environment(GameProgress.self) private var progress
    @State private var mapFor: MapRef? = nil

    var body: some View {
        let g = grape
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                WineCardView(grape: g)
                Text(rich(g.summary)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.9)).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if let aka = g.aka, !aka.isEmpty {
                    Text("Also known as \(aka.joined(separator: ", "))").font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(text: "Aromas & flavors")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), alignment: .center, spacing: 14) {
                        ForEach(g.aromas, id: \.self) { a in
                            VStack(spacing: 6) {
                                FlavorIcon(aroma: a, size: 32)
                                Text(a).font(.system(size: 11)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                                    .lineLimit(2).minimumScaleFactor(0.85)
                            }
                        }
                    }
                }

                if g.cool != nil || g.warm != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(text: "Climate changes the style")
                        HStack(alignment: .top, spacing: 12) {
                            if let c = g.cool { climate("Cool", "cloud.sun", Palette.slate, c) }
                            if let w = g.warm { climate("Warm", "sun.max", Palette.brass, w) }
                        }
                    }
                }

                let regions = ContentStore.shared.regions(forGrape: g)
                if !regions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: "Where it grows").padding(.bottom, 8)
                        ForEach(regions) { r in
                            NavigationLink(value: r) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                                        Text(r.country).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
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

                if let s = g.styles { textBlock("Styles", s) }
                if let a = g.ageing { textBlock("Ageing", a) }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "At the table")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(g.food, id: \.self) { f in
                            HStack(spacing: 6) {
                                Image(systemName: "fork.knife").font(.system(size: 10)).foregroundStyle(Palette.inkSoft)
                                Text(f).font(.system(size: 14)).foregroundStyle(Palette.ink)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                        }
                    }
                }

                if let f = g.fact {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle().fill(Palette.wine).frame(width: 2)
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Did you know", color: Palette.wine)
                            Text(rich(f)).font(.serif(17).italic()).foregroundStyle(Palette.ink.opacity(0.9)).lineSpacing(3)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text("Origin: \(g.origin)").font(.system(size: 13)).foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, Metrics.margin).padding(.vertical, 16)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { progress.noteViewed(grape: g.id) }
    }

    private func climate(_ title: String, _ icon: String, _ tint: Color, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            Text(rich(text)).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.08)))
    }

    private func textBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            Text(rich(text)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
