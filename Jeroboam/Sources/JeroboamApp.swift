import SwiftUI
import UserNotifications

@main
struct JeroboamApp: App {
    @State private var progress = GameProgress()
    @State private var journal = JournalStore()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        let p = GameProgress()
        #if DEBUG
        DebugScreens.prepare(p)
        #endif
        _progress = State(initialValue: p)
        // no white bar behind the page's own header (it showed as a white strip on the Duo)
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        // Stylish navigation bar titles in the serif face.
        let serif = UIFont.systemFont(ofSize: 17, weight: .semibold).fontDescriptor.withDesign(.serif)
        if let serif {
            UINavigationBar.appearance().titleTextAttributes = [.font: UIFont(descriptor: serif, size: 17)]
        }
        let large = UIFont.systemFont(ofSize: 34, weight: .regular).fontDescriptor.withDesign(.serif)
        if let large {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: large, size: 34)]
        }
    }

    var body: some Scene {
        WindowGroup {
            // the whole app sits inside the foldable-preview host, so the preview carries every setting
            DuoPreviewHost {
                AdaptiveRoot { RootView() }
                    .environment(progress)
                    .environment(journal)
                    .preferredColorScheme(progress.colorScheme)
                    .tint(Palette.wine)
                    .plusSheetHost()
            }
            .environment(progress)
            .environment(journal)
            .preferredColorScheme(progress.colorScheme)
            // preferredColorScheme(nil) does not undo an earlier override and misses open sheets,
            // so the choice is also set on every window.
            .onChange(of: progress.data.appearance, initial: true) { _, v in
                let style: UIUserInterfaceStyle = v == 1 ? .light : (v == 2 ? .dark : .unspecified)
                for scene in UIApplication.shared.connectedScenes {
                    (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
                }
            }
            .tint(Palette.wine)
            .task { await Plus.shared.refresh() }
            .task { await Plus.shared.listen() }
            .task { await Currency.refresh() }
            .task { await PriceUpdater.refresh() }
            .task { await journal.repriceShopBottlesOnce() }
            .task { await PriceCloud.seedOnce() }
            .onAppear {
                QuizGenerator.lessonCompleted = { [progress] id in progress.isCompleted(id) }
                Achievement.journal = journal
                CloudSync.shared.start(progress, journal)
            }
        }
    }
}

struct RootView: View {
    @Environment(GameProgress.self) private var progress
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0

    private var tabBinding: Binding<Int> {
        Binding(get: { tab }, set: { new in
            if new == tab && new == 0 { NotificationCenter.default.post(name: .learnTabReselected, object: nil) }
            // a full-screen map or the offer is closed by pressing a tab
            CoverHost.shared.content = nil; CoverHost.shared.owner = nil
            if CoverHost.shared.paywall != nil { CoverHost.shared.paywall = nil; PaywallPresenter.shared.target = nil }
            tab = new
        })
    }

    private var tabs: some View {
        TabView(selection: tabBinding) {
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.closed") }
                .tag(0)
            PracticeView()
                .tabItem { Label("Practice", systemImage: "target") }
                .tag(1)
            LibraryView()
                .tabItem { Label("Atlas", systemImage: "globe.europe.africa") }
                .tag(2)
            JournalView()
                .tabItem { Label("Journal", systemImage: "camera.aperture") }
                .tag(3)
        }
    }

