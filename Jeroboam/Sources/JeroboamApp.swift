import SwiftUI

@main
struct JeroboamApp: App {
    @State private var progress = GameProgress()
    @State private var journal = JournalStore()

    init() {
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
            RootView()
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
                .plusSheetHost()
                .task { await Plus.shared.refresh() }
                .task { await Plus.shared.listen() }
                .onAppear {
                    QuizGenerator.lessonCompleted = { [progress] id in progress.isCompleted(id) }
                    CloudSync.shared.start(progress)
                }
        }
    }
}

struct RootView: View {
    @Environment(GameProgress.self) private var progress
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0

    var body: some View {
        Group {
            if progress.data.onboarded {
                TabView(selection: Binding(get: { tab }, set: { new in
                    if new == tab && new == 0 { NotificationCenter.default.post(name: .learnTabReselected, object: nil) }
                    tab = new
                })) {
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
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: progress.data.onboarded)
        .onChange(of: phase) { _, p in
            if p == .active { progress.refreshStreakState(); progress.scheduleReminder() }
        }
        .onAppear {
            #if DEBUG
            if let t = DebugScreens.initialTab { tab = t }
            if DebugScreens.screen == "paywall" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { PaywallPresenter.shared.show("Levels 2 and 3, the whole atlas and your journal.") }
            }
            #endif
        }
    }
}
