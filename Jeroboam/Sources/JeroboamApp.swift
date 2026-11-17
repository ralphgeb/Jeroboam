import SwiftUI

@main
struct JeroboamApp: App {
    @State private var progress = GameProgress()

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
                .preferredColorScheme(progress.colorScheme)
                .tint(Palette.wine)
                .onAppear {
                    QuizGenerator.lessonCompleted = { [progress] id in progress.isCompleted(id) }
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
                TabView(selection: $tab) {
                    LearnView()
                        .tabItem { Label("Learn", systemImage: "book.closed") }
                        .tag(0)
                    PracticeView()
                        .tabItem { Label("Practice", systemImage: "target") }
                        .tag(1)
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "books.vertical") }
                        .tag(2)
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
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
            if p == .active { progress.refreshStreakState() }
        }
        .onAppear {
            #if DEBUG
            if let t = DebugScreens.initialTab { tab = t }
            #endif
        }
    }
}
