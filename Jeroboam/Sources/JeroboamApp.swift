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
            .onAppear {
                QuizGenerator.lessonCompleted = { [progress] id in progress.isCompleted(id) }
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
        .safeAreaPadding(.top, 16)
    }

    var body: some View {
        Group {
            if progress.data.onboarded {
                GeometryReader { g in
                    // the Duo's screens are nearly as wide as they are tall: the tabs stand up in a column on the right
                    let rail = g.size.height / max(g.size.width, 1) < 1.7 || g.size.width >= 640
                    if rail {
                        HStack(spacing: 0) {
                            railPages
                                .environment(\.windowWidth, g.size.width - AdaptiveLayout.railWidth)
                                .frame(maxWidth: .infinity)
                            Color.clear.frame(width: AdaptiveLayout.railWidth)
                        }
                        .environment(\.hasRail, true)
                        .overlay(alignment: .bottomTrailing) {
                            DuoRail(selection: tabBinding).frame(width: AdaptiveLayout.railWidth)
                        }
                        // one profile button, always in the same place: the top of the tab column
                        .overlay(alignment: .topTrailing) {
                            AvatarButton(size: 36, ignoreRail: true)
                                .frame(width: AdaptiveLayout.railWidth)
                                .padding(.top, 14)
                        }
                        .background(Palette.paper.ignoresSafeArea())
                    } else {
                        tabs
                    }
                }
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: progress.data.onboarded)
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
                            .frame(width: 46, height: 46)
                            .background(on ? Palette.wine : .clear, in: Circle())
                            .foregroundStyle(on ? Palette.onWine : Palette.ink)
                        Text(item.0).font(.system(size: 10, weight: .semibold)).foregroundStyle(on ? Palette.wine : Palette.inkSoft)
                    }
                    .frame(width: 62, height: 70)
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