    /// Rail layout: one page at a time (no system tab bar, which would draw a second set of tabs); pages that were
    /// opened stay alive underneath so they keep their place.
    @State private var visited: Set<Int> = [0]
    @State private var covers = CoverHost.shared
    @State private var deepWine: GreatWine? = nil
    private var railPages: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                if visited.contains(i) || tab == i {
                    Group {
                        switch i {
                        case 0: LearnView()
                        case 1: PracticeView()
                        case 2: LibraryView()
                        default: JournalView()
                        }
                    }
                    .opacity(tab == i ? 1 : 0)
                    .allowsHitTesting(tab == i)
                    .accessibilityHidden(tab != i)
                    .zIndex(tab == i ? 1 : 0)
                }
            }
        }
        .onChange(of: tab, initial: true) { _, t in visited.insert(t) }
        // real padding: a NavigationStack ignores extra safe area, so this keeps every page the same distance from the top
        .padding(.top, 30)
    }

    @State private var stableSize: CGSize = .zero
    private func railDecision(_ live: CGSize) -> Bool {
        let s = stableSize == .zero ? live : stableSize
        return s.height / max(s.width, 1) < 1.7 || s.width >= 640
    }

    var body: some View {
        Group {
            if progress.data.onboarded {
                GeometryReader { g in
                    // the Duo's screens are nearly as wide as they are tall: the tabs stand up in a column on the right.
                    // Decided from the window size measured WITHOUT the keyboard: the keyboard shrinks this reader, which used to
                    // flip the layout and rebuild every page (search fields lost the page the moment they were tapped).
                    let rail = railDecision(g.size)
                    if rail {
                        // Where iOS keeps a column for itself on the right (the Duo's camera, clock and battery), the tabs stand inside that
                        // column under the camera, as in Scout: nothing extra is reserved for them. Without such a column (the opened Duo
                        // upright, or any plain window) the page leaves its own slim column for them.
                        let inset = g.safeAreaInsets.trailing
                        let inColumn = inset > 40
                        let reserve: CGFloat = inColumn ? 0 : AdaptiveLayout.railWidth
                        HStack(spacing: 0) {
                            railPages
                                .environment(\.windowWidth, g.size.width - reserve)
                                .frame(maxWidth: .infinity)
                                // covers (the full map) fill the page area in front of the page, the tab column stays
                                .overlay {
                                    if let c = covers.content {
                                        c.background(Palette.paper.ignoresSafeArea()).ignoresSafeArea()
                                            .environment(\.windowWidth, g.size.width - reserve)
                                            .transition(.move(edge: .bottom))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.25), value: covers.content == nil)
                                .overlay { if let pw = covers.paywall { pw.environment(\.windowWidth, g.size.width - reserve).transition(.opacity) } }
                                .onAppear { covers.railActive = true; covers.pageWidth = g.size.width - reserve }
                                .onDisappear { covers.railActive = false }
                                .onChange(of: g.size.width) { _, w in covers.pageWidth = w - reserve }
                            if !inColumn { Color.clear.frame(width: AdaptiveLayout.railWidth) }
                        }
                        .environment(\.hasRail, true)
                        .environment(\.coverHost, covers)
                        .overlay(alignment: .bottomTrailing) {
                            DuoRail(selection: tabBinding, column: inColumn ? inset : AdaptiveLayout.railWidth)
                                .frame(width: inColumn ? inset : AdaptiveLayout.railWidth)
                                .offset(x: inColumn ? inset : 0)
                        }
                        // one profile button, always in the same place: the top right of the left half (the Duo's camera and
                        // battery sit in the right-hand strip, so it stays out of there)
                        .overlay(alignment: .topLeading) {
                            // only on the first two tabs, and not once the big title has scrolled up into the small bar
                            if covers.content == nil, tab <= 1, HeaderState.shared.collapsed[tab == 0 ? "Learn" : "Practice"] != true {
                            let page = g.size.width - reserve
                            let edge = page >= AdaptiveLayout.twoPaneThreshold ? page / 2 : page
                            AvatarButton(size: 32, ignoreRail: true)
                                .padding(.top, 32)
                                .offset(x: edge - Metrics.margin - 32)
                            }
                        }
                        .background(Palette.paper.ignoresSafeArea())
                    } else {
                        tabs
                    }
                }
                .background(
                    GeometryReader { m in Color.clear.onAppear { stableSize = m.size }.onChange(of: m.size) { _, n in stableSize = n } }
                        .ignoresSafeArea()
                        .ignoresSafeArea(.keyboard)
                )
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: progress.data.onboarded)
        // widget taps: the fun fact opens Learn, a wine opens its page
        .onOpenURL { url in
            guard url.scheme == "jero" else { return }
            if url.host == "wine", let id = url.pathComponents.dropFirst().first,
               let w = ContentStore.shared.library.great?.first(where: { $0.id == id }) {
                tab = 2
                GreatWinePlaylist.wines = [w]
                deepWine = w
            } else {
                tab = 0
            }
        }
        .sheet(item: $deepWine) { w in
            NavigationStack { GreatWinePager(wine: w) }
                .environment(progress)
                .plusSheetHost()
        }
        .onChange(of: phase) { _, p in
            if p == .active { progress.refreshStreakState(); progress.scheduleReminder() }
            if p == .background || p == .inactive { CloudSync.shared.pushAll() }
        }
        .onAppear {
            #if DEBUG
            if let t = DebugScreens.initialTab { tab = t }
            // screenshots of the foldable / wide layouts: -orient portrait|landscape turns the screen
            let args = CommandLine.arguments
            let want: UIInterfaceOrientationMask? = args.contains("-landscape") ? .landscapeRight
                : (args.firstIndex(of: "-orient").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
                    .map { $0 == "landscape" ? UIInterfaceOrientationMask.landscapeRight : .portrait })
            if let want {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                        scene.requestGeometryUpdate(.iOS(interfaceOrientations: want)) { _ in }
                    }
                }
            }
            if DebugScreens.screen == "paywall" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { PaywallPresenter.shared.show("Every level, the whole atlas and your journal.") }
            }
            #endif
        }
    }
}

/// The four tabs standing up in a slim column on the right (the iPhone Duo), in reach of the thumb.
struct DuoRail: View {
    @Binding var selection: Int
    /// The width of the column the rail stands in (78 normally; the Duo's status column when the tabs sit under the camera).
    var column: CGFloat = AdaptiveLayout.railWidth
    private var w: CGFloat { min(62, max(48, column - 14)) }
    private let items: [(String, String, String)] = [
        ("Learn", "book", "book.fill"), ("Practice", "target", "target"),
        ("Atlas", "globe.europe.africa", "globe.europe.africa.fill"), ("Journal", "camera.aperture", "camera.aperture"),
    ]
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                let on = selection == i
                Button { selection = i } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on ? item.2 : item.1)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: w * 0.74, height: w * 0.74)
                            .background(on ? Palette.wine : .clear, in: Circle())
                            .foregroundStyle(on ? Palette.onWine : Palette.ink)
                        Text(item.0).font(.system(size: 10, weight: .semibold)).foregroundStyle(on ? Palette.wine : Palette.inkSoft)
                    }
                    .frame(width: w, height: 70)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.0)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
        .background(Palette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
        .padding(.horizontal, 7)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(.snappy(duration: 0.25), value: selection)
    }
}
