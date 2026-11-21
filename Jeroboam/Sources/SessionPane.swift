import SwiftUI

extension View {
    /// Lessons and quizzes: a full-screen cover on a phone, but the right-hand pane on the Duo opened sideways, so the
    /// list stays on the left while the questions move on the right. `idle` fills the pane between lessons.
    func sessionPane(_ session: Binding<Session?>, idle: @escaping () -> AnyView) -> some View {
        modifier(SessionPaneModifier(session: session, idle: idle))
    }
}

private struct SessionPaneModifier: ViewModifier {
    @Binding var session: Session?
    let idle: () -> AnyView
    @Environment(\.windowWidth) private var width

    func body(content: Content) -> some View {
        if width >= AdaptiveLayout.twoPaneThreshold {
            HStack(spacing: 0) {
                content.frame(width: width / 2)
                Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                Group {
                    if let s = session {
                        LessonPlayer(session: s, onClose: { session = nil }).id(s.id)
                    } else {
                        idle()
                    }
                }
                .frame(width: width / 2 - 0.5)
                .background(Palette.paper.ignoresSafeArea())
            }
        } else {
            content.fullScreenCover(item: $session) { s in LessonPlayer(session: s) }
        }
    }
}

/// What the right-hand pane shows between lessons.
struct PaneIdle: View {
    let eyebrow: String
    let title: String
    let text: String
    var button: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            SplashMark().frame(width: 74, height: 74)
            Eyebrow(eyebrow, color: Palette.wine)
            Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text(text).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).frame(maxWidth: 360)
            if let button, let action {
                Button(action: action) { Text(button).frame(maxWidth: 280) }.buttonStyle(PrimaryButtonStyle()).padding(.top, 6)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The right-hand pane on the Learn tab before a lesson starts: what the next lesson covers, from the top of the pane.
struct LessonPreviewPane: View {
    let lesson: Lesson
    let level: Int
    let onStart: () -> Void
    var body: some View {
        let topics = lesson.cards.filter { !$0.isQuestion }.compactMap(\.title)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Up next · Level \(level)", color: .white.opacity(0.75))
                    Text(lesson.title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(lesson.cards.count) cards · \(lesson.questionCount) questions")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                    Button(action: onStart) {
                        Text("Start lesson").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.wine)
                            .padding(.horizontal, 22).padding(.vertical, 12).background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain).padding(.top, 8)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Metrics.radius + 4, style: .continuous).fill(Palette.wine))
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: "In this lesson").padding(.bottom, 8)
                        ForEach(Array(topics.enumerated()), id: \.offset) { i, t in
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", i + 1)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Palette.wine)
                                Text(t).font(.system(size: 16)).foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 11)
                            Hairline()
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.top, 12).padding(.bottom, 24)
        }
    }
}
