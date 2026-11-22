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
        snap("map-explorer", settle: 3.0) { MapExplorer(mapID: "bordeaux") }
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
}
