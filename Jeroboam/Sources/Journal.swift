import SwiftUI
import PhotosUI
import Observation

// MARK: - Model & store

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
    var rating = 7
    var quality: [String] = []
    var notes = ""

    var title: String { wine.name.isEmpty ? "Untitled wine" : wine.name }
}

@Observable
final class JournalStore {
    var entries: [JournalEntry] = [] { didSet { save() } }
    var lookups = 0 { didSet { UserDefaults.standard.set(lookups, forKey: "jero.lookups") } }
    var spentUSD: Double = 0 { didSet { UserDefaults.standard.set(spentUSD, forKey: "jero.spent") } }

    @ObservationIgnored private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("journal.json")
    }()

    static var photoDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    init() {
        if let data = try? Data(contentsOf: url), let e = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = e
        }
        lookups = UserDefaults.standard.integer(forKey: "jero.lookups")
        spentUSD = UserDefaults.standard.double(forKey: "jero.spent")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: url, options: .atomic) }
    }

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
        if let p = e.photo { try? FileManager.default.removeItem(at: Self.photoDir.appendingPathComponent(p)) }
    }

    var averageRating: Double {
        entries.isEmpty ? 0 : Double(entries.map(\.rating).reduce(0, +)) / Double(entries.count)
    }
}

// MARK: - Journal tab

struct JournalView: View {
    @Environment(JournalStore.self) private var journal
    @State private var newTasting = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(eyebrow: "Tasting notebook", title: "Journal")

