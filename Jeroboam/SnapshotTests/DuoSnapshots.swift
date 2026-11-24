import XCTest
import SwiftUI
@testable import Jeroboam

/// Renders real app views at the iPhone Duo's exact sizes (outside, inside upright, inside sideways) without
/// needing the Duo simulator: each view is hosted in an offscreen window of that size and drawn to a PNG.
/// Sizes are the Duo's point sizes: 466×678 outside, 669×951 inside (turned: 951×669).
@MainActor
final class DuoSnapshots: XCTestCase {
    static let screens: [(String, CGSize)] = [
        ("outside", CGSize(width: 466, height: 678)),
        ("inside-portrait", CGSize(width: 669, height: 951)),
        ("inside-landscape", CGSize(width: 951, height: 669)),
    ]

    private var outDir: URL {
        let p = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        let u = URL(fileURLWithPath: p, isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func snap<V: View>(_ name: String, settle: TimeInterval = 2.0, @ViewBuilder _ make: () -> V) {
        let progress = GameProgress()
        progress.data.onboarded = true
        let journal = JournalStore.sample
        for (label, size) in Self.screens {
            // as on the Duo: the tabs stand up in a column on the right and the page gets the rest
            let root = AdaptiveRoot {
                HStack(spacing: 0) {
                    make().environment(\.windowWidth, size.width - AdaptiveLayout.railWidth).padding(.top, 30).frame(maxWidth: .infinity)
                    Color.clear.frame(width: AdaptiveLayout.railWidth)
                }
                .environment(\.hasRail, true)
                .overlay(alignment: .bottomTrailing) { DuoRail(selection: .constant(2)).frame(width: AdaptiveLayout.railWidth) }
                .overlay(alignment: .topLeading) {
                    let page = size.width - AdaptiveLayout.railWidth
                    AvatarButton(size: 32, ignoreRail: true).padding(.top, 32)
                        .offset(x: (page >= AdaptiveLayout.twoPaneThreshold ? page / 2 : page) - Metrics.margin - 32)
                }
            }
                .environment(progress)
                .environment(journal)
                .background(Palette.paper)
                .ignoresSafeArea()
            let host = NoInsetController(rootView: AnyView(root))
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            spin(settle)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            if let png = img.pngData() {
                try? png.write(to: outDir.appendingPathComponent("\(name)-\(label).png"))
                let a = XCTAttachment(image: img); a.name = "\(name)-\(label)"; a.lifetime = .keepAlways; add(a)
            }
            window.isHidden = true
        }
    }

    private func card(_ visual: String) -> Card? {
        ContentStore.shared.orderedLessons.flatMap(\.cards).first { $0.visual == visual }
    }

    func testGuidebook() {
        guard let unit = ContentStore.shared.course.levels.flatMap(\.units).first(where: { $0.title == "In the vineyard" }) else { return XCTFail("no unit") }
        snap("guidebook") { GuidebookView(unit: unit) }
    }

    func testVineYear() {
        guard let c = card("diagram:vine-cycle") else { return XCTFail("no card") }
        snap("vine-year") { ScrollView { LearnCard(card: c, topic: 1).padding(20) } }
    }

    func testClimate() {
        guard let c = card("diagram:climate") else { return XCTFail("no card") }
        snap("climate") { ScrollView { LearnCard(card: c, topic: 3).padding(20) } }
    }

    func testGrapeAnatomy() {
        guard let c = card("diagram:grape-anatomy") else { return XCTFail("no card") }
        snap("grape-anatomy") { ScrollView { LearnCard(card: c, topic: 2).padding(20) } }
    }

    func testMapExplorer() {
        snap("map-explorer", settle: 3.0) { MapExplorer(mapID: "france", highlight: ["pauillac"]) }
    }

    /// Whole-country explorers at the Duo sizes: regions, zones and appellations drawn together.
    func testMapExplorersCountries() {
        for id in ["france", "italy", "spain", "tuscany"] { snap("explorer-\(id)", settle: 3.0) { MapExplorer(mapID: id) } }
    }

    /// The Journal's wine map and charts, with the example data (an empty journal).
    func testJournalInsights() {
        snap("insights", settle: 3.0) { ScrollView { JournalInsights().padding(20) }.environment(JournalStore()) }
    }

    func testMatchCard() {
        guard let c = ContentStore.shared.orderedLessons.flatMap(\.cards).first(where: { $0.kind == .match }) else { return XCTFail("no match card") }
        snap("match") { MatchCard(card: c, locked: false, onAnswer: { _, _ in }).padding(20) }
    }

    /// The Foldable preview exactly as on a phone (inside sideways, a 440×956 phone window), with the full-screen map open.
    func testPreviewFullMap() {
        UserDefaults.standard.set(3, forKey: "jero.duoPreview")
        defer { UserDefaults.standard.set(0, forKey: "jero.duoPreview"); CoverHost.shared.content = nil }
        let progress = GameProgress(); progress.data.onboarded = true
        let size = CGSize(width: 440, height: 956)
        CoverHost.shared.content = AnyView(MapExplorer(mapID: "france").environment(\.coverClose, { CoverHost.shared.content = nil }))
        let root = DuoPreviewHost { AdaptiveRoot { RootView() } }.environment(progress).environment(JournalStore.sample)
        let host = UIHostingController(rootView: AnyView(root))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        spin(3.5)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
        if let png = img.pngData() { try? png.write(to: outDir.appendingPathComponent("preview-map-phone.png")) }
        window.isHidden = true
    }

    private func shot<V: View>(_ name: String, _ size: CGSize, settle: TimeInterval = 3.5, _ view: V) {
        let host = UIHostingController(rootView: AnyView(view))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        spin(settle)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
        if let png = img.pngData() { try? png.write(to: outDir.appendingPathComponent(name + ".png")) }
        window.isHidden = true
    }

    /// Where does the chopped map come from? The cover without the preview, and the preview without the cover.
    func testMapIsolation() {
        let progress = GameProgress(); progress.data.onboarded = true
        let journal = JournalStore.sample
        // 1. the cover in a Duo-sized window (no preview)
        CoverHost.shared.content = AnyView(MapExplorer(mapID: "france"))
        shot("iso1-cover-only", CGSize(width: 951, height: 669), AdaptiveRoot { RootView() }.environment(progress).environment(journal))
        CoverHost.shared.content = nil
        // 2. the preview with the map as plain content (no cover)
        UserDefaults.standard.set(3, forKey: "jero.duoPreview")
        shot("iso2-preview-direct", CGSize(width: 440, height: 956),
             DuoPreviewHost { AdaptiveRoot { MapExplorer(mapID: "france") } }.environment(progress).environment(journal))
        UserDefaults.standard.set(0, forKey: "jero.duoPreview")
    }

    func testDrinkWindow() {
        snap("drink-window") { VStack(spacing: 16) { DrinkWindowChart(window: "Now–2030", vintage: "2019"); DrinkWindowChart(window: "2026–2040", vintage: "2018") }.padding(20) }
    }

    func testSoloMap() {
        snap("solo-map") { VStack(spacing: 16) { VisualView(spec: "mapsolo:spain:rioja"); VisualView(spec: "map:spain:rioja", compact: true, hideAnswers: true) }.padding(20) }
    }

    func testBottleFull() {
        guard let w = ContentStore.shared.library.great?.first(where: { $0.bottle != nil }) else { return XCTFail("no wine") }
        snap("bottle-full") { BottleFullScreen(wine: w) }
    }

    // ---- every page, at all three Duo sizes
    private func page<V: View>(_ name: String, _ v: @autoclosure () -> V) { snap(name) { NavigationStack { v() } } }

    func testPages1() {
        page("grapes", GrapeListView())
        page("regions", RegionListView())
        page("wines", WinesScreen())
        page("great-list", GreatWinesScreen())
        page("aromas", AromaWheelScreen())
        page("colors", ColorChartScreen())
    }

    func testPages2() {
        page("styles", StylesScreen())
        page("tasting", TastingScreen())
        page("pairing", PairingScreen())
        page("glossary", GlossaryScreen())
        page("bottles", BottlesScreen())
        page("wine-cards", WineCardsScreen())
    }

    func testPages3() {
        page("boldness", BoldnessScreen())
        page("labels", LabelsScreen())
        page("style-guide", StyleGuideScreen())
        snap("profile") { ProfileView() }
        snap("onboarding") { OnboardingView() }
        if let g = ContentStore.shared.library.grapes.first { page("grape", GrapeDetailView(grape: g)) }
    }

    func testLesson() {
        let cards = ContentStore.shared.orderedLessons.first?.cards ?? []
        let q = ContentStore.shared.orderedLessons.flatMap(\.cards).filter { $0.kind != .learn }
        snap("lesson-learn") { LessonPlayer(session: Session(title: "Lesson", lessonID: nil, cards: Array(cards.prefix(4)))) }
        snap("lesson-question") { LessonPlayer(session: Session(title: "Practice", lessonID: nil, cards: Array(q.prefix(6)))) }
    }

    /// Someone doing a lesson on the Learn tab: list on the left, the lesson in the right-hand pane.
    func testLearnLesson() {
        let cards = ContentStore.shared.orderedLessons.first?.cards ?? []
        let firstQ = cards.firstIndex { $0.isQuestion } ?? 0
        LearnView.snapshotStart = 0
        snap("learn-lesson-card", settle: 2.5) { LearnView() }
        LearnView.snapshotStart = firstQ
        snap("learn-lesson-question", settle: 2.5) { LearnView() }
        LearnView.snapshotStart = nil
    }

    func testLearnHome() { snap("learn") { LearnView() } }
    func testRoot() { snap("root") { RootView() } }

    /// Each badge announcement, a moment in and when it has settled (phone size).
    func testBadgeStyles() {
        guard let a = Achievement.all.first(where: { $0.id == "streak-7" }) else { return XCTFail("no badge") }
        let size = CGSize(width: 393, height: 852)
        for style in BadgeStyle.allCases {
            for (label, wait) in [("mid", 1.2), ("end", 3.9)] {
                let root = BadgeAnnouncePage(achievement: a, date: Date(), style: style, onDone: {}).preferredColorScheme(.light)
                let host = UIHostingController(rootView: root)
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = host
                window.makeKeyAndVisible()
                host.view.frame = window.bounds
                host.view.layoutIfNeeded()
                spin(wait)
                let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
                let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
                if let png = img.pngData() { try? png.write(to: outDir.appendingPathComponent("badge-\(style.rawValue)-\(label).png")) }
                window.isHidden = true
            }
        }
    }

    /// The real app (RootView alone, nothing drawn around it). On the outer screen a 64 pt column on the right stands in for the
    /// strip iOS keeps for the camera and clock; the opened screen has none.
    func testRootFaithful() {
        let progress = GameProgress()
        progress.data.onboarded = true
        let journal = JournalStore.sample
        for (label, size) in Self.screens {
            let root = AdaptiveRoot { RootView() }
                .environment(progress).environment(journal).background(Palette.paper).ignoresSafeArea()
            let host = ColumnController(rootView: AnyView(root))
            host.column = label == "outside" ? 64 : 0
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            spin(2.5)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            if let png = img.pngData() { try? png.write(to: outDir.appendingPathComponent("rootfaithful-\(label).png")) }
            window.isHidden = true
        }
    }
    func testAtlas() { snap("atlas") { LibraryView() } }
    func testJournal() { snap("journal") { JournalView() } }
    func testPractice() { snap("practice") { PracticeView() } }

    func testGreatWine() {
        guard let w = ContentStore.shared.library.great?.first else { return XCTFail("no wine") }
        GreatWinePlaylist.wines = Array((ContentStore.shared.library.great ?? []).prefix(5))
        snap("great-wine") { NavigationStack { GreatWinePager(wine: w) } }
    }

    /// The "Full map" cover on a region page, drawn inside the page (the tabs stay in their column).
    func testRegionMapCover() {
        guard let r = ContentStore.shared.library.regions.first(where: { $0.id == "bordeaux" }) else { return XCTFail("no region") }
        RegionDetailView.snapshotExplore = true
        snap("region-map", settle: 3.0) { NavigationStack { RegionDetailView(region: r) } }
        RegionDetailView.snapshotExplore = false
    }

    func testRegions() {
        guard let r = ContentStore.shared.library.regions.first(where: { $0.id == "bordeaux" }) else { return XCTFail("no region") }
        snap("region") { NavigationStack { RegionDetailView(region: r) } }
    }

    /// The merged France map: layers, names inside the areas, and the phone-style layout on the upright inner screen.
    func testFranceDetail() {
        snap("fr-whole", settle: 4.0) { MapExplorer(mapID: "france") }
        snap("fr-pauillac", settle: 4.0) { MapExplorer(mapID: "france", highlight: ["pauillac"]) }
        snap("fr-nuits", settle: 4.0) { MapExplorer(mapID: "france", highlight: ["vosne-romanee"]) }
        snap("fr-subregions", settle: 4.0) { MapExplorer(mapID: "france", highlight: ["cote-de-beaune"]) }
        snap("pt-whole", settle: 3.0) { MapExplorer(mapID: "portugal") }
        snap("profile2") { ProfileView() }
    }

    /// Maps beyond the atlas: the list from Settings, a country page and its explorer.
    func testExtraAtlas() {
        snap("extra-list", settle: 3.0) { ExtraAtlasView() }
        for id in ["georgia", "new-york", "england-wales"] {
            guard let r = ContentStore.shared.region(id) else { continue }
            snap("extra-\(id)", settle: 3.0) { NavigationStack { RegionDetailView(region: r) } }
            snap("extra-explorer-\(id)", settle: 4.0) { MapExplorer(mapID: id) }
        }
        let m = ContentStore.shared.regionMatching("", country: "Argentina")
        XCTAssertEqual(m?.id, "argentina")
        XCTAssertEqual(ContentStore.shared.regionMatching("Uco Valley, Mendoza", country: "Argentina")?.id, "uco-valley")
        XCTAssertEqual(ContentStore.shared.regionMatching("Mendoza", country: "")?.id, "mendoza")
        XCTAssertEqual(ContentStore.shared.regionMatching("Kakheti", country: "Georgia")?.id, "kakheti")
    }

    /// The grey loading cards of a scan, and the Journal with its heat map.
    func testScanSkeleton() {
        snap("scan-loading") { ScrollView { ScanSkeleton().padding(20) } }
        snap("journal-heat", settle: 3.0) { ScrollView { JournalInsights().padding(20) } }
    }

    /// Atlas search, Georgia in the main atlas, and the France map with its commune lines.
    func testSearchAndGeorgia() {
        snap("atlas-search-pauillac", settle: 3.0) { NavigationStack { RegionListView(query: "pauillac") } }
        snap("atlas-search-geo", settle: 3.0) { NavigationStack { RegionListView(query: "georgia") } }
        snap("atlas-list", settle: 3.0) { NavigationStack { RegionListView() } }
        snap("georgia-explorer", settle: 4.0) { MapExplorer(mapID: "georgia") }
        snap("georgia-kakheti", settle: 4.0) { MapExplorer(mapID: "georgia", highlight: ["tsinandali"]) }
        snap("fr-lines-medoc", settle: 4.0) { MapExplorer(mapID: "france", highlight: ["haut-medoc"]) }
        snap("fr-lines-rhone", settle: 4.0) { MapExplorer(mapID: "france", highlight: ["chateauneuf-du-pape"]) }
        XCTAssertNotNil(ContentStore.shared.region("tsinandali"))
    }

    /// Search: the matching rules, and what the Atlas search finds.
    func testSearchRules() {
        var lines: [String] = []
        func check(_ ok: Bool, _ what: String) { lines.append((ok ? "OK    " : "FAIL  ") + what); XCTAssertTrue(ok, what) }
        check(Search.matches("cotes du rhone", "Côtes du Rhône"), "accents ignored")
        check(Search.matches("CHATEAUNEUF", "Châteauneuf-du-Pape"), "capitals and hyphens ignored")
        check(Search.matches("pa", "Châteauneuf-du-Pape"), "start of a later word")
        check(!Search.matches("zzz", "Pauillac"), "no false hit")
        for q in ["pauillac", "barolo", "mendoza", "kakheti", "tsinandali", "georgia", "napa", "rioja", "willamette", "cote de nuits", "burgundy", "chianti", "marlborough", "stellenbosch"] {
            let n = AtlasSearchResults.places(q).count
            check(n > 0, "place search '\(q)' → \(n) (first: \(AtlasSearchResults.places(q).first?.name ?? "-"))")
        }
        for q in ["cab", "riesling", "malbec", "pinot", "syrah", "chard"] {
            let n = AtlasSearchResults.grapes(q).count
            check(n > 0, "grape search '\(q)' → \(n)")
        }
        check(AtlasSearchResults.places("pauillac").first?.id == "pauillac", "Pauillac is the first hit for pauillac")
        for (a, k) in [("Dried rose", FlavorGlyph.Kind.rose), ("Tar", .tar), ("Licorice", .liquorice), ("Wet slate", .pebbles), ("Pencil shavings", .pencil)] {
            check(FlavorGlyph.kind(for: a, category: nil) == k, "icon for \(a)")
        }
        check(FlavorGlyph.kind(for: "Totally unknown thing", category: nil) == .drop, "unknown aroma gets the drop, not an empty circle")
        snap("search-report") { ScrollView { Text(lines.joined(separator: "\n")).font(.system(size: 11, design: .monospaced)).padding(16).frame(maxWidth: .infinity, alignment: .leading) } }
    }

    /// The wine pages in the Journal: the glance tiles and the region map.
    func testWineGlance() {
        testSearchRules()
        var w = WineIdentity.empty
        w.name = "Barolo Pira"; w.producer = "Roagna"; w.region = "Barolo, Piedmont"; w.country = "Italy"; w.vintage = "2012"
        w.grapes = ["Nebbiolo"]; w.funFact = "Pira is a historic vineyard in Castiglione Falletto."; w.drinkWindow = "2024–2040"
        w.tastingNotes = ["Dried rose", "Tar", "Red cherry", "Licorice", "Dried herbs"]
        let price = PriceInfo(average: 215, low: 215, high: 215, currency: "USD", source: "Cheapest of 2 shops · 3 L bottle, per 750 ml", url: "https://example.com")
        snap("wine-glance", settle: 3.0) { ScrollView { VStack(spacing: 14) { WineGlance(wine: w, price: price, points: 94, pointsAreGuess: true); WineInfoCard(wine: w) }.padding(20) } }
    }

    /// Round check: Oregon in the atlas, the heat map blobs, the wine page and the Great wines search.
    func testRound() {
        testWineGlance()
        testScanSkeleton()
        XCTAssertNotNil(ContentStore.shared.region("willamette-valley"))
        for (id, hl) in [("oregon", Set<String>()), ("oregon", Set(["dundee-hills"])), ("oregon", Set(["red-mountain"]))] {
            snap("oregon-\(hl.first ?? "all")", settle: 4.0) { MapExplorer(mapID: id, highlight: hl) }
        }
        snap("oregon-page", settle: 3.0) { NavigationStack { RegionDetailView(region: ContentStore.shared.region("willamette-valley")!) } }
        snap("atlas-search-oregon", settle: 3.0) { NavigationStack { RegionListView(query: "oregon") } }
        snap("great-wines", settle: 3.0) { NavigationStack { GreatWinesScreen() } }
    }

    /// Every big atlas map in its explorer, to review them one by one.
    func testMapsTidy() {
        for id in ["france", "italy", "spain", "portugal", "germany", "california", "oregon", "australia", "new-zealand", "south-africa", "chile", "argentina"] {
            snap("tidy-\(id)", settle: 4.0) { MapExplorer(mapID: id) }
        }
    }

    /// Spain and neighbours after the official-boundary pass, and the Old World / New World lists.
    func testSpainPass() {
        snap("atlas-list2", settle: 3.0) { NavigationStack { RegionListView() } }
        snap("spain-all", settle: 4.0) { MapExplorer(mapID: "spain") }
        for id in ["ribeira-sacra", "getariako-txakolina", "malaga-do", "tarragona", "rioja"] {
            snap("spain-\(id)", settle: 4.0) { MapExplorer(mapID: "spain", highlight: [id]) }
        }
        snap("portugal-all", settle: 4.0) { MapExplorer(mapID: "portugal") }
        snap("hungary-all", settle: 4.0) { MapExplorer(mapID: "hungary") }
    }

    /// Heat map, Oregon centering, profile spacing, region page without the big map button.
    func testRound3() {
        snap("heat3", settle: 3.0) { ScrollView { JournalInsights().padding(20) } }
        snap("oregon3", settle: 4.0) { MapExplorer(mapID: "oregon") }
        snap("profile3", settle: 3.0) { ProfileView() }
        if let r = ContentStore.shared.region("spain") { snap("spain-page3", settle: 3.0) { NavigationStack { RegionDetailView(region: r) } } }
    }

    /// The cellar page, the journal with its new cards, the scan history.
    func testCellarPass() {
        let j = JournalStore.sample
        snap("cellar4", settle: 3.0) { NavigationStack { CellarView() }.environment(j) }
        snap("journal4", settle: 3.0) { JournalHome().environment(j) }
        snap("history4", settle: 3.0) { NavigationStack { ScanHistoryView() }.environment(j) }
        snap("heat4", settle: 3.0) { ScrollView { JournalInsights().padding(20) }.environment(j) }
    }

    /// The real RootView with the Duo's status column (camera, clock, battery) as a right-hand safe-area inset: the tabs must
    /// stand inside that column, under the camera, and the page gets the rest. Also without the column (the tabs keep their own).
    func testRailColumn() {
        let progress = GameProgress()
        progress.data.onboarded = true
        let journal = JournalStore.sample
        let cases: [(String, CGSize, CGFloat)] = [
            ("col-outside", CGSize(width: 466, height: 678), 66), ("col-landscape", CGSize(width: 951, height: 669), 66),
            ("col-none-outside", CGSize(width: 466, height: 678), 0), ("col-none-portrait", CGSize(width: 669, height: 951), 0),
        ]
        for (name, size, inset) in cases {
            let host = UIHostingController(rootView: AnyView(RootView().environment(progress).environment(journal).background(Palette.paper)))
            host.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: inset)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            spin(3.0)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            if let png = img.pngData() { try? png.write(to: outDir.appendingPathComponent("\(name).png")) }
            window.isHidden = true
        }
    }
}

/// A hosting controller with no safe area of its own, plus a column on the right of the given width.
final class ColumnController<C: View>: UIHostingController<C> {
    var column: CGFloat = 0
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let a = additionalSafeAreaInsets, s = view.safeAreaInsets
        let want = UIEdgeInsets(top: -(s.top - a.top), left: -(s.left - a.left), bottom: -(s.bottom - a.bottom), right: -(s.right - a.right) + column)
        if a != want { additionalSafeAreaInsets = want }
    }
}
