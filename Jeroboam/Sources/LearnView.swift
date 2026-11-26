import SwiftUI

struct LearnView: View {
    @Environment(GameProgress.self) private var progress
    @State private var levelNumber: Int = 1
    @State private var session: Session? = nil
    @State private var guidebook: Unit? = nil
    @State private var askUnlock: Level? = nil
    @State private var collapse: CGFloat = 0
    @Environment(\.hasRail) private var hasRail
    private let content = ContentStore.shared
    #if DEBUG
    static var snapshotStart: Int? = nil
    #endif

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let level = currentLevel {
                            levelIntro(level)
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, hasRail ? 10 : 18)
                                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("learnScroll")).minY } action: { y in
                                    // 0 at rest, 1 once the level title has scrolled under the header
                                    let p = min(1, max(0, (18 - y) / 70))
                                    if abs(p - collapse) > 0.01 { collapse = p; HeaderState.shared.collapsed["Learn"] = p > 0.5 }
                                }
                            if plusLocked(level.number) {
                                PlusLevelBanner(level: level)
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 16)
                            }
                            if let next = progress.currentLesson(in: level), progress.isLevelUnlocked(level.number) {
                                continueCard(next, level: level)
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 22)
                            }
                            ForEach(Array(level.courseUnits.enumerated()), id: \.element.id) { i, unit in
                                UnitSection(unit: unit, number: i + 1, level: level,
                                            onStart: { start($0) }, onGuide: { openGuide(unit, level) }, onLocked: { locked(level) })
                                    .id(unit.id)
                                    .padding(.top, 34)
                            }
                            if !level.studyUnits.isEmpty {
                                StudyGuideHeader(level: level)
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 44)
                            }
                            ForEach(Array(level.studyUnits.enumerated()), id: \.element.id) { i, unit in
                                UnitSection(unit: unit, number: i + 1, level: level,
                                            onStart: { start($0) }, onGuide: { openGuide(unit, level) }, onLocked: { locked(level) })
                                    .id(unit.id)
                                    .padding(.top, 30)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { fixedHeader }
                .coordinateSpace(name: "learnScroll")
                .scrollIndicators(.hidden)
                .background(Palette.paper.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .background(NavCapture(tab: 0))
                .onChange(of: levelNumber) { _, _ in proxy.scrollTo("top", anchor: .top) }
                // Tapping Learn again: back to the top of the level you are working on.
                .onReceive(NotificationCenter.default.publisher(for: .learnTabReselected)) { _ in
                    let unlocked = content.course.levels.filter { progress.isLevelUnlocked($0.number) }
                    let target = unlocked.first { progress.levelProgress($0) < 1 } ?? unlocked.last
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let t = target, t.number != levelNumber { levelNumber = t.number }
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
        .sessionPane($session, guide: $guidebook, idle: {
            let next = currentLevel.flatMap { l in progress.isLevelUnlocked(l.number) ? progress.currentLesson(in: l) : nil }
            if let n = next { return AnyView(LessonPreviewPane(lesson: n, level: levelNumber) { start(n) }) }
            return AnyView(PaneIdle(eyebrow: "Level \(levelNumber)", title: "Pick a lesson",
                                    text: "Choose a lesson on the left and it opens here."))
        })
        .guidebookSheet($guidebook)
        #if DEBUG
        .onAppear {
            // snapshot tests: open the first lesson (skipping some cards) as if it had been tapped
            if let s = LearnView.snapshotStart, session == nil, let l = content.orderedLessons.first {
                session = Session(title: l.title, lessonID: l.id, cards: Array(l.cards.dropFirst(s)), accent: Palette.level(1))
            }
        }
        #endif
        .alert("Jump ahead?", isPresented: Binding(get: { askUnlock != nil }, set: { if !$0 { askUnlock = nil } })) {
            Button("Unlock Level \(askUnlock?.number ?? 2)") {
                if let l = askUnlock { progress.unlockLevel(l.number) }
                askUnlock = nil
            }
            Button("Not now", role: .cancel) { askUnlock = nil }
        } message: {
            Text("Levels unlock as you finish the one before. If you already know the basics, you can start here.")
        }
        .onAppear {
            if levelNumber == 1, progress.data.startLevel > 1 { levelNumber = progress.data.startLevel }
            #if DEBUG
            DebugScreens.learnHook(start: { start($0) })
            if DebugScreens.screen == "freelearn" || DebugScreens.screen == "history" { levelNumber = DebugScreens.screen == "freelearn" ? 2 : 3 }
            #endif
        }
    }

    private var currentLevel: Level? { content.course.levels.first { $0.number == levelNumber } }

    /// Every level except your starting one (lessons and guidebooks) is part of Jero Plus.
    private func plusLocked(_ n: Int) -> Bool { n != progress.data.startLevel && Plus.shared.locked }

    private func openGuide(_ unit: Unit, _ level: Level) {
        if plusLocked(level.number) { PaywallPresenter.shared.show("Level \(level.number) guidebooks come with Jero Plus.") }
        else { guidebook = unit }
    }

    private func locked(_ level: Level) {
        if plusLocked(level.number) { PaywallPresenter.shared.show("Level \(level.number) · \(level.title) comes with Jero Plus.") }
        else { askUnlock = level }
    }

    private func start(_ lesson: Lesson) {
        let level = content.level(ofLesson: lesson.id)
        if let n = level?.number, plusLocked(n) {
            PaywallPresenter.shared.show("Level \(n) · \(level?.title ?? "") comes with Jero Plus.")
            return
        }
        session = Session(title: lesson.title, lessonID: lesson.id, cards: lesson.cards, accent: Palette.level(level?.number ?? 1))
    }

    /// Fixed-height header: the streak row cross-fades into the current level's name as you scroll;
    /// the level tabs stay put. Nothing changes height, so the content never jumps.
    private var fixedHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                TopStatusBar()
                    .opacity(1 - collapse)
                    .offset(y: -8 * collapse)
                    .allowsHitTesting(collapse < 0.5)
                if let level = currentLevel {
                    let lessons = level.courseUnits.flatMap(\.lessons)
                    let done = lessons.filter { progress.isCompleted($0.id) }.count
                    HStack(spacing: 10) {
                        Text(level.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(done)/\(lessons.count)").font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                        GoalRing(progress: progress.levelProgress(level), lineWidth: 2.5).frame(width: 18, height: 18)
                    }
                    .opacity(collapse)
                    .offset(y: 8 * (1 - collapse))
                    .allowsHitTesting(false)
                }
            }
            .frame(height: hasRail ? 38 : 44)
            .padding(.horizontal, Metrics.margin)
            levelTabs.padding(.top, 2)
        }
        .padding(.top, hasRail ? 0 : 4)
        .background(Palette.paper.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline().opacity(collapse) }
    }

    private var levelTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(content.course.levels) { l in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { levelNumber = l.number }
                    } label: {
                        VStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("Level").font(.system(size: 10.5, weight: .medium))
                                HStack(spacing: 3) {
                                    Text("\(l.number)").font(.system(size: 17, weight: .semibold))
                                    if plusLocked(l.number) {
                                        Image(systemName: "lock.fill").font(.system(size: 9))
                                    }
                                }
                            }
                            .foregroundStyle(levelNumber == l.number ? Palette.ink : Palette.inkFaint)
                            Rectangle().fill(levelNumber == l.number ? Palette.level(l.number) : Color.clear).frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.margin)
        }
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, Metrics.margin) }
    }

    private func levelIntro(_ level: Level) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(level.subtitle, color: Palette.level(level.number))
            Text(level.title).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink)
            let lessons = level.courseUnits.flatMap(\.lessons)
            let done = lessons.filter { progress.isCompleted($0.id) }.count
            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule().fill(Palette.level(level.number)).frame(width: geo.size.width * progress.levelProgress(level))
                    }
                }
                .frame(height: 4)
                Text("\(done)/\(lessons.count) lessons").font(.numeric(12, .medium)).foregroundStyle(Palette.inkSoft)
                    .fixedSize()
            }
            .padding(.top, 6)
        }
        .id("top")
    }

    private func continueCard(_ lesson: Lesson, level: Level) -> some View {
        let unit = content.unit(ofLesson: lesson.id)
        return Button { start(lesson) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(progress.completedCount == 0 ? "Start here" : "Up next", color: .white.opacity(0.75))
                    Text(lesson.title).font(.jero(size: 22, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.leading)
                    Text(unit?.title ?? "").font(.jero(size: 13)).foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 6) {
                        Text("Start lesson").font(.jero(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Palette.bordeaux)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
                SplashMark(color: .white, surface: Palette.wineSoft.opacity(0.9))
                    .frame(width: 58, height: 58)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background { HeroCardBackground() }
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status bar (streak, XP, goal)

struct TopStatusBar: View {
    @Environment(GameProgress.self) private var progress
    @State private var showProfile = false
    var body: some View {
        HStack(spacing: 10) {
            Wordmark(size: 22)
            Spacer()
            StreakXPPill()
            AvatarButton(size: 30)
        }
    }
}

/// The streak flame and the XP spark in one small capsule: in the Learn tab's bar, and kept in the slim top bar of Practice,
/// Atlas and Journal once their big title has scrolled away.
struct StreakXPPill: View {
    @Environment(GameProgress.self) private var progress
    var body: some View {
        HStack(spacing: 14) {
            FlameBadge(count: progress.data.streak, active: progress.activeToday)
            XPBadge(xp: progress.data.xp)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Palette.card))
    }
}

// MARK: - Unit section with a lesson timeline

struct UnitSection: View {
    let unit: Unit
    let number: Int
    let level: Level
    let onStart: (Lesson) -> Void
    let onGuide: () -> Void
    let onLocked: () -> Void
    @Environment(GameProgress.self) private var progress

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.level(level.number).opacity(0.75))
                VStack(alignment: .leading, spacing: 5) {
                    Text(unit.title).font(.sectionTitle).foregroundStyle(Palette.ink)
                    Text(unit.summary).font(.jero(size: 14)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)

            Button(action: onGuide) {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages").font(.system(size: 12))
                    Text("Guidebook").font(.jero(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.level(level.number))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().strokeBorder(Palette.level(level.number).opacity(0.35), lineWidth: 1))
            }
            .padding(.leading, Metrics.margin + 48)
            .padding(.top, 12)

            VStack(spacing: 0) {
                ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { i, lesson in
                    LessonRow(lesson: lesson, level: level, isFirst: i == 0, isLast: i == unit.lessons.count - 1,
                              onStart: onStart, onLocked: onLocked)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, Metrics.margin)
        }
    }
}

struct LessonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let lesson: Lesson
    let level: Level
    let isFirst: Bool
    let isLast: Bool
    let onStart: (Lesson) -> Void
    let onLocked: () -> Void
    @Environment(GameProgress.self) private var progress
    @State private var pulse = false

    var body: some View {
        let done = progress.isCompleted(lesson.id)
        let unlocked = progress.isUnlocked(lesson, in: level)
        let current = unlocked && !done && progress.currentLesson(in: level)?.id == lesson.id
        let tint = Palette.level(level.number)
        let record = progress.data.lessons[lesson.id]
        Button {
            if unlocked { onStart(lesson) } else if !progress.isLevelUnlocked(level.number) { onLocked() }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle().fill(isFirst ? Color.clear : (done || current ? tint.opacity(0.45) : Palette.line)).frame(width: 1.5)
                        Rectangle().fill(isLast ? Color.clear : (done ? tint.opacity(0.45) : Palette.line)).frame(width: 1.5)
                    }
                    node(done: done, current: current, unlocked: unlocked, tint: tint, perfect: record?.perfect ?? false)
                }
                .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title)
                        .font(.system(size: 16.5, weight: current ? .semibold : .regular))
                        .foregroundStyle(unlocked ? Palette.ink : Palette.inkFaint)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text("\(lesson.questionCount) questions").font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                        if let r = record {
                            Text("·").foregroundStyle(Palette.inkFaint)
                            Text("Best \(Int((r.bestAccuracy * 100).rounded()))%").font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
                .padding(.vertical, 14)
                Spacer(minLength: 0)
                if current {
                    Text("Start").font(.jero(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(tint))
                } else if done {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 13)).foregroundStyle(Palette.inkFaint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func node(done: Bool, current: Bool, unlocked: Bool, tint: Color, perfect: Bool) -> some View {
        ZStack {
            if current {
                Circle().stroke(tint.opacity(0.25), lineWidth: 6).frame(width: 34, height: 34)
                    .scaleEffect(pulse ? 1.12 : 0.95)
                    .opacity(pulse ? 0.2 : 0.8)
                    .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } } }
            }
            Circle()
                .fill(done ? tint : Palette.paper)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(done ? tint : (current ? tint : Palette.line), lineWidth: current ? 2 : 1.5))
            if done {
                Image(systemName: perfect ? "star.fill" : "checkmark").font(.system(size: perfect ? 10 : 11, weight: .bold)).foregroundStyle(.white)
            } else if current {
                Circle().fill(tint).frame(width: 9, height: 9)
            } else if !unlocked {
                Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Palette.inkFaint)
            }
        }
    }
}

