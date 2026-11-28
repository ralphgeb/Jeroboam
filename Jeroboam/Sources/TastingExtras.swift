import PhotosUI
import SwiftUI

/// Up to 3 photos with a tasting's notes (the table, the food, the friends): taken or picked, shrunk to 900 px JPEG and kept inside
/// the tasting, so they go to iCloud with it.
struct NotePhotosRow: View {
    @Binding var photos: [Data]
    @State private var picks: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var shot: UIImage? = nil
    static let limit = 3

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(photos.enumerated()), id: \.offset) { i, d in
                if let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { photos.remove(at: i) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 20, height: 20).background(Circle().fill(.black.opacity(0.55)))
                            }
                            .accessibilityLabel("Remove photo").offset(x: 6, y: -6)
                        }
                }
            }
            if photos.count < Self.limit {
                Menu {
                    Button { camera = true } label: { Label("Take a photo", systemImage: "camera") }
                    PhotosPicker(selection: $picks, maxSelectionCount: Self.limit - photos.count, matching: .images) {
                        Label("Choose from photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "camera").font(.system(size: 18))
                        Text(photos.isEmpty ? "Add photos" : "\(photos.count)/\(Self.limit)").font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(Palette.wine)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wineSoft))
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: picks) { _, items in
            Task {
                for item in items where photos.count < Self.limit {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d), let small = Self.shrink(img) {
                        photos.append(small)
                    }
                }
                picks = []
            }
        }
        .onChange(of: shot) { _, img in
            if let img, photos.count < Self.limit, let small = Self.shrink(img) { photos.append(small) }
            shot = nil
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker(image: $shot).ignoresSafeArea() }
    }

    /// 900 px on the long side, JPEG 0.6 (about 80–150 KB): small enough to travel inside the tasting.
    static func shrink(_ image: UIImage) -> Data? {
        let side = max(image.size.width, image.size.height)
        let k = min(1, 900 / max(1, side))
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.6)
    }
}

/// The Tastings tab before the first tasting: an invitation to taste blind, how the score works, and what you'll see.
struct TastingsWelcome: View {
    var onBlind: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("BLIND TASTING").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(.white.opacity(0.75))
                Text("Can you guess the wine?").font(.jero(size: 22, weight: .semibold)).foregroundStyle(.white)
                Text("Snap the label, Jero hides it. Look, smell and taste, guess the grape and the country, then see how close you were.")
                    .font(.jero(size: 14)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                Button(action: onBlind) {
                    Label("Start a blind tasting", systemImage: "eye.slash")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("How you score").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    part("Grape", 30); part("Country", 20); part("Aromas", 30); part("Structure", 20)
                }
                Text("Out of 100. Tasting a bottle you know works too: tap a bottle in your cellar, then Taste this bottle.")
                    .font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 0)
        }
    }

    private func part(_ name: String, _ points: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(points)").font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
            Text(name).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wineSoft))
    }
}

