import SwiftUI
import PhotosUI
import Observation

// MARK: - Models

/// One tasting: either a known wine, or a blind tasting where the wine is revealed (and scored) at the end.
struct JournalEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var photo: String? = nil
    var wine = WineIdentity.empty
    var identified = false
    // the drinker's own tasting
    var colorID: String? = nil
    var intensity = 2
    var aromas: [String] = []
    var sweetness = 1
    var acidity = 3
    var tannin = 3
    var body = 3
    var finish = 3
    var rating = 88                       // 100-point scale (older entries used 1–10)
    var quality: [String] = []
    var notes = ""
    // blind tasting (optional so older journals still load)
    var blind: Bool? = nil
    var guessGrape: String? = nil
    var guessCountry: String? = nil
    var score: Int? = nil
    var price: PriceInfo? = nil

    var title: String { wine.name.isEmpty ? "Untitled wine" : wine.name }
    /// The rating on the 100-point scale (older 1–10 ratings are converted).
    var points: Int { rating <= 10 ? 50 + rating * 5 : rating }
    var isBlind: Bool { blind == true }
}

/// A bottle you own.
struct CellarBottle: Codable, Identifiable, Hashable {
    var id = UUID()
    var added = Date()
    var photo: String? = nil
    var wine = WineIdentity.empty
    var quantity = 1
    var price: PriceInfo? = nil
    var notes = ""

    var title: String { wine.name.isEmpty ? "Untitled wine" : wine.name }
    var value: Double { (price?.average ?? 0) * Double(quantity) }
}

@Observable
final class JournalStore {
    var entries: [JournalEntry] = [] { didSet { save() } }
    var cellar: [CellarBottle] = [] { didSet { saveCellar() } }
    var lookups = 0 { didSet { UserDefaults.standard.set(lookups, forKey: "jero.lookups") } }
    var spentUSD: Double = 0 { didSet { UserDefaults.standard.set(spentUSD, forKey: "jero.spent") } }

    @ObservationIgnored private let url: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("journal.json")
    }()
    @ObservationIgnored private let cellarURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("cellar.json")
    }()

    static var photoDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// False for the made-up journal shown to free users (never written to disk).
    @ObservationIgnored var persist = true

    /// A made-up cellar and tastings, shown greyed out behind the Jero Plus lock.
    static let sample: JournalStore = {
        let j = JournalStore(empty: true)
        func wine(_ name: String, _ producer: String, _ region: String, _ country: String, _ grapes: [String], _ vintage: String,
                  _ style: String, _ notes: [String]) -> WineIdentity {
            var w = WineIdentity.empty
            w.found = true; w.name = name; w.producer = producer; w.region = region; w.country = country; w.grapes = grapes
            w.vintage = vintage; w.style = style; w.tastingNotes = notes; w.confidence = "high"
            return w
        }
        let bottles: [(WineIdentity, Int, Double)] = [
            (wine("Château Musar", "Château Musar", "Bekaa Valley", "Lebanon", ["Cabernet Sauvignon", "Cinsault", "Carignan"], "2016", "red", ["Red cherry", "Dried fig", "Cloves"]), 2, 58),
            (wine("Barolo Bussia", "Prunotto", "Barolo", "Italy", ["Nebbiolo"], "2019", "red", ["Rose", "Tar", "Red cherry"]), 3, 72),
            (wine("Sancerre Les Monts Damnés", "Henri Bourgeois", "Sancerre", "France", ["Sauvignon Blanc"], "2022", "white", ["Grapefruit", "Flint"]), 4, 41),
            (wine("Brut Réserve", "Charles Heidsieck", "Champagne", "France", ["Chardonnay", "Pinot Noir"], "NV", "sparkling", ["Brioche", "Pear"]), 1, 69),
        ]
        for (w, q, p) in bottles {
            var b = CellarBottle(); b.wine = w; b.quantity = q
            b.price = PriceInfo(average: p, low: p * 0.85, high: p * 1.2, currency: "USD", source: "Estimate")
            j.cellar.append(b)
        }
        var e = JournalEntry()
        e.wine = bottles[0].0; e.identified = true; e.blind = true; e.aromas = ["Red cherry", "Cloves", "Earth"]
        e.guessGrape = "Cabernet Sauvignon"; e.guessCountry = "France"; e.body = 4; e.tannin = 4; e.rating = 92
        e.score = TastingScore.total(e)
        j.entries.append(e)
        var f = JournalEntry(); f.wine = bottles[2].0; f.identified = true; f.aromas = ["Grapefruit", "Flint"]; f.rating = 9
        j.entries.append(f)
        return j
    }()

    private init(empty: Bool) { persist = false }

    init() {
        if let data = try? Data(contentsOf: url), let e = try? JSONDecoder().decode([JournalEntry].self, from: data) { entries = e }
        if let data = try? Data(contentsOf: cellarURL), let c = try? JSONDecoder().decode([CellarBottle].self, from: data) { cellar = c }
        lookups = UserDefaults.standard.integer(forKey: "jero.lookups")
        spentUSD = UserDefaults.standard.double(forKey: "jero.spent")
    }

    private func save() { guard persist else { return }; if let d = try? JSONEncoder().encode(entries) { try? d.write(to: url, options: .atomic) } }
    private func saveCellar() { guard persist else { return }; if let d = try? JSONEncoder().encode(cellar) { try? d.write(to: cellarURL, options: .atomic) } }

    func savePhoto(_ image: UIImage, id: UUID) -> String? {
        let name = id.uuidString + ".jpg"
        let maxSide: CGFloat = 1600
        let s = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        let img = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = img.jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: Self.photoDir.appendingPathComponent(name))
        return name
    }

    static func image(_ name: String?) -> UIImage? {
        guard let n = name else { return nil }
        return UIImage(contentsOfFile: photoDir.appendingPathComponent(n).path)
    }

    func upsert(_ e: JournalEntry) {
        if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i] = e } else { entries.insert(e, at: 0) }
    }

    func delete(_ e: JournalEntry) {
        entries.removeAll { $0.id == e.id }
        if let p = e.photo, !cellar.contains(where: { $0.photo == p }) { try? FileManager.default.removeItem(at: Self.photoDir.appendingPathComponent(p)) }
    }

    func upsert(_ b: CellarBottle) {
        if let i = cellar.firstIndex(where: { $0.id == b.id }) { cellar[i] = b } else { cellar.insert(b, at: 0) }
    }

    func delete(_ b: CellarBottle) {
        cellar.removeAll { $0.id == b.id }
        if let p = b.photo, !entries.contains(where: { $0.photo == p }) { try? FileManager.default.removeItem(at: Self.photoDir.appendingPathComponent(p)) }
    }

    func noteCost(_ usd: Double) {
        guard usd > 0 else { return }
        lookups += 1
        spentUSD += usd
    }

    var bottleCount: Int { cellar.reduce(0) { $0 + $1.quantity } }
    var cellarValue: Double { cellar.reduce(0) { $0 + $1.value } }
    var cellarCurrency: String { cellar.compactMap { $0.price?.currency }.first ?? "USD" }
    var averageRating: Double { entries.isEmpty ? 0 : Double(entries.map(\.points).reduce(0, +)) / Double(entries.count) }
    var blindAverage: Int? {
        let s = entries.compactMap(\.score)
        return s.isEmpty ? nil : s.reduce(0, +) / s.count
    }
}

