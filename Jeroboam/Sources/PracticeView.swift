import SwiftUI

struct PracticeView: View {
    @Environment(GameProgress.self) private var progress
    @State private var session: Session? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TopStatusBar().padding(.top, 8)
                    ScreenHeader(eyebrow: "Practice", title: "Keep it fresh",
                                 subtitle: "Short quizzes drawn from everything you have learned.")

                    VStack(spacing: 12) {
                        GroupCard {
                            HStack(spacing: 14) {
                                GoalRing(progress: Double(progress.todayXP) / Double(max(1, progress.data.dailyGoal)), lineWidth: 4)
                                    .frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(progress.goalReached ? "Daily goal reached" : "Daily goal").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                                    Text("\(progress.todayXP) of \(progress.data.dailyGoal) XP today").font(.system(size: 13).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                FlameBadge(count: progress.data.streak, active: progress.activeToday, size: 15)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            if !progress.data.mistakes.isEmpty {
                                Hairline().padding(.leading, 68)
                                Button { session = QuizGenerator.mistakes(progress.data.mistakes) } label: {
                                    IconRow(title: "Review mistakes", detail: "\(progress.data.mistakes.count) to revisit", last: true) {
                                        Image(systemName: "arrow.uturn.backward").font(.system(size: 15)).foregroundStyle(Palette.wrong)
                                    }
                                }
                                .buttonStyle(RowPressStyle())
                            }
                        }
                        Button { start(.mixed) } label: {
                            Label("Start daily mix", systemImage: "shuffle")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "By topic")
                        let kinds = QuizGenerator.Kind.allCases.filter { $0 != .mixed }
                        GroupCard {
                            ForEach(kinds) { k in
                                Button { start(k) } label: {
                                    IconRow(title: k.title, detail: k.subtitle, last: k == kinds.last) {
                                        Image(systemName: k.icon).font(.system(size: 16)).foregroundStyle(Palette.wine)
                                    }
                                }
                                .buttonStyle(RowPressStyle())
                            }
                        }
                    }
                    Color.clear.frame(height: 24)
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

}