/// The Cellar tab before the first bottle.
struct CellarWelcome: View {
    var onScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CELLAR").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(.white.opacity(0.75))
            Text("Know what every bottle is worth").font(.jero(size: 22, weight: .semibold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Scan the bottles you own: Jero adds their price, score and when to open them, and tells you when each is ready.")
                .font(.jero(size: 14)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            Button(action: onScan) {
                Label("Scan a bottle", systemImage: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
    }
}

// MARK: - Aromas: this wine's vs yours

/// The aromas this wine usually shows (its tasting notes, else its main grape's), each ticked when you found it (✓ the same word,
/// ≈ the same family), then the ones you noted that it doesn't usually show. Used at the end of a tasting and on the tasting page.
struct AromaCompareCard: View {
    let wine: WineIdentity
    let picked: [String]

    static func typical(_ w: WineIdentity) -> [String] {
        if !w.tastingNotes.isEmpty { return Array(w.tastingNotes.prefix(6)) }
        return Array((matchGrape(w.grapes.first)?.aromas ?? []).prefix(6))
    }

    private enum Hit { case exact, close, none }
    private func hit(_ a: String) -> Hit {
        let mine = picked.map { $0.lowercased() }
        if mine.contains(a.lowercased()) { return .exact }
        if let f = ContentStore.shared.aromaCategory(forItem: a)?.id,
           picked.contains(where: { ContentStore.shared.aromaCategory(forItem: $0)?.id == f }) { return .close }
        return .none
    }

    var body: some View {
        let typical = Self.typical(wine)
        let lower = Set(typical.map { $0.lowercased() })
        let extra = picked.filter { !lower.contains($0.lowercased()) }
        let found = typical.filter { hit($0) == .exact }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aromas").font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if !typical.isEmpty && !picked.isEmpty {
                    Text("\(found) of \(typical.count) found").font(.jero(size: 13, weight: .semibold)).foregroundStyle(Palette.wine)
                }
            }
            if !typical.isEmpty {
                Text(wine.tastingNotes.isEmpty ? "Typical of its grape" : "In this wine")
                    .font(.jero(size: 12.5, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(typical, id: \.self) { a in chip(a, hit(a)) }
                }
            }
            if !extra.isEmpty {
                Text(typical.isEmpty ? "You noted" : "You also noted").font(.jero(size: 12.5, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(extra, id: \.self) { AromaChip(text: $0, compact: true) }
                }
            }
            if picked.isEmpty {
                Text("You didn't note any aromas this time.").font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func chip(_ a: String, _ h: Hit) -> some View {
        HStack(spacing: 5) {
            FlavorIcon(aroma: a, size: 16)
            Text(a).font(.system(size: 13)).foregroundStyle(h == .exact ? Palette.onWine : Palette.ink)
            if h != .none {
                Image(systemName: h == .exact ? "checkmark" : "circle.lefthalf.filled")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(h == .exact ? Palette.onWine : Palette.wine)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(h == .exact ? Palette.wine : (h == .close ? Palette.wineSoft : Palette.cardAlt)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a + (h == .exact ? ", you found it" : h == .close ? ", you found a close one" : ""))
    }
}

// MARK: - Tastings list (the same compact list / cards switch as the cellar)

struct LayoutSwitch: View {
    @Binding var asList: Bool
    var body: some View {
        HStack(spacing: 0) {
            button("list.bullet", compact: true)
            button("square.grid.2x2", compact: false)
        }
        .padding(3).background(Capsule().fill(Palette.cardAlt))
    }
    private func button(_ icon: String, compact: Bool) -> some View {
        let on = asList == compact
        return Button { Haptics.tap(); withAnimation(.smooth(duration: 0.2)) { asList = compact } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Palette.onWine : Palette.ink)
                .frame(width: 46, height: 34)
                .background(Capsule().fill(on ? Palette.wine : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(compact ? "Compact list" : "Cards")
    }
}

/// One tasting as a compact row, like a cellar row: picture, name, vintage and place, points on the right with the date.
struct EntryRow: View {
    let entry: JournalEntry
    var last = false
    var body: some View {
        HStack(spacing: 10) {
            Thumb(photo: entry.photo, style: entry.wine.style).frame(width: 34, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if entry.isBlind {
                        Image(systemName: "eye.slash").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.wine)
                    }
                    Text(entry.title).font(.system(size: 14.5, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                }
                Text([entry.wine.vintage, entry.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.points) pts").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))
                    .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 56) } }
        .contentShape(Rectangle())
    }
}

// MARK: - The last page of a tasting

/// The bottle you tasted at the top of the last page: its picture, the colour you saw, your score and the XP earned.
struct TastedHero: View {
    let entry: JournalEntry
    let photo: UIImage?
    let blind: Bool
    let xp: Int

    var body: some View {
        let w = entry.wine
        let color = entry.colorID.flatMap { ContentStore.shared.color($0) }
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let photo {
                    Color.clear.overlay { Image(uiImage: photo).resizable().scaledToFill() }.clipped()
                } else {
                    Thumb(photo: entry.photo, style: w.style)
                }
            }
            .frame(width: 96, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(blind ? "It was…" : "Tasting saved").font(.jero(size: 12, weight: .semibold)).foregroundStyle(Palette.wine)
                    .textCase(.uppercase).kerning(0.6)
                if !w.producer.isEmpty {
                    Text(w.producer).font(.jero(size: 13, weight: .semibold)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
                Text([w.name.isEmpty ? "Your wine" : w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.jero(size: 21, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(3).minimumScaleFactor(0.8)
                if !w.region.isEmpty || !w.country.isEmpty {
                    Text([w.region, w.country].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
                HStack(spacing: 10) {
                    if let c = color {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color(hex: c.hex)).frame(width: 16, height: 16)
                                .overlay(Rectangle().strokeBorder(Palette.line, lineWidth: 0.5))
                            Text(c.name).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        }
                    }
                    Text("\(entry.points) pts").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Palette.bordeaux)
                    Text("+\(xp) XP").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.brass)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(Palette.brass.opacity(0.14)))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Your nose, marked: every aroma you picked with its icon, green when the wine has it (or one of its family), red when it
/// doesn't; then the aromas the wine has that you didn't pick.
struct TastedAromasCard: View {
    let wine: WineIdentity
    let picked: [String]

    private func right(_ a: String, typical: [String]) -> Bool {
        let t = typical.map { $0.lowercased() }
        if t.contains(a.lowercased()) { return true }
        guard let f = ContentStore.shared.aromaCategory(forItem: a)?.id else { return false }
        return typical.contains { ContentStore.shared.aromaCategory(forItem: $0)?.id == f }
    }

    var body: some View {
        let typical = AromaCompareCard.typical(wine)
        let rights = picked.filter { right($0, typical: typical) }
        let missed = typical.filter { t in !picked.contains { right($0, typical: [t]) } }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your nose").font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if !typical.isEmpty && !picked.isEmpty {
                    Text("\(rights.count) of \(picked.count) right").font(.jero(size: 13, weight: .semibold))
                        .foregroundStyle(rights.isEmpty ? Palette.wrong : Palette.correct)
                }
            }
            if picked.isEmpty {
                Text("You didn't pick any aromas this time.").font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft)
            } else if typical.isEmpty {
                Text("We don't know this wine's aromas yet, so these can't be marked.").font(.jero(size: 13)).foregroundStyle(Palette.inkSoft)
                grid(picked) { _ in nil }
            } else {
                grid(picked) { right($0, typical: typical) }
            }
            if !missed.isEmpty {
                Text(picked.isEmpty ? "This wine usually shows" : "You missed").font(.jero(size: 12.5, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(missed, id: \.self) { AromaChip(text: $0, compact: true) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func grid(_ items: [String], ok: @escaping (String) -> Bool?) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { a in
                let r = ok(a)
                let tint: Color = r == true ? Palette.correct : (r == false ? Palette.wrong : Palette.wine)
                VStack(spacing: 6) {
                    FlavorIcon(aroma: a, size: 26)
                    Text(a).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, minHeight: 78)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(r == nil ? 0.06 : 0.12)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.55), lineWidth: r == nil ? 0.5 : 1.2))
                .overlay(alignment: .topTrailing) {
                    if let r {
                        Image(systemName: r ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14)).foregroundStyle(tint).padding(5)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(a + (r == true ? ", right" : r == false ? ", not in this wine" : ""))
            }
        }
    }
}