func money(_ v: Double, _ currency: String) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency.isEmpty ? "USD" : currency
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
}

func styleColor(_ s: String) -> Color {
    switch s {
    case "white": return Color(hex: "#C9A227")
    case "rose": return Color(hex: "#E07A93")
    case "sparkling": return Color(hex: "#C9A54A")
    case "fortified", "sweet": return Color(hex: "#B8701E")
    case "orange": return Color(hex: "#E08A3C")
    default: return Color(hex: "#8B1538")
    }
}

// MARK: - Journal tab

/// The Journal is part of Jero Plus: free users see a made-up cellar, greyed out, under the Bordeaux lock.
struct JournalView: View {
    var body: some View {
        if Plus.shared.active {
            JournalHome()
        } else {
            JournalHome()
                .environment(JournalStore.sample)
                .allowsHitTesting(false)
                .saturation(0.25)
                .opacity(0.5)
                .overlay {
                    PlusCallout(title: "Your wine journal",
                                message: "Scan bottles into your cellar with their price, and taste blind, scored out of 100.")
                        .onTapGesture { PaywallPresenter.shared.show("Scan, keep a cellar and taste blind with Jero Plus.") }
                }
        }
    }
}

struct JournalHome: View {
    @Environment(JournalStore.self) private var journal
    @State private var section = 0
    @State private var scan = false
    @State private var blind = false

