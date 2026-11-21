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
