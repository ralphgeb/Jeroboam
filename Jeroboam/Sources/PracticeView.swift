import SwiftUI

struct PracticeView: View {
    @Environment(GameProgress.self) private var progress
    @State private var session: Session? = nil

    var body: some View {
        NavigationStack {
            CollapsingPage(eyebrow: "Keep it fresh", title: "Practice",
                           subtitle: "Short quizzes from everything you have learned, and mock exams for each level.", showStatus: true) {
                dailyHero
                if !progress.data.mistakes.isEmpty {
                    GroupCard {
                        Button { session = QuizGenerator.mistakes(progress.data.mistakes) } label: {
                            IconRow(title: "Review mistakes", detail: "\(progress.data.mistakes.count) questions to revisit", last: true) {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 15)).foregroundStyle(Palette.wrong)
                            }
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
                exams
                topics
                Color.clear.frame(height: 24)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sessionPane($session, idle: {
            AnyView(PaneIdle(eyebrow: "Practice", title: "Today's 10 questions",
                             text: "Pick the daily mix, a mock exam or a topic on the left. The questions open here.",
                             button: "Start daily mix", action: { start(.mixed) }))
        })
        .onAppear {
            #if DEBUG
            DebugScreens.practiceHook { session = $0 }
            #endif
        }
    }

    // MARK: daily mix

    private var dailyHero: some View {
        let goal = Double(progress.todayXP) / Double(max(1, progress.data.dailyGoal))
        return Button { start(.mixed) } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Daily mix", color: .white.opacity(0.75))
                    Text(progress.goalReached ? "Goal reached, keep going" : "Today’s 10 questions")
                        .font(.system(size: 21, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.leading)
                    Text("\(progress.todayXP) of \(progress.data.dailyGoal) XP today · about 3 min")
                        .font(.system(size: 13).monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle").font(.system(size: 12, weight: .semibold))
                        Text("Start daily mix").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Palette.bordeaux)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 6)
                    Circle().trim(from: 0, to: min(1, goal)).stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill").font(.system(size: 15)).foregroundStyle(.white)
                        Text("\(progress.data.streak)").font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                    }
                }
                .frame(width: 68, height: 68)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroCardBackground() }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: mock exams

    private var exams: some View {
        let unlocked = max(progress.data.startLevel, progress.data.unlockedLevels.max() ?? 1)
        let info: [(String, String, String, CGFloat)] = [
            ("Foundations", "Bottle", "Tasting, the great grapes, the classic regions", 0.62),
            ("Intermediate", "Magnum", "Vineyard, winery, sparkling, labels, more grapes", 0.8),
            ("Advanced", "Jeroboam", "Every appellation, viticulture and winemaking", 1.0),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Mock exams")
            VStack(spacing: 0) {
                ForEach(1...3, id: \.self) { lv in
                    let open = lv <= unlocked
                    let i = info[lv - 1]
                    Button { if open { session = QuizGenerator.exam(level: lv) } } label: {
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(open ? Palette.wineSoft.opacity(0.75) : Palette.cardAlt)
                                BottleShape().fill(open ? Palette.bordeaux : Palette.inkFaint.opacity(0.5))
                                    .frame(width: 17 * i.3, height: 50 * i.3)
                                    .padding(.bottom, 9)
                            }
                            .frame(width: 52, height: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Level \(lv) · \(i.1)").font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(open ? Palette.wine : Palette.inkFaint)
                                Text(i.0).font(.system(size: 17, weight: .semibold)).foregroundStyle(open ? Palette.ink : Palette.inkFaint)
                                Text(open ? i.2 : "Finish Level \(lv - 1) to unlock").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 6)
                            VStack(spacing: 2) {
                                if open {
                                    Text("30").font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                                    Text("questions").font(.system(size: 10.5)).foregroundStyle(Palette.inkSoft)
                                } else {
                                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Palette.inkFaint)
                                }
                            }
                            .frame(width: 56)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(!open)
                    if lv < 3 { Hairline().padding(.leading, 80) }
                }
            }
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        }
    }

    // MARK: topics

    private var topics: some View {
        let kinds = QuizGenerator.Kind.allCases.filter { $0 != .mixed && $0 != .maps }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "By topic")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(kinds) { k in
                    Button { start(k) } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Palette.wineSoft.opacity(0.7))
                                art(k).scaleEffect(0.82)
                            }
                            .frame(width: 42, height: 42)
                            Text(k.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Palette.ink)
                                .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .cardStyle(padding: 11)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    @ViewBuilder private func art(_ k: QuizGenerator.Kind) -> some View {
        switch k {
        case .grapes: GrapeArt(id: "cabernet-sauvignon", size: 42)
        case .regions, .maps:
            Image(systemName: "globe.europe.africa").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.wine)
        case .colors:
            HStack(spacing: 2) {
                ForEach(["#E6D68C", "#E9A6A2", "#7A1832"], id: \.self) { Rectangle().fill(Color(hex: $0)).frame(width: 8, height: 22) }
            }
        case .aromas: AromaWheelMini().frame(width: 40, height: 40)
        default: WineGlass(color: Color(hex: "#8E1E3F"), fill: 0.45).frame(width: 20, height: 34)
        }
    }

    private func start(_ k: QuizGenerator.Kind) {
        let maxLevel = max(progress.data.startLevel, progress.data.unlockedLevels.max() ?? 1)
        session = QuizGenerator.session(k, maxLevel: maxLevel)
    }
}