                    Button { newTasting = true } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(Palette.onWine.opacity(0.14)).frame(width: 46, height: 46)
                                Image(systemName: "camera").font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.onWine)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("New tasting").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.onWine)
                                Text(WineRecognizer.isAvailable ? "Snap the label. We'll find the wine, you taste it."
                                                                : "Photograph the label and log your tasting.")
                                    .font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.onWine.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.wine))
                    }
                    .buttonStyle(PressableStyle())

                    if !journal.entries.isEmpty {
                        HStack(spacing: 10) {
                            stat("\(journal.entries.count)", "wines")
                            stat(String(format: "%.1f", journal.averageRating), "avg. score")
                            stat(topGrape ?? "—", "top grape")
                        }
                    }

                    if journal.entries.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(journal.entries) { e in
                                NavigationLink(value: e) { EntryTile(entry: e) }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Metrics.margin)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: JournalEntry.self) { e in EntryDetailView(entryID: e.id) }
        }
        .fullScreenCover(isPresented: $newTasting) { NewTastingFlow() }
    }

    private var topGrape: String? {
        let all = journal.entries.flatMap { $0.wine.grapes }
        let counts = Dictionary(all.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.display(22)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).kerning(1).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GrapeMark(tones: [Palette.line, Palette.lockedDeep, Palette.cardAlt]).frame(height: 90)
            Text("Your cellar of memories").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("Every bottle you taste becomes a page: the photo, what you smelled, how much you loved it. Over time you'll see your palate take shape.")
                .font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

struct EntryTile: View {
    let entry: JournalEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let img = JournalStore.image(entry.photo) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(height: 170).frame(maxWidth: .infinity).clipped()
                } else {
                    ZStack {
                        Rectangle().fill(styleColor(entry.wine.style).opacity(0.18))
                        GrapeMark(tones: [styleColor(entry.wine.style), styleColor(entry.wine.style).mix(with: .black, 0.2),
                                          styleColor(entry.wine.style).mix(with: .white, 0.2)]).frame(height: 70)
                    }
                    .frame(height: 170)
                }
                Text("\(entry.rating)").font(.display(26, .black)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Palette.bordeaux))
                    .padding(8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                Text([entry.wine.vintage, entry.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            .padding(12)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

func styleColor(_ s: String) -> Color {
    switch s {
    case "white": return Color(hex: "#D9B22E")
    case "rose": return Color(hex: "#E8708A")
    case "sparkling": return Color(hex: "#C9A54A")
    case "fortified", "sweet": return Color(hex: "#B8701E")
    case "orange": return Color(hex: "#E08A3C")
    default: return Color(hex: "#8B1538")
    }
}

// MARK: - New tasting flow

struct NewTastingFlow: View {
    @Environment(JournalStore.self) private var journal
    @Environment(GameProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss

    enum Step: Int, CaseIterable { case photo, identify, look, smell, taste, verdict, done }

    @State private var step: Step = .photo
    @State private var entry = JournalEntry()
    @State private var image: UIImage? = nil
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var working = false
    @State private var error: String? = nil
    @State private var lastCost: Double? = nil
    @State private var typedName = ""
    @State private var aromaQuery = ""
    @State private var expandedFamily: String? = nil
    @State private var infoTab = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case .photo: photoStep
                    case .identify: identifyStep
                    case .look: lookStep
                    case .smell: smellStep
                    case .taste: tasteStep
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
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $image).ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    image = img
                }
            }
        }
        .onChange(of: image) { _, img in
            if img != nil { go(.identify) }
        }
    }

    private func go(_ s: Step) { withAnimation { step = s } }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(height: 6)
                    Capsule().fill(Palette.pink).frame(width: geo.size.width * CGFloat(step.rawValue) / CGFloat(Step.allCases.count - 1), height: 6)
                        .animation(.spring(), value: step)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    @ViewBuilder private var footer: some View {
        switch step {
        case .photo, .identify, .done: EmptyView()
        default:
            Button(step == .verdict ? "Save to journal" : "Continue") {
                let order = Step.allCases
                if step == .verdict { finish() }
                else if let i = order.firstIndex(of: step), i + 1 < order.count { go(order[i + 1]) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 10)
            .background(LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper], startPoint: .top, endPoint: .center).ignoresSafeArea())
        }
    }

    // ---- 1. photo
    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(eyebrow: "New tasting", title: "Snap the label",
                         subtitle: "Fill the frame with the front label. Good light helps the label reader.")
            Button { showCamera = true } label: {
                Label("Take a photo", systemImage: "camera.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose from library").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            }
            HStack {
                Rectangle().fill(Palette.line).frame(height: 1)
                Text("OR").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.inkFaint)
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Type the wine").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                TextField("e.g. Cloudy Bay Sauvignon Blanc 2023", text: $typedName)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                Button("Continue without photo") {
                    entry.wine.name = typedName
                    go(.identify)
                }
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.wine)
                .disabled(typedName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // ---- 2. identify
    private var identifyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            if working {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading the label…").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.vertical, 20)
            } else if entry.identified {
                identityCard(entry.wine)
                Text("Not right? Edit the name below.").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
            }
            if let e = error {
                Text(e).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.wrong)
            }
            if !working {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wine").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSoft)
                    TextField("Wine name", text: $entry.wine.name)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                    HStack(spacing: 10) {
                        TextField("Vintage", text: $entry.wine.vintage).keyboardType(.numberPad)
                            .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                        Picker("Style", selection: $entry.wine.style) {
                            ForEach(["red", "white", "rose", "sparkling", "orange", "sweet", "fortified"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .tint(Palette.ink)
                        .padding(8).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                    }
                }
                Button("Start tasting") { go(.look) }
                    .buttonStyle(PrimaryButtonStyle(enabled: !entry.wine.name.isEmpty))
                    .disabled(entry.wine.name.isEmpty)
                if WineRecognizer.isAvailable && !entry.identified && !entry.wine.name.isEmpty && image == nil {
                    Button("Look up this wine") { Task { await lookup(text: entry.wine.name) } }
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.wine)
                }
            }
        }
        .task {
            if let img = image, !entry.identified, WineRecognizer.isAvailable {
                await lookup(image: img)
            } else if image == nil, !entry.wine.name.isEmpty, WineRecognizer.isAvailable, !entry.identified {
                await lookup(text: entry.wine.name)
            }
        }
    }

    private func identityCard(_ w: WineIdentity) -> some View {
        let region = ContentStore.shared.library.regions.first { r in
            !w.region.isEmpty && (w.region.localizedCaseInsensitiveContains(r.name) || r.name.localizedCaseInsensitiveContains(w.region))
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wineglass").font(.system(size: 20, weight: .semibold)).foregroundStyle(styleColor(w.style))
                    .frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 12).fill(styleColor(w.style).opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.producer.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(1).foregroundStyle(Palette.inkSoft)
                    Text([w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
            Picker("Info", selection: $infoTab) {
                Text("This bottle").tag(0)
                Text("In the glass").tag(1)
                Text("Region").tag(2)
            }
            .pickerStyle(.segmented)
            switch infoTab {
            case 1:
                if !w.tastingNotes.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(w.tastingNotes.prefix(5), id: \.self) { n in
                            VStack(spacing: 5) {
                                FlavorIcon(aroma: n, size: 30)
                                Text(n).font(.system(size: 10.5, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                if !w.palate.isEmpty { Text(w.palate).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.85)) }
                if !w.food.isEmpty {
                    Text("WITH: " + w.food.prefix(3).joined(separator: " · ").uppercased()).font(.system(size: 11, weight: .semibold)).kerning(0.6)
                        .foregroundStyle(Palette.inkSoft)
                }
            case 2:
                if let r = region {
                    Text(r.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(r.summary).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.85))
                    if let m = r.map {
                        WineMapView(mapID: m, highlight: Set(r.highlight ?? [r.id]), showCities: false, labelScale: 0.85)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else {
                    Text([w.region, w.country].filter { !$0.isEmpty }.joined(separator: ", "))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                }
            default:
                Text([w.region, w.country].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                if !w.grapes.isEmpty {
                    Text(w.grapes.joined(separator: " · ").uppercased()).font(.system(size: 11, weight: .semibold)).kerning(0.8).foregroundStyle(styleColor(w.style))
                }
                if w.priceHigh > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill").font(.system(size: 12))
                        Text("Typically \(price(w.priceLow, w.currency))–\(price(w.priceHigh, w.currency)) a bottle").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Palette.ink)
                    Text("Estimated typical retail price, not a live quote.").font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                }
                if !w.funFact.isEmpty {
                    Text(w.funFact).font(.system(size: 13.5, weight: .medium).italic()).foregroundStyle(Palette.inkSoft)
                }
                if !w.found {
                    Text("Best guess, so double-check the name below.").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.pink)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
    }

    private func price(_ v: Double, _ cur: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = cur.isEmpty ? "USD" : cur
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }

    private func lookup(image: UIImage) async {
        working = true; error = nil
        do {
            let r = try await WineRecognizer.identify(image: image)
            apply(r)
        } catch { self.error = error.localizedDescription }
        working = false
    }

    private func lookup(text: String) async {
        working = true; error = nil
        do {
            let r = try await WineRecognizer.identify(text: text)
            apply(r)
        } catch { self.error = error.localizedDescription }
        working = false
    }

    private func apply(_ r: RecognitionResult) {
        var w = r.identity
        if w.name.isEmpty { w.name = entry.wine.name }
        entry.wine = w
        entry.identified = true
        journal.lookups += 1
        journal.spentUSD += r.costUSD
        lastCost = r.costUSD
    }

    // ---- 3. look
    private var lookStep: some View {
        let family = entry.wine.style == "white" || entry.wine.style == "sparkling" || entry.wine.style == "sweet" || entry.wine.style == "orange"
            ? "white" : (entry.wine.style == "rose" ? "rose" : "red")
        let colors = ContentStore.shared.library.colors.filter { $0.chart == true && $0.family == family }
        return VStack(alignment: .leading, spacing: 18) {
            stepTitle("1 · LOOK", "Which color is closest?")
            coach("Tilt your glass over something white. Judge depth at the center, and the hue at the rim.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(colors) { c in
                    Button { entry.colorID = c.id; Haptics.tap() } label: {
                        VStack(spacing: 6) {
                            ColorSwatch(core: Color(hex: c.hex), rim: Color(hex: c.rim)).aspectRatio(1, contentMode: .fit)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(entry.colorID == c.id ? Palette.ink : .clear, lineWidth: 3))
                            Text(c.name).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            scale("Intensity", value: $entry.intensity, labels: ["Pale", "Medium", "Deep"])
        }
    }

    // ---- 4. smell
    private var smellStep: some View {
        let cats = ContentStore.shared.allAromaCategories()
        let q = aromaQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let results = q.isEmpty ? [] : cats.flatMap(\.items).filter { $0.lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: 18) {
            stepTitle("2 · SMELL", "What can you find in the glass?")
            coach("Take a short sniff. Swirl once and sniff again. Pick a family first, then the exact smell.")
            if !entry.aromas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECTED (\(entry.aromas.count))").font(.system(size: 10.5, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(entry.aromas, id: \.self) { a in
                                Button { entry.aromas.removeAll { $0 == a } } label: {
                                    HStack(spacing: 6) {
                                        FlavorIcon(aroma: a, size: 18)
                                        Text(a).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.inkSoft)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Capsule().fill(Palette.card))
                                    .overlay(Capsule().strokeBorder(Palette.pink.opacity(0.6), lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
                TextField("Search aromas…", text: $aromaQuery).textInputAutocapitalization(.never)
            }
            .padding(14)
            .background(Capsule().fill(Palette.card))
            if !results.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(results, id: \.self) { aromaToggle($0, highlighted: false) } }
            }
            if !entry.wine.tastingNotes.isEmpty && q.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRY LOOKING FOR").font(.system(size: 10.5, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.pink)
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
                            VStack(spacing: 6) {
                                FlavorIcon(aroma: cat.items.first ?? "", size: 30)
                                Text(cat.name).font(.system(size: 14.5, weight: .bold)).foregroundStyle(Palette.ink)
                                Text(picked > 0 ? "\(picked) picked" : " ").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                                Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.inkSoft)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(picked > 0 ? Color(hex: cat.color).opacity(0.14) : Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(open ? Color(hex: cat.color) : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let id = expandedFamily, let cat = cats.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(cat.name.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
                        FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(cat.items, id: \.self) { aromaToggle($0, highlighted: false) } }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: cat.color).opacity(0.10)))
                    .transition(.opacity)
                }
            }
        }
    }

    private func coach(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BrandDroplet(size: 44)
                .padding(8)
                .background(Circle().fill(Palette.card))
            Text(text).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                .padding(14)
                .background(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                                                   topTrailingRadius: 18, style: .continuous).fill(Palette.card))
        }
    }

    private func aromaToggle(_ a: String, highlighted: Bool) -> some View {
        let on = entry.aromas.contains(a)
        return Button {
            if on { entry.aromas.removeAll { $0 == a } } else { entry.aromas.append(a) }
            Haptics.tap()
        } label: {
            Text(a).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Palette.onWine : Palette.ink)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Capsule().fill(on ? Palette.wine : (highlighted ? Palette.wineSoft : Palette.card)))
                .overlay(Capsule().strokeBorder(highlighted && !on ? Palette.pink.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // ---- 5. taste
    private var tasteStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepTitle("3 · TASTE", "Structure, one sensation at a time.")
            coach("Take a sip and let it coat your mouth. Mouth watering? That's acidity. Drying gums? That's tannin.")
            scale("Sweetness", value: $entry.sweetness, labels: ["Dry", "Off-dry", "Medium", "Sweet"])
            scale("Acidity", value: $entry.acidity, labels: ["Low", "Med−", "Medium", "Med+", "High"])
            if entry.wine.style == "red" || entry.wine.style == "fortified" {
                scale("Tannin", value: $entry.tannin, labels: ["Low", "Med−", "Medium", "Med+", "High"])
            }
            scale("Body", value: $entry.body, labels: ["Light", "Med−", "Medium", "Med+", "Full"])
            scale("Finish", value: $entry.finish, labels: ["Short", "Med−", "Medium", "Med+", "Long"])
        }
    }

    // ---- 6. verdict
    private var verdictStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepTitle("4 · VERDICT", "How much did you enjoy it?")
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(entry.rating)").font(.display(96, .black)).foregroundStyle(Palette.bordeaux).contentTransition(.numericText())
                Text("/10").font(.display(28)).foregroundStyle(Palette.inkFaint)
            }
            .frame(maxWidth: .infinity)
            Slider(value: Binding(get: { Double(entry.rating) }, set: { entry.rating = Int($0.rounded()); Haptics.tap() }), in: 1...10, step: 1)
                .tint(Palette.pink)
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT STOOD OUT").font(.system(size: 10.5, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(["Balanced", "Long finish", "Intense", "Complex", "Great value", "Would buy again", "Too oaky", "Too sweet", "Harsh"], id: \.self) { q in
                        let on = entry.quality.contains(q)
                        Button {
                            if on { entry.quality.removeAll { $0 == q } } else { entry.quality.append(q) }
                        } label: {
                            Text(q).font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(on ? Palette.onWine : Palette.ink)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Capsule().fill(on ? Palette.wine : Palette.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES").font(.system(size: 10.5, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
                TextField("Where, with whom, with what…", text: $entry.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
            }
        }
    }

    // ---- done
    private var doneStep: some View {
        let typical = entry.wine.tastingNotes.map { $0.lowercased() }
        let found = entry.aromas.filter { typical.contains($0.lowercased()) }
        return VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(eyebrow: "Journal", title: "Saved")
            if !typical.isEmpty {
                Text("You found \(found.count) of \(typical.count) typical aromas").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                Text(found.isEmpty ? "Next time, try smelling for: \(entry.wine.tastingNotes.prefix(3).joined(separator: ", "))."
                                   : "Nice nose. You spotted \(found.joined(separator: ", ")).")
                    .font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            Text("+15 XP for keeping your journal").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.brass)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func finish() {
        if let img = image { entry.photo = journal.savePhoto(img, id: entry.id) }
        entry.date = Date()
        journal.upsert(entry)
        progress.award(xp: 15)
        Haptics.success()
        go(.done)
    }

    private func stepTitle(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink)
            Text(sub).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.inkSoft)
        }
    }

    private func scale(_ title: String, value: Binding<Int>, labels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    let v = i + 1
                    Button { value.wrappedValue = v; Haptics.tap() } label: {
                        Text(l).font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(value.wrappedValue == v ? Palette.onWine : Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(value.wrappedValue == v ? Palette.wine : Palette.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Entry detail

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
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 300).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(e.date.formatted(date: .abbreviated, time: .omitted))
                            Text(e.title).font(.system(size: 24, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text([e.wine.vintage, e.wine.producer, e.wine.region].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text("\(e.rating)").font(.display(44, .black)).foregroundStyle(Palette.bordeaux)
                            Text("/10").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkFaint)
                        }
                    }
                    if let c = e.colorID.flatMap({ ContentStore.shared.color($0) }) {
                        HStack(spacing: 12) {
                            ColorSwatch(core: Color(hex: c.hex), rim: Color(hex: c.rim), corner: 10).frame(width: 44, height: 44)
                            Text(c.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                    }
                    if !e.aromas.isEmpty {
                        section("Your nose") {
                            FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(e.aromas, id: \.self) { AromaChip(text: $0, compact: true) } }
                        }
                    }
                    section("Your palate") {
                        VStack(alignment: .leading, spacing: 6) {
                            row("Sweetness", e.sweetness, of: 4)
                            row("Acidity", e.acidity, of: 5)
                            if e.wine.style == "red" { row("Tannin", e.tannin, of: 5) }
                            row("Body", e.body, of: 5)
                            row("Finish", e.finish, of: 5)
                        }
                    }
                    if !e.wine.tastingNotes.isEmpty {
                        section("Typically") {
                            Text(e.wine.tastingNotes.joined(separator: " · ")).font(.system(size: 14.5, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                    }
                    if !e.quality.isEmpty { section("Stood out") { Text(e.quality.joined(separator: " · ")).font(.system(size: 14.5)) } }
                    if !e.notes.isEmpty { section("Notes") { Text(e.notes).font(.system(size: 15)).foregroundStyle(Palette.ink) } }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Delete entry").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wrong)
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
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.inkSoft)
            c()
        }
    }

    private func row(_ name: String, _ v: Int, of n: Int) -> some View {
        HStack {
            Text(name).font(.system(size: 14, weight: .semibold)).frame(width: 90, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(1...n, id: \.self) { i in
                    Capsule().fill(i <= v ? Palette.pink : Palette.line).frame(height: 6)
                }
            }
        }
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
