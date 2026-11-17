import SwiftUI
#if DEBUG

/// Simulator-only helpers: `-screen <name>` opens a given screen so CI can take screenshots.
enum DebugScreens {
    static let screen: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var autoAnswerWrong = false
    static var autoFinish = false

    static var initialTab: Int? {
        switch screen {
        case "learn", "lesson", "feedback", "blank", "match", "complete": return 0
        case "practice": return 1
        case "library", "grapes", "grape", "regions", "region", "map", "aromas", "colors", "styles", "tasting", "cards", "boldness", "labels", "explorer", "guide", "tuscany", "icons", "lebanon", "portugal": return 2
        case "journal", "profile": return 3
        default: return nil
        }
    }

    static func prepare(_ progress: GameProgress) {
        guard let screen else { return }
        var d = progress.data
        if screen == "onboarding" {
            d = ProgressData()
            progress.data = d
            return
        }
        d.onboarded = true
        d.xp = 640
        d.streak = 12
        d.bestStreak = 21
        d.lastActiveDay = GameProgress.day()
        d.answered = 180
        d.correct = 152
        d.dailyGoal = 30
        let cal = Calendar.current
        for (i, xp) in [22, 35, 30, 14, 40, 31, 18].enumerated() {
            if let day = cal.date(byAdding: .day, value: -i, to: Date()) { d.dailyXP[GameProgress.day(day)] = xp }
        }
        let lessons = ContentStore.shared.orderedLessons
        for l in lessons.prefix(5) { d.lessons[l.id] = LessonRecord(completions: 1, bestAccuracy: 0.9, perfect: l.id.hasSuffix("a"), lastDate: GameProgress.day()) }
        d.mistakes = Array(lessons.dropFirst(2).first?.cards.filter(\.isQuestion).map(\.id).prefix(3) ?? [])
        d.achievements = ["first-sip", "streak-3", "streak-7", "perfect", "xp-500"]
        progress.data = d
        autoAnswerWrong = screen == "feedback"
        autoFinish = screen == "complete"
    }

    static func learnHook(start: @escaping (Lesson) -> Void) {
        guard let screen, ["lesson", "feedback", "blank", "match", "complete"].contains(screen) else { return }
        let lessons = ContentStore.shared.orderedLessons
        func first(where test: (Card) -> Bool) -> Lesson? {
            for l in lessons {
                if let i = l.cards.firstIndex(where: test) {
                    return Lesson(id: l.id, title: l.title, icon: l.icon, cards: Array(l.cards[i...]))
                }
            }
            return nil
        }
        let lesson: Lesson?
        switch screen {
        case "feedback": lesson = first { $0.kind == .choice && $0.visual == nil }
        case "blank": lesson = first { $0.kind == .blank }
        case "match": lesson = first { $0.kind == .match }
        default: lesson = first { $0.kind == .learn && $0.visual != nil }
        }
        if let lesson {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(lesson) }
        }
    }

    static func practiceHook(_ open: @escaping (Session) -> Void) {}

    static func libraryHook(_ push: @escaping (any Hashable) -> Void) {
        guard let screen else { return }
        let c = ContentStore.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            switch screen {
            case "grapes": push(LibrarySection.grapes)
            case "grape": if let g = c.grape("pinot-noir") ?? c.library.grapes.first { push(g) }
            case "regions": push(LibrarySection.regions)
            case "region": if let r = c.region("bordeaux") ?? c.library.regions.first { push(r) }
            case "map": if let r = c.region("france") ?? c.library.regions.first { push(r) }
            case "explorer": if let r = c.region("bordeaux") { push(r) }
            case "aromas": push(LibrarySection.aromas)
            case "colors": push(LibrarySection.colors)
            case "styles": push(LibrarySection.styles)
            case "tasting": push(LibrarySection.tasting)
            case "cards": push(LibrarySection.cards)
            case "boldness": push(LibrarySection.boldness)
            case "labels": push(LibrarySection.labels)
            case "guide": push(LibrarySection.guide)
            case "tuscany": if let r = c.region("tuscany") { push(r) }
            case "lebanon": if let r = c.region("lebanon") { push(r) }
            case "portugal": if let r = c.region("portugal") { push(r) }
            case "icons": push("icons")
            default: break
            }
        }
    }
}

/// Every flavor icon on one sheet (for reviewing the icon set in CI screenshots).
struct DebugIconSheet: View {
    var body: some View {
        let items = ContentStore.shared.allAromaCategories().flatMap { c in c.items }
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 8) {
                ForEach(items, id: \.self) { a in
                    VStack(spacing: 3) {
                        FlavorIcon(aroma: a, size: 34)
                        Text(a).font(.system(size: 8)).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
            .padding(10)
        }
        .background(Palette.paper)
    }
}
#endif

extension View {
    @ViewBuilder func debugDestinations() -> some View {
        #if DEBUG
        self.navigationDestination(for: String.self) { _ in DebugIconSheet() }
        #else
        self
        #endif
    }
}
