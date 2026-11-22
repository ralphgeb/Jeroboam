import SwiftUI

extension View {
    /// Lessons and quizzes: a full-screen cover on a phone, but the right-hand pane on the Duo opened sideways, so the
    /// list stays on the left while the questions move on the right. `idle` fills the pane between lessons.
    func sessionPane(_ session: Binding<Session?>, guide: Binding<Unit?> = .constant(nil), idle: @escaping () -> AnyView) -> some View {
        modifier(SessionPaneModifier(session: session, guide: guide, idle: idle))
    }

    /// A guidebook opens as a sheet on a phone; on the Duo it opens in the right-hand pane instead (see `sessionPane`).
    func guidebookSheet(_ guide: Binding<Unit?>) -> some View { modifier(GuidebookSheet(guide: guide)) }
}

private struct GuidebookSheet: ViewModifier {
    @Binding var guide: Unit?
    @Environment(\.windowWidth) private var width
    func body(content: Content) -> some View {
        if width >= AdaptiveLayout.twoPaneThreshold { content } else { content.sheet(item: $guide) { GuidebookView(unit: $0) } }
    }
}

private struct SessionPaneModifier: ViewModifier {
    @Binding var session: Session?
    @Binding var guide: Unit?
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
                    } else if let u = guide {
                        GuidebookView(unit: u).id(u.id)
                            .environment(\.coverClose, { guide = nil })
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

/// What the right-hand pane shows between lessons: a title, a small start button, and something underneath.
struct PaneIdle: View {
    let eyebrow: String
    let title: String
    let text: String
    var button: String? = nil
    var action: (() -> Void)? = nil
    var chips: [(String, String)] = []
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack { Circle().fill(Palette.wineSoft); SplashMark().frame(width: 52, height: 52) }.frame(width: 96, height: 96)
                Eyebrow(eyebrow, color: Palette.wine)
                Text(title).font(.system(size: 27, weight: .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                Text(text).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).frame(maxWidth: 360)
                if let button, let action { StartPill(title: button, action: action).padding(.top, 2) }
                if !chips.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(Array(chips.enumerated()), id: \.offset) { _, c in
                            HStack(spacing: 6) {
                                Image(systemName: c.0).font(.system(size: 13)).foregroundStyle(Palette.wine)
                                Text(c.1).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.ink)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Capsule().fill(Palette.card))
                            .overlay(Capsule().strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.top, 80).padding(.bottom, 30)
        }
    }
}

/// A small rounded start button (the full-width one looked too heavy beside the lists).
struct StartPill: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 15.5, weight: .semibold))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Palette.onWine)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Capsule().fill(Palette.wine))
        }
        .buttonStyle(.plain)
    }
}

/// The right-hand pane on the Learn tab before a lesson starts: the next lesson, a small start button and what is in it.
struct LessonPreviewPane: View {
    let lesson: Lesson
    let level: Int
    let onStart: () -> Void
    var body: some View {
        let topics = lesson.cards.filter { !$0.isQuestion }.compactMap(\.title)
        ScrollView {
            VStack(spacing: 14) {
                ZStack { Circle().fill(Palette.wineSoft); SplashMark().frame(width: 52, height: 52) }.frame(width: 96, height: 96)
                Eyebrow("Up next · Level \(level)", color: Palette.wine)
                Text(lesson.title).font(.system(size: 27, weight: .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                Text("\(lesson.cards.count) cards · \(lesson.questionCount) questions").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                StartPill(title: "Start lesson", action: onStart).padding(.top, 2)
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("In this lesson").font(.sectionTitle).foregroundStyle(Palette.ink).padding(.bottom, 6)
                        ForEach(Array(topics.enumerated()), id: \.offset) { i, t in
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", i + 1)).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
                                Text(t).font(.system(size: 15.5)).foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            if i < topics.count - 1 { Hairline() }
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.top, 80).padding(.bottom, 30)
        }
    }
}