    var body: some View {
        NavigationStack {
            CollapsingPage(eyebrow: "Your wines", title: "Journal",
                           subtitle: "Scan bottles into your cellar, or taste blind and see how close you get.") {

                    HStack(spacing: 12) {
                        actionTile(icon: "camera.viewfinder", title: "Scan a wine", detail: "Details and price", primary: true) { scan = true }
                        actionTile(icon: "eye.slash", title: "Blind tasting", detail: "Scored out of 100", primary: false) { blind = true }
                    }

                    Picker("Section", selection: $section) {
                        Text("Cellar").tag(0)
                        Text("Tastings").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if section == 0 { cellarSection } else { tastingsSection }
                    JournalExtras(onBlind: { blind = true })
                    Color.clear.frame(height: 20)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: JournalEntry.self) { e in EntryDetailView(entryID: e.id) }
            .navigationDestination(for: CellarBottle.self) { b in CellarDetailView(bottleID: b.id) }
            .navigationDestination(for: Wine.self) { w in PlusGate(quota: "wines", id: w.id) { WineDetailView(wine: w) } }
            .navigationDestination(for: Grape.self) { g in PlusGate(quota: "grapes", id: g.id) { GrapeDetailView(grape: g) } }
            .navigationDestination(for: Region.self) { r in PlusGate(country: r.gateCountry, reason: "Every country and appellation comes with Jero Plus.") { RegionDetailView(region: r) } }
            .navigationDestination(for: WineStyle.self) { st in PlusGate(quota: "styles", id: st.id) { StyleDetailView(style: st) } }
        }
        .fullScreenCover(isPresented: $scan) { ScanFlow() }
        .fullScreenCover(isPresented: $blind) { TastingFlow(blind: true) }
        .onAppear {
            #if DEBUG
            DebugScreens.journalHook(journal) { kind in
                if kind == "scan" { scan = true } else if kind == "blind" { blind = true } else if kind == "tastings" { section = 1 }
            }
            #endif
        }
    }

    private func actionTile(icon: String, title: String, detail: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17))
                    .foregroundStyle(primary ? Palette.onWine : Palette.wine)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(primary ? Palette.onWine.opacity(0.15) : Palette.wineSoft))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(primary ? Palette.onWine : Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.85)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(primary ? Palette.onWine.opacity(0.75) : Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(primary ? Palette.wine : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(primary ? .clear : Palette.line.opacity(0.7), lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
    }

    // ---- cellar
    @ViewBuilder private var cellarSection: some View {
        if journal.cellar.isEmpty {
            empty(icon: "square.stack.3d.up", title: "Your cellar is empty",
                  text: "Scan the bottles you own. Jero keeps the details and the average price, and adds up what your cellar is worth.")
        } else {
            HStack(spacing: 10) {
                stat("\(journal.bottleCount)", journal.bottleCount == 1 ? "bottle" : "bottles")
                stat(money(journal.cellarValue, journal.cellarCurrency), "cellar value")
                stat(journal.bottleCount > 0 ? money(journal.cellarValue / Double(journal.bottleCount), journal.cellarCurrency) : "–", "avg. bottle")
            }
            GroupCard {
                ForEach(Array(journal.cellar.enumerated()), id: \.element.id) { i, b in
                    NavigationLink(value: b) { cellarRow(b, last: i == journal.cellar.count - 1) }
                        .buttonStyle(RowPressStyle())
                }
            }
            Text("Average prices from Wine-Searcher or CellarTracker where found; otherwise an estimate.")
                .font(.system(size: 11.5)).foregroundStyle(Palette.inkFaint)
        }
    }

    private func cellarRow(_ b: CellarBottle, last: Bool) -> some View {
        HStack(spacing: 12) {
            Thumb(photo: b.photo, style: b.wine.style).frame(width: 46, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Text([b.wine.vintage, b.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(b.price.map { $0.averageText } ?? "–").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                Text("× \(b.quantity)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 72) } }
        .contentShape(Rectangle())
    }

    // ---- tastings
    @ViewBuilder private var tastingsSection: some View {
        if journal.entries.isEmpty {
            empty(icon: "wineglass", title: "No tastings yet",
                  text: "Try a blind tasting: snap the label, taste without looking, guess the grape and country, then see your score.")
        } else {
            HStack(spacing: 10) {
                stat("\(journal.entries.count)", "tastings")
                stat(String(format: "%.0f", journal.averageRating), "avg. points")
                stat(journal.blindAverage.map { "\($0)" } ?? "–", "blind score")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(journal.entries) { e in
                    NavigationLink(value: e) { EntryTile(entry: e) }.buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 18, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
    }

    private func empty(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 26, weight: .light)).foregroundStyle(Palette.wine)
                .frame(width: 60, height: 60).background(Circle().fill(Palette.wineSoft))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(text).font(.system(size: 14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
        }
        .padding(.vertical, 26).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }
}

/// Bottle photo, or a soft placeholder in the wine's color.
struct Thumb: View {
    let photo: String?
    let style: String
    var body: some View {
        Group {
            if let img = JournalStore.image(photo) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    styleColor(style).opacity(0.14)
                    WineGlass(color: styleColor(style), fill: 0.5).padding(10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EntryTile: View {
    let entry: JournalEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Thumb(photo: entry.photo, style: entry.wine.style)
                    .frame(height: 150).frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
                HStack(spacing: 4) {
                    if entry.isBlind { Image(systemName: "eye.slash").font(.system(size: 10, weight: .semibold)) }
                    Text("\(entry.points) pts").font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Palette.bordeaux.opacity(0.92)))
                .padding(8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                Text([entry.wine.vintage, entry.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            .padding(10)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}

// MARK: - Shared pieces

/// Take a photo, pick one, or type the wine.
struct CaptureStep: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    @Binding var image: UIImage?
    var onTyped: (String) -> Void
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
            Button { showCamera = true } label: { Label("Take a photo", systemImage: "camera") }
                .buttonStyle(PrimaryButtonStyle())
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose from library").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            }
            HStack {
                Rectangle().fill(Palette.line).frame(height: 0.5)
                Text("or").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                Rectangle().fill(Palette.line).frame(height: 0.5)
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField("Type the wine, e.g. Cloudy Bay Sauvignon Blanc 2023", text: $typed)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                Button("Continue") { onTyped(typed.trimmingCharacters(in: .whitespaces)) }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine)
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !WineRecognizer.isAvailable {
                Text("Wine recognition isn't set up in this build, so details and prices won't load.")
                    .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
            }
        }
        .sheet(isPresented: $showCamera) { CameraPicker(image: $image).ignoresSafeArea() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { image = img }
            }
        }
    }
}

/// Everything known about an identified wine.
struct WineInfoCard: View {
    let wine: WineIdentity
    @State private var tab = 0
    @State private var openGrape: Grape? = nil

    var body: some View {
        let w = wine
        let region = ContentStore.shared.library.regions.first { r in
            !w.region.isEmpty && (w.region.localizedCaseInsensitiveContains(r.name) || r.name.localizedCaseInsensitiveContains(w.region))
        }
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                if !w.producer.isEmpty { Eyebrow(w.producer, color: styleColor(w.style)) }
                Text([w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text([w.region, w.country].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
            }
            Picker("Info", selection: $tab) {
                Text("Bottle").tag(0)
                Text("In the glass").tag(1)
                Text("Region").tag(2)
            }
            .pickerStyle(.segmented)
            switch tab {
            case 1:
                if !w.tastingNotes.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(w.tastingNotes.prefix(5), id: \.self) { n in
                            VStack(spacing: 5) {
                                FlavorIcon(aroma: n, size: 28)
                                Text(n).font(.system(size: 10.5)).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                if !w.palate.isEmpty { Text(w.palate).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.88)) }
                if !w.food.isEmpty { info("fork.knife", w.food.prefix(3).joined(separator: " · ")) }
            case 2:
                if let r = region {
                    Text(r.summary).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.88))
                    if let m = r.map {
                        WineMapView(mapID: m, highlight: Set(r.highlight ?? [r.id]), showCities: false, labelScale: 0.85, fill: true)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    Text("This region isn't in the atlas yet.").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                }
            default:
                if !w.grapes.isEmpty { grapeChips(w.grapes) }
                info("wineglass", w.style.capitalized)
                if let d = w.drinkWindow, !d.isEmpty { info("calendar", d) }
                if !w.funFact.isEmpty {
                    Text(w.funFact).font(.system(size: 14).italic()).foregroundStyle(Palette.inkSoft).padding(.top, 2)
                }
                if !w.found {
                    Text("Best guess, so double-check the name.").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.pink)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }

    /// Grapes as chips; known varieties open their grape card.
    private func grapeChips(_ names: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(names, id: \.self) { n in
                    let g = matchGrape(n)
                    Button { openGrape = g } label: {
                        HStack(spacing: 6) {
                            if let g { GrapeBadge(grape: g, size: 22) } else { Image(systemName: "leaf").font(.system(size: 12)) }
                            Text(n).font(.system(size: 14, weight: .medium))
                            if g != nil { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.inkFaint) }
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.wineSoft))
                    }
                    .buttonStyle(.plain)
                    .disabled(g == nil)
                }
            }
        }
        .scrollIndicators(.hidden)
        .sheet(item: $openGrape) { g in
            NavigationStack {
                GrapeDetailView(grape: g)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { openGrape = nil } } }
            }
        }
    }

    private func info(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Palette.wine).frame(width: 18)
            Text(text).font(.system(size: 14.5)).foregroundStyle(Palette.ink)
        }
    }
}

/// Average price with its source.
struct PriceCard: View {
    let price: PriceInfo?
    var loading = false
    var quantity: Int? = nil
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "tag").font(.system(size: 17)).foregroundStyle(Palette.wine)
                .frame(width: 40, height: 40).background(Circle().fill(Palette.wineSoft))
            VStack(alignment: .leading, spacing: 2) {
                if loading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Estimating the price…").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                    }
                } else if let p = price {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(p.averageText).font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                        Text("avg. per bottle").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                    }
                    Text(p.isEstimate ? (p.low > 0 && p.high > 0 ? "Estimated by Claude · \(p.format(p.low))–\(p.format(p.high))" : "Estimated by Claude") :
                            (p.low > 0 && p.high > 0 ? "\(p.format(p.low))–\(p.format(p.high)) · \(p.source)" : p.source))
                        .font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                    if let q = quantity, q > 1 {
                        Text("\(q) bottles · \(p.format(p.average * Double(q)))").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Palette.ink)
                    }
                } else {
                    Text("No price estimate for this wine").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            if let onRefresh, !loading, WineRecognizer.livePrices {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                        .frame(width: 32, height: 32).background(Circle().fill(Palette.cardAlt))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    }
}

/// Close button + progress bar used by the flows.
struct FlowHeader: View {
    var progress: Double
    var onClose: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(height: 4)
                    Capsule().fill(Palette.wine).frame(width: max(4, geo.size.width * progress), height: 4)
                        .animation(.spring(), value: progress)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }
}

// MARK: - Scan a wine (details, price, add to cellar)

struct ScanFlow: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage? = nil
    @State private var wine = WineIdentity.empty
    @State private var identified = false
    @State private var working = false
    @State private var error: String? = nil
    @State private var price: PriceInfo? = nil
    @State private var pricing = false
    @State private var quantity = 1
    @State private var added = false
    @State private var tasteNow = false
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(progress: started ? (added ? 1 : 0.6) : 0.15) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !started {
                        CaptureStep(eyebrow: "Scan a wine", title: "Snap the label",
                                    subtitle: "Fill the frame with the front label. You'll get the details and the average price.",
                                    image: $image) { typed in
                            wine.name = typed
                            begin()
                        }
                    } else {
                        result
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.top, 10).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(Palette.paper.ignoresSafeArea())
        .onChange(of: image) { _, img in if img != nil { begin() } }
        .fullScreenCover(isPresented: $tasteNow) { TastingFlow(blind: false, wine: wine, image: image, price: price) }
    }

    private func begin() {
        withAnimation { started = true }
        Task { await identify() }
    }

    @ViewBuilder private var result: some View {
        if let img = image {
            Image(uiImage: img).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        }
        if working {
            HStack(spacing: 12) {
                ProgressView()
                Text("Reading the label…").font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.vertical, 16)
        } else {
            if let e = error { Text(e).font(.system(size: 13.5)).foregroundStyle(Palette.wrong) }
            if identified { WineInfoCard(wine: wine) }
            else {
                TextField("Wine name", text: $wine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
            }
            PriceCard(price: price, loading: pricing, onRefresh: identified ? { Task { await findPrice() } } : nil)

            VStack(spacing: 12) {
                HStack {
                    Text("Bottles").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                    Spacer()
                    Stepper(value: $quantity, in: 1...99) {
                        Text("\(quantity)").font(.system(size: 15, weight: .semibold).monospacedDigit())
                    }
                    .fixedSize()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))

                Button { addToCellar() } label: {
                    Label(added ? "Added to cellar" : "Add to cellar", systemImage: added ? "checkmark" : "plus")
                }
                .buttonStyle(PrimaryButtonStyle(enabled: !added && !wine.name.isEmpty))
                .disabled(added || wine.name.isEmpty)

                Button { tasteNow = true } label: { Label("Taste it now", systemImage: "wineglass") }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(wine.name.isEmpty)
                if added {
                    Button("Done") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine)
                        .frame(maxWidth: .infinity).padding(.top, 4)
                }
            }
        }
    }

    private func identify() async {
        guard WineRecognizer.isAvailable else { return }
        working = true; error = nil
        do {
            let r: RecognitionResult
            if let img = image { r = try await WineRecognizer.identify(image: img) }
            else { r = try await WineRecognizer.identify(text: wine.name) }
            var w = r.identity
            if w.name.isEmpty { w.name = wine.name }
            wine = w
            identified = true
            journal.noteCost(r.costUSD)
        } catch { self.error = error.localizedDescription }
        working = false
        if identified { await findPrice() }
    }

    private func findPrice() async {
        pricing = true
        let (p, cost) = await WineRecognizer.averagePrice(for: wine)
        price = p
        journal.noteCost(cost)
        pricing = false
    }

    private func addToCellar() {
        var b = CellarBottle()
        b.wine = wine
        b.quantity = quantity
        b.price = price
        if let img = image { b.photo = journal.savePhoto(img, id: b.id) }
        journal.upsert(b)
        Haptics.success()
        withAnimation { added = true }
    }
}

