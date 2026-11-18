import SwiftUI

struct LearnView: View {
    @Environment(GameProgress.self) private var progress
    @State private var levelNumber: Int = 1
    @State private var session: Session? = nil
    @State private var guidebook: Unit? = nil
    @State private var askUnlock: Level? = nil
    @State private var collapse: CGFloat = 0
    private let content = ContentStore.shared

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let level = currentLevel {
                            levelIntro(level)
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, 18)
                                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("learnScroll")).minY } action: { y in
                                    // 0 at rest, 1 once the level title has scrolled under the header
                                    let p = min(1, max(0, (18 - y) / 70))
                                    if abs(p - collapse) > 0.01 { collapse = p }
                                }
                            if let next = progress.currentLesson(in: level), progress.isLevelUnlocked(level.number) {
                                continueCard(next, level: level)
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 22)
                            }
                            ForEach(Array(level.units.enumerated()), id: \.element.id) { i, unit in
                                UnitSection(unit: unit, number: i + 1, level: level,
                                            onStart: { start($0) }, onGuide: { guidebook = unit }, onLocked: { askUnlock = level })
                                    .id(unit.id)
                                    .padding(.top, 34)
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
                .onChange(of: levelNumber) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
        }
        .fullScreenCover(item: $session) { s in
            LessonPlayer(session: s)
        }
        .sheet(item: $guidebook) { u in GuidebookView(unit: u) }
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
            #endif
        }
    }

    private var currentLevel: Level? { content.course.levels.first { $0.number == levelNumber } }

    private func start(_ lesson: Lesson) {
        let level = content.level(ofLesson: lesson.id)
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
                    let lessons = level.units.flatMap(\.lessons)
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
            .frame(height: 44)
            .padding(.horizontal, Metrics.margin)
            levelTabs.padding(.top, 2)
        }
        .padding(.top, 4)
        .background(Palette.paper.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline().opacity(collapse) }
    }

    private var levelTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 26) {
                ForEach(content.course.levels) { l in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { levelNumber = l.number }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Level \(l.number)").font(.system(size: 15, weight: .semibold))
                                if !progress.isLevelUnlocked(l.number) {
                                    Image(systemName: "lock.fill").font(.system(size: 10))
                                }
                            }
                            .foregroundStyle(levelNumber == l.number ? Palette.ink : Palette.inkFaint)
                            Rectangle().fill(levelNumber == l.number ? Palette.level(l.number) : Color.clear).frame(height: 2)
                        }
                        .fixedSize()
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
            let lessons = level.units.flatMap(\.lessons)
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
                    Text(lesson.title).font(.system(size: 22, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.leading)
                    Text(unit?.title ?? "").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 6) {
                        Text("Start lesson").font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 10)
                }
                Spacer(minLength: 0)
                GrapeMark(tones: [.white.opacity(0.9), .white.opacity(0.55), .white.opacity(0.75)])
                    .frame(width: 46, height: 60)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: Metrics.radius + 2, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.bordeaux, Palette.bordeaux.mix(with: .black, 0.25)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
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
            HStack(spacing: 14) {
                FlameBadge(count: progress.data.streak, active: progress.activeToday)
                XPBadge(xp: progress.data.xp)
                GoalRing(progress: Double(progress.todayXP) / Double(max(1, progress.data.dailyGoal)), lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                    .accessibilityLabel("Daily goal \(progress.todayXP) of \(progress.data.dailyGoal) XP")
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Palette.card))
            Button { showProfile = true } label: {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 26)).foregroundStyle(Palette.ink.opacity(0.85))
            }
            .accessibilityLabel("Profile and settings")
        }
        .sheet(isPresented: $showProfile) { ProfileView() }
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
                    Text(unit.summary).font(.system(size: 14)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)

            Button(action: onGuide) {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages").font(.system(size: 12))
                    Text("Guidebook").font(.system(size: 13, weight: .semibold))
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
                        Text("\(lesson.questionCount) questions").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                        if let r = record {
                            Text("·").foregroundStyle(Palette.inkFaint)
                            Text("Best \(Int((r.bestAccuracy * 100).rounded()))%").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
                .padding(.vertical, 14)
                Spacer(minLength: 0)
                if current {
                    Text("Start").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
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
                    .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } }
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
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Guidebook")
                        Text(unit.title).font(.serif(32)).foregroundStyle(Palette.ink)
                        Text(unit.summary).font(.system(size: 16)).foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(unit.lessons) { lesson in
                        VStack(alignment: .leading, spacing: 26) {
                            Text(lesson.title.uppercased()).font(.system(size: 12, weight: .semibold)).kerning(1.4).foregroundStyle(Palette.wine)
                            ForEach(lesson.cards.filter { $0.kind == .learn }) { card in
                                LearnCard(card: card)
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
