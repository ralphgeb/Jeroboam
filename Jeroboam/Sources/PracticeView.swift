import SwiftUI

struct PracticeView: View {
    @Environment(GameProgress.self) private var progress
    @State private var session: Session? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TopStatusBar().padding(.top, 8)
                    ScreenHeader(eyebrow: "Practice", title: "Keep it fresh",
                                 subtitle: "Endless questions drawn from the whole library, plus a review of anything you got wrong.")
                    .padding(.top, 18)

                    dailyGoal.padding(.top, 24)

                    if !progress.data.mistakes.isEmpty {
                        Button {
                            session = QuizGenerator.mistakes(progress.data.mistakes)
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle().fill(Palette.wrongBG).frame(width: 46, height: 46)
                                    Image(systemName: "arrow.uturn.backward").font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.wrong)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Review mistakes").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                                    Text("\(progress.data.mistakes.count) question\(progress.data.mistakes.count == 1 ? "" : "s") to revisit")
                                        .font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                            .cardStyle(padding: 16)
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, 16)
                    }

                    Eyebrow("Quick quizzes").padding(.top, 32).padding(.bottom, 12)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(QuizGenerator.Kind.allCases) { k in
                            Button { start(k) } label: { tile(k) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, Metrics.margin)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $session) { s in LessonPlayer(session: s) }
        .onAppear {
            #if DEBUG
            DebugScreens.practiceHook { session = $0 }
            #endif
        }
    }

    private func start(_ k: QuizGenerator.Kind) {
        let maxLevel = max(progress.data.startLevel, progress.data.unlockedLevels.max() ?? 1)
        session = QuizGenerator.session(k, maxLevel: maxLevel)
    }

    private var dailyGoal: some View {
        HStack(spacing: 18) {
            GoalRing(progress: Double(progress.todayXP) / Double(max(1, progress.data.dailyGoal)), lineWidth: 5)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.goalReached ? "Daily goal reached" : "Daily goal").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Text("\(progress.todayXP) of \(progress.data.dailyGoal) XP today").font(.numeric(14, .regular)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            FlameBadge(count: progress.data.streak, active: progress.activeToday, size: 18)
        }
        .cardStyle(padding: 18)
    }

    private func tile(_ k: QuizGenerator.Kind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: k.icon).font(.system(size: 18, weight: .regular)).foregroundStyle(k == .mixed ? .white : Palette.wine)
                .frame(width: 38, height: 38)
                .background(Circle().fill(k == .mixed ? Palette.wine : Palette.wineSoft))
            VStack(alignment: .leading, spacing: 3) {
                Text(k.title).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Text(k.subtitle).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }
}