// MARK: - Tasting (known wine or blind)

struct TastingFlow: View {
    @Environment(JournalStore.self) private var journal
    @Environment(GameProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss

    let blind: Bool
    var wine: WineIdentity? = nil
    var image: UIImage? = nil
    var price: PriceInfo? = nil

    enum Step: Int, CaseIterable { case photo, identify, look, smell, taste, guess, verdict, done }
    @State private var ratingGuide = false
    @AppStorage("jero.seenRatingGuide") private var seenRatingGuide = false

    @State private var step: Step = .photo
    @State private var entry = JournalEntry()
    @State private var photo: UIImage? = nil
    @State private var working = false
    @State private var pricing = false
    @State private var error: String? = nil
    @State private var aromaQuery = ""
    @State private var expandedFamily: String? = nil
    @State private var grapeOptions: [String] = []
    @State private var countryOptions: [String] = []
    @State private var prepared = false

    private var steps: [Step] {
        Step.allCases.filter { s in
            if s == .guess && !blind { return false }
            if (s == .photo || s == .identify) && wine != nil { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(progress: Double(steps.firstIndex(of: step) ?? 0) / Double(max(1, steps.count - 1))) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case .photo: photoStep
                    case .identify: identifyStep
                    case .look: lookStep
                    case .smell: smellStep
                    case .taste: tasteStep
                    case .guess: guessStep
                    case .verdict: verdictStep
                    case .done: doneStep
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 10)
                .padding(.bottom, 120)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollIndicators(.hidden)
        }
        .background(Palette.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) { footer }
        .animation(.easeInOut(duration: 0.3), value: step)
        .onChange(of: photo) { _, img in if img != nil { go(.identify) } }
        .sheet(isPresented: $ratingGuide, onDismiss: { seenRatingGuide = true }) { RatingGuideSheet() }
        .onAppear {
            // the first blind tasting starts with how to score a wine
            if blind && !seenRatingGuide { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ratingGuide = true } }
            guard !prepared else { return }
            prepared = true
            entry.blind = blind ? true : nil
            if let w = wine {
                entry.wine = w
                entry.identified = true
                entry.price = price
                photo = image
                step = .look
            }
        }
    }