// MARK: - Guidebook

struct GuidebookView: View {
    let unit: Unit
    /// Topics are numbered continuously through the whole guidebook.
    private func topicNumber(_ lesson: Lesson, _ index: Int) -> Int {
        var n = 0
        for l in unit.lessons {
            if l.id == lesson.id { return n + index + 1 }
            n += l.cards.filter { $0.kind == .learn }.count
        }
        return index + 1
    }
    @Environment(\.dismiss) private var dismissEnv
    @Environment(\.coverClose) private var coverClose
    private func dismiss() { if let c = coverClose { c() } else { dismissEnv() } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Guidebook")
                        Text(unit.title).font(.serif(32)).foregroundStyle(Palette.ink)
                        Text(unit.summary).font(.jero(size: 16)).foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(unit.lessons) { lesson in
                        VStack(alignment: .leading, spacing: 26) {
                            Text(lesson.title.uppercased()).font(.jero(size: 12, weight: .semibold)).kerning(1.4).foregroundStyle(Palette.wine)
                            ForEach(Array(lesson.cards.filter { $0.kind == .learn }.enumerated()), id: \.element.id) { i, card in
                                LearnCard(card: card, topic: topicNumber(lesson, i))
                            }
                        }
                        Hairline()
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 20)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(Palette.wine) }
            }
        }
    }
}

/// Separates the course from the study guide: reference lessons that cover everything the exams ask.
struct StudyGuideHeader: View {
    let level: Level
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Palette.level(level.number).opacity(0.12))
                Image(systemName: "books.vertical").font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.level(level.number))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Study guide").font(.sectionTitle).foregroundStyle(Palette.ink)
                Text("Every grape, region and term the Level \(level.number) exam can ask about. Open in any order.")
                    .font(.system(size: 14)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
    }
}

extension Notification.Name {
    static let learnTabReselected = Notification.Name("jero.learnTabReselected")
    /// Pressing the tab you are on, on its first page: back to the top (object = the page title).
    static let tabScrollTop = Notification.Name("jero.tabScrollTop")
}

/// At the top of the locked levels for free users.
struct PlusLevelBanner: View {
    let level: Level
    var body: some View {
        Button { PaywallPresenter.shared.show("Level \(level.number) · \(level.title) comes with Jero Plus.") } label: {
            HStack(spacing: 14) {
                LockDot(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Level \(level.number)").font(.jero(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("Every lesson, guidebook and exam with Jero Plus · \(Plus.shared.price)/month")
                        .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(HeroCardBackground().clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)))
        }
        .buttonStyle(PressableStyle())
    }
}