    private func go(_ s: Step) { withAnimation { step = s } }

    private func next() {
        if step == .verdict { finish(); return }
        if let i = steps.firstIndex(of: step), i + 1 < steps.count {
            if steps[i + 1] == .guess { prepareGuess() }
            go(steps[i + 1])
        }
    }

    @ViewBuilder private var footer: some View {
        switch step {
        case .photo, .identify, .done: EmptyView()
        default:
            Button(step == .verdict ? (blind ? "Reveal the wine" : "Save to journal") : "Continue") { next() }
                .buttonStyle(PrimaryButtonStyle(enabled: step != .guess || (entry.guessGrape != nil && entry.guessCountry != nil)))
                .disabled(step == .guess && (entry.guessGrape == nil || entry.guessCountry == nil))
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 10)
                .background(LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper], startPoint: .top, endPoint: .center).ignoresSafeArea())
        }
    }

    // ---- photo
    private var photoStep: some View {
        CaptureStep(eyebrow: blind ? "Blind tasting" : "New tasting", title: "Snap the label",
                    subtitle: blind ? "Jero reads the label and keeps the answer hidden until you've tasted."
                                    : "Fill the frame with the front label.",
                    image: $photo) { typed in
            entry.wine.name = typed
            go(.identify)
        }
    }

    // ---- identify (blind: only the price is shown)
    private var identifyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let img = photo {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                    .blur(radius: blind ? 14 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    .overlay {
                        if blind {
                            Label("Hidden until the end", systemImage: "eye.slash").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(.black.opacity(0.45)))
                        }
                    }
            }
            if working {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading the label…").font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.vertical, 16)
            } else if blind {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.identified ? "Got it. The wine stays secret for now." : "Couldn't read this label.")
                        .font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("The only clue is the price. Taste it, guess the grape and the country, then see how close you were.")
                        .font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                }
                PriceCard(price: entry.price, loading: pricing)
                if let e = error { Text(e).font(.system(size: 13.5)).foregroundStyle(Palette.wrong) }
                Button("Start blind tasting") { go(.look) }
                    .buttonStyle(PrimaryButtonStyle(enabled: entry.identified))
                    .disabled(!entry.identified)
            } else {
                if entry.identified { WineInfoCard(wine: entry.wine) }
                if let e = error { Text(e).font(.system(size: 13.5)).foregroundStyle(Palette.wrong) }
                TextField("Wine name", text: $entry.wine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                Button("Start tasting") { go(.look) }
                    .buttonStyle(PrimaryButtonStyle(enabled: !entry.wine.name.isEmpty))
                    .disabled(entry.wine.name.isEmpty)
            }
        }
        .task {
            guard !entry.identified, WineRecognizer.isAvailable else { return }
            working = true; error = nil
            do {
                let r: RecognitionResult
                if let img = photo { r = try await WineRecognizer.identify(image: img) }
                else { r = try await WineRecognizer.identify(text: entry.wine.name) }
                var w = r.identity
                if w.name.isEmpty { w.name = entry.wine.name }
                entry.wine = w
                entry.identified = true
                journal.noteCost(r.costUSD)
            } catch { self.error = error.localizedDescription }
            working = false
            if entry.identified && blind {
                pricing = true
                let (p, cost) = await WineRecognizer.averagePrice(for: entry.wine)
                entry.price = p
                journal.noteCost(cost)
                pricing = false
            }
        }
    }

    // ---- look
    private var colorFamily: String {
        let s = entry.wine.style
        return s == "white" || s == "sparkling" || s == "sweet" || s == "orange" ? "white" : (s == "rose" ? "rose" : "red")
    }

    private var lookStep: some View {
        let colors = ContentStore.shared.library.colors.filter { $0.chart == true && $0.family == colorFamily }
        return VStack(alignment: .leading, spacing: 18) {
            stepTitle("Look", "Which color is closest?")
            coach("Tilt your glass over something white. Judge depth at the center, and the hue at the rim.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4), spacing: 12) {
                ForEach(colors) { c in
                    Button { entry.colorID = c.id; Haptics.tap() } label: {
                        VStack(spacing: 5) {
                            Rectangle().fill(Color(hex: c.hex)).aspectRatio(1, contentMode: .fit)
                                .overlay(Rectangle().strokeBorder(entry.colorID == c.id ? Palette.ink : .clear, lineWidth: 2.5))
                            Text(c.name).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            scale("Intensity", value: $entry.intensity, labels: ["Pale", "Medium", "Deep"])
        }
    }

    // ---- smell
    private var smellStep: some View {
        let cats = ContentStore.shared.allAromaCategories()
        let q = aromaQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let results = q.isEmpty ? [] : cats.flatMap(\.items).filter { $0.lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: 18) {
            stepTitle("Smell", "What can you find in the glass?")
            coach("Take a short sniff. Swirl once and sniff again. Pick a family first, then the exact smell.")
            if !entry.aromas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.aromas, id: \.self) { a in
                            Button { entry.aromas.removeAll { $0 == a } } label: {
                                HStack(spacing: 6) {
                                    FlavorIcon(aroma: a, size: 16)
                                    Text(a).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.ink)
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.inkSoft)
                                }
                                .padding(.horizontal, 11).padding(.vertical, 7)
                                .background(Capsule().fill(Palette.card))
                                .overlay(Capsule().strokeBorder(Palette.wine.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
                TextField("Search aromas", text: $aromaQuery).textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(Capsule().fill(Palette.card))
            if !results.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(results, id: \.self) { aromaToggle($0, highlighted: false) } }
            }
            if !blind && !entry.wine.tastingNotes.isEmpty && q.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Try looking for", color: Palette.wine)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(entry.wine.tastingNotes, id: \.self) { n in aromaToggle(n, highlighted: true) }
                    }
                }
            }
            if q.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(cats) { cat in
                        let picked = cat.items.filter { entry.aromas.contains($0) }.count
                        let open = expandedFamily == cat.id
                        Button { withAnimation(.easeInOut(duration: 0.2)) { expandedFamily = open ? nil : cat.id } } label: {
                            HStack(spacing: 10) {
                                FlavorIcon(aroma: cat.items.first ?? "", size: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cat.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                                    Text(picked > 0 ? "\(picked) picked" : "\(cat.items.count) aromas").font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(picked > 0 ? Color(hex: cat.color).opacity(0.14) : Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(open ? Color(hex: cat.color) : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let id = expandedFamily, let cat = cats.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(cat.name)
                        FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(cat.items, id: \.self) { aromaToggle($0, highlighted: false) } }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: cat.color).opacity(0.10)))
                    .transition(.opacity)
                }
            }
        }
    }

    private func coach(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            BrandDroplet(size: 30)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.card))
            Text(text).font(.system(size: 14.5)).foregroundStyle(Palette.ink)
                .padding(12)
                .background(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14,
                                                   topTrailingRadius: 14, style: .continuous).fill(Palette.card))
        }
    }

    private func aromaToggle(_ a: String, highlighted: Bool) -> some View {
        let on = entry.aromas.contains(a)
        return Button {
            if on { entry.aromas.removeAll { $0 == a } } else { entry.aromas.append(a) }
            Haptics.tap()
        } label: {
            HStack(spacing: 5) {
                FlavorIcon(aroma: a, size: 16, color: on ? Palette.onWine : nil)
                Text(a).font(.system(size: 13.5, weight: .medium))
            }
            .foregroundStyle(on ? Palette.onWine : Palette.ink)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(on ? Palette.wine : (highlighted ? Palette.wineSoft : Palette.card)))
        }
        .buttonStyle(.plain)
    }

    // ---- taste
    private var tasteStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Taste", "Structure, one sensation at a time.")
            coach("Take a sip and let it coat your mouth. Mouth watering? That's acidity. Drying gums? That's tannin.")
            scale("Sweetness", value: $entry.sweetness, labels: ["Dry", "Off-dry", "Medium", "Sweet"])
            scale("Acidity", value: $entry.acidity, labels: ["Low", "Med−", "Medium", "Med+", "High"])
            if colorFamily == "red" {
                scale("Tannin", value: $entry.tannin, labels: ["Low", "Med−", "Medium", "Med+", "High"])
            }
            scale("Body", value: $entry.body, labels: ["Light", "Med−", "Medium", "Med+", "Full"])
            scale("Finish", value: $entry.finish, labels: ["Short", "Med−", "Medium", "Med+", "Long"])
        }
    }

    // ---- guess (blind)
    private func prepareGuess() {
        guard grapeOptions.isEmpty else { return }
        let lib = ContentStore.shared.library
        let truthGrape = matchGrape(entry.wine.grapes.first)?.name ?? entry.wine.grapes.first ?? ""
        let berry = matchGrape(entry.wine.grapes.first)?.berry ?? (colorFamily == "red" ? .black : .white)
        var g = lib.grapes.filter { $0.berry == berry && $0.name != truthGrape && $0.level <= 2 }.map(\.name).shuffled().prefix(3).map { $0 }
        if !truthGrape.isEmpty { g.append(truthGrape) }
        grapeOptions = g.shuffled()
        let truthCountry = entry.wine.country
        var c = lib.regions.filter { $0.kind == "country" && $0.name != truthCountry }.map(\.name).shuffled().prefix(3).map { $0 }
        if !truthCountry.isEmpty { c.append(truthCountry) }
        countryOptions = c.shuffled()
    }

    private var guessStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Your guess", "Trust your nose and palate.")
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Grape")
                ForEach(grapeOptions, id: \.self) { g in option(g, selected: entry.guessGrape == g) { entry.guessGrape = g } }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Country")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(countryOptions, id: \.self) { c in option(c, selected: entry.guessCountry == c) { entry.guessCountry = c } }
                }
            }
        }
    }

    private func option(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.tap() } label: { Text(text) }
            .buttonStyle(TileStyle(state: selected ? .selected : .idle))
    }

    // ---- verdict
    private var verdictStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                stepTitle("Verdict", "Score it out of 100, like the critics.")
                Spacer()
                Button { ratingGuide = true } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 20)).foregroundStyle(Palette.wine)
                }
            }
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(entry.points)").font(.system(size: 64, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.bordeaux)
                        .contentTransition(.numericText())
                    Text("/100").font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.inkFaint)
                }
                Text(RatingGuide.band(entry.points).0).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine)
            }
            .frame(maxWidth: .infinity)
            Slider(value: Binding(get: { Double(entry.points) }, set: { entry.rating = Int($0.rounded()); Haptics.tap() }), in: 50...100, step: 1)
                .tint(Palette.wine)
            HStack {
                Text("50").font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                Spacer()
                Text("80 good · 90 outstanding · 95+ classic").font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                Spacer()
                Text("100").font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("What stood out")
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(["Balanced", "Long finish", "Intense", "Complex", "Great value", "Would buy again", "Too oaky", "Too sweet", "Harsh"], id: \.self) { q in
                        let on = entry.quality.contains(q)
                        Button {
                            if on { entry.quality.removeAll { $0 == q } } else { entry.quality.append(q) }
                        } label: {
                            Text(q).font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(on ? Palette.onWine : Palette.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(on ? Palette.wine : Palette.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Notes")
                TextField("Where, with whom, with what…", text: $entry.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
            }
        }
    }

    // ---- done / reveal
    private var doneStep: some View {
        let typical = entry.wine.tastingNotes.map { $0.lowercased() }
        let found = entry.aromas.filter { typical.contains($0.lowercased()) }
        return VStack(alignment: .leading, spacing: 18) {
            if blind {
                ScreenHeader(eyebrow: "Blind tasting", title: "It was…")
                if let s = entry.score {
                    HStack(spacing: 18) {
                        ZStack {
                            GoalRing(progress: Double(s) / 100, lineWidth: 6).frame(width: 84, height: 84)
                            VStack(spacing: 0) {
                                Text("\(s)").font(.system(size: 26, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                                Text("/100").font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(TastingScore.breakdown(entry).enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 8) {
                                    Image(systemName: item.2 ? "checkmark.circle.fill" : "circle.dashed")
                                        .font(.system(size: 13)).foregroundStyle(item.2 ? Palette.correct : Palette.inkFaint)
                                    Text(item.1).font(.system(size: 13.5)).foregroundStyle(Palette.ink)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                }
                WineInfoCard(wine: entry.wine)
                if entry.price != nil { PriceCard(price: entry.price) }
            } else {
                ScreenHeader(eyebrow: "Journal", title: "Saved")
                if !typical.isEmpty {
                    Text("You found \(found.count) of \(typical.count) typical aromas").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                    Text(found.isEmpty ? "Next time, try smelling for: \(entry.wine.tastingNotes.prefix(3).joined(separator: ", "))."
                                       : "Nice nose. You spotted \(found.joined(separator: ", ")).")
                        .font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                }
            }
            Text("+\(blind ? 25 : 15) XP").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.brass)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func finish() {
        if let img = photo { entry.photo = journal.savePhoto(img, id: entry.id) }
        entry.date = Date()
        if blind { entry.score = TastingScore.total(entry) }
        journal.upsert(entry)
        progress.award(xp: blind ? 25 : 15)
        Haptics.success()
        go(.done)
    }

    private func stepTitle(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink)
            Text(sub).font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
        }
    }

    private func scale(_ title: String, value: Binding<Int>, labels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    let v = i + 1
                    Button { value.wrappedValue = v; Haptics.tap() } label: {
                        Text(l).font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(value.wrappedValue == v ? Palette.onWine : Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(value.wrappedValue == v ? Palette.wine : Palette.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

func matchGrape(_ name: String?) -> Grape? {
    guard let n = name?.lowercased(), !n.isEmpty else { return nil }
    return ContentStore.shared.library.grapes.first { g in
        g.name.lowercased() == n || n.contains(g.name.lowercased()) || (g.aka ?? []).contains { $0.lowercased() == n }
    }
}

/// Blind-tasting score out of 100: grape 30, country 20, aromas 30, structure 20.
enum TastingScore {
    static func grapeRight(_ e: JournalEntry) -> Bool {
        guard let g = e.guessGrape?.lowercased(), !g.isEmpty else { return false }
        return e.wine.grapes.contains { $0.lowercased().contains(g) || g.contains($0.lowercased()) }
    }
    static func countryRight(_ e: JournalEntry) -> Bool {
        guard let c = e.guessCountry, !c.isEmpty else { return false }
        return e.wine.country.localizedCaseInsensitiveContains(c) || c.localizedCaseInsensitiveContains(e.wine.country)
    }
    static func aromaFraction(_ e: JournalEntry) -> Double {
        let typical = e.wine.tastingNotes.map { $0.lowercased() }
        guard !typical.isEmpty else { return 0.5 }
        var hits = 0.0
        let fams = Set(typical.compactMap { ContentStore.shared.aromaCategory(forItem: $0)?.id })
        for a in e.aromas {
            if typical.contains(a.lowercased()) { hits += 1 }
            else if let f = ContentStore.shared.aromaCategory(forItem: a)?.id, fams.contains(f) { hits += 0.5 }
        }
        return min(1, hits / Double(min(4, typical.count)))
    }
    static func structureFraction(_ e: JournalEntry) -> Double {
        guard let g = matchGrape(e.wine.grapes.first) else { return 0.5 }
        var checks = [abs(g.body - e.body) <= 1, abs(g.acidity - e.acidity) <= 1]
        if g.berry == .black { checks.append(abs(g.tannin - e.tannin) <= 1) }
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }
    static func total(_ e: JournalEntry) -> Int {
        let s = (grapeRight(e) ? 30.0 : 0) + (countryRight(e) ? 20 : 0) + aromaFraction(e) * 30 + structureFraction(e) * 20
        return Int(s.rounded())
    }
    /// (id, text, good)
    static func breakdown(_ e: JournalEntry) -> [(String, String, Bool)] {
        [("g", grapeRight(e) ? "Grape: \(e.guessGrape ?? "") ✓" : "Grape: you said \(e.guessGrape ?? "–")", grapeRight(e)),
         ("c", countryRight(e) ? "Country: \(e.guessCountry ?? "") ✓" : "Country: you said \(e.guessCountry ?? "–")", countryRight(e)),
         ("a", "Aromas: \(Int((aromaFraction(e) * 100).rounded()))% match", aromaFraction(e) >= 0.5),
         ("s", "Structure: \(Int((structureFraction(e) * 100).rounded()))% match", structureFraction(e) >= 0.5)]
    }
}

// MARK: - Tasting detail

struct EntryDetailView: View {
    let entryID: UUID
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        if let e = journal.entries.first(where: { $0.id == entryID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let img = JournalStore.image(e.photo) {
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 260).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    }
                    HStack(alignment: .top) {
                        ScreenHeader(eyebrow: (e.isBlind ? "Blind · " : "") + e.date.formatted(date: .abbreviated, time: .omitted), title: e.title,
                                     subtitle: [e.wine.vintage, e.wine.producer, e.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                        VStack(spacing: 0) {
                            Text("\(e.points)").font(.system(size: 30, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.bordeaux)
                            Text(e.score != nil ? "/100" : "/10").font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                        }
                        .padding(.top, 20)
                    }
                    if e.isBlind {
                        GroupCard {
                            ForEach(Array(TastingScore.breakdown(e).enumerated()), id: \.offset) { i, item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.2 ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(item.2 ? Palette.correct : Palette.inkFaint)
                                    Text(item.1).font(.system(size: 14.5)).foregroundStyle(Palette.ink)
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .overlay(alignment: .bottom) { if i < 3 { Hairline().padding(.leading, 40) } }
                            }
                        }
                    }
                    if e.identified { WineInfoCard(wine: e.wine) }
                    if let p = e.price { PriceCard(price: p) }
                    if let c = e.colorID.flatMap({ ContentStore.shared.color($0) }) {
                        HStack(spacing: 12) {
                            Rectangle().fill(Color(hex: c.hex)).frame(width: 36, height: 36)
                            Text("Color: \(c.name)").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                    }
                    if !e.aromas.isEmpty {
                        section("Your nose") {
                            FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(e.aromas, id: \.self) { AromaChip(text: $0, compact: true) } }
                        }
                    }
                    section("Your palate") {
                        VStack(alignment: .leading, spacing: 8) {
                            row("Sweetness", e.sweetness, of: 4)
                            row("Acidity", e.acidity, of: 5)
                            if e.wine.style == "red" { row("Tannin", e.tannin, of: 5) }
                            row("Body", e.body, of: 5)
                            row("Finish", e.finish, of: 5)
                        }
                    }
                    if !e.quality.isEmpty { section("Stood out") { Text(e.quality.joined(separator: " · ")).font(.system(size: 14.5)) } }
                    if !e.notes.isEmpty { section("Notes") { Text(e.notes).font(.system(size: 15)).foregroundStyle(Palette.ink) } }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Delete tasting").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.wrong)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this tasting?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { journal.delete(e); dismiss() }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            c()
        }
    }

    private func row(_ name: String, _ v: Int, of n: Int) -> some View {
        HStack(spacing: 12) {
            Text(name).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink).frame(width: 80, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(1...n, id: \.self) { i in Capsule().fill(i <= v ? Palette.wine : Palette.line).frame(height: 5) }
            }
        }
    }
}

// MARK: - Cellar bottle detail

struct CellarDetailView: View {
    let bottleID: UUID
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var pricing = false
    @State private var tasting = false

    var body: some View {
        if let b = journal.cellar.first(where: { $0.id == bottleID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let img = JournalStore.image(b.photo) {
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 260).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                    }
                    ScreenHeader(eyebrow: "In your cellar", title: b.title,
                                 subtitle: "Added " + b.added.formatted(date: .abbreviated, time: .omitted))
                    PriceCard(price: b.price, loading: pricing, quantity: b.quantity) { Task { await refresh(b) } }
                    HStack {
                        Text("Bottles").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                        Spacer()
                        Stepper(value: Binding(get: { b.quantity }, set: { v in var c = b; c.quantity = v; journal.upsert(c) }), in: 0...99) {
                            Text("\(b.quantity)").font(.system(size: 15, weight: .semibold).monospacedDigit())
                        }
                        .fixedSize()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                    WineInfoCard(wine: b.wine)
                    Button { tasting = true } label: { Label("Taste this bottle", systemImage: "wineglass") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Remove from cellar").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.wrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $tasting) {
                TastingFlow(blind: false, wine: b.wine, image: JournalStore.image(b.photo), price: b.price)
            }
            .confirmationDialog("Remove this wine from your cellar?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { journal.delete(b); dismiss() }
            }
        }
    }

    private func refresh(_ b: CellarBottle) async {
        pricing = true
        let (p, cost) = await WineRecognizer.averagePrice(for: b.wine)
        journal.noteCost(cost)
        if let p { var c = b; c.price = p; journal.upsert(c) }
        pricing = false
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// The 100-point scale, as critics use it.
enum RatingGuide {
    static let bands: [(ClosedRange<Int>, String, String)] = [
        (96...100, "Classic", "A great wine: everything in balance, complex and long. Rare."),
        (90...95, "Outstanding", "Real character and style. A wine you remember."),
        (85...89, "Very good", "Well made, with something special about it."),
        (80...84, "Good", "Solid and pleasant; nothing wrong, nothing striking."),
        (70...79, "Average", "Drinkable but plain, or with small flaws."),
        (50...69, "Below average", "Faulty, unbalanced or dull."),
    ]
    static func band(_ p: Int) -> (String, String) {
        let b = bands.first { $0.0.contains(p) } ?? bands.last!
        return (b.1, b.2)
    }
}

struct RatingGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "Before you taste", title: "Scoring out of 100",
                             subtitle: "Jero uses the 100-point scale made famous by Robert Parker and used by Wine Spectator, James Suckling and Vinous. Every wine starts at 50; the points above that reward what you find in the glass.")
                VStack(spacing: 0) {
                    ForEach(Array(RatingGuide.bands.enumerated()), id: \.offset) { i, b in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(b.0.lowerBound)–\(b.0.upperBound)").font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white).frame(width: 64, height: 26)
                                .background(Capsule().fill(Palette.bordeaux.opacity(1 - Double(i) * 0.13)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(b.2).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if i < RatingGuide.bands.count - 1 { Hairline() }
                    }
                }
                .cardStyle(padding: 14)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("How the points add up")
                    Text("Critics weigh balance (fruit, acid, tannin, alcohol in harmony), intensity, complexity and length of the finish, the same BLIC you learn in the course. Score what is in the glass, not the label or the price.")
                        .font(.system(size: 15)).foregroundStyle(Palette.ink).lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle(padding: 16)
                Button { dismiss() } label: {
                    Text("Got it").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.bordeaux))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(Metrics.margin)
        }
        .background(Palette.paper.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
