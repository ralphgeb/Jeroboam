import SwiftUI

/// True when the window is wide enough for a two-pane layout: a foldable iPhone opened flat, or any iPhone turned sideways.
/// Pictures and maps go on the left, the writing on the right; narrow windows keep the single iPhone column.
private struct IsWideKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isWide: Bool {
        get { self[IsWideKey.self] }
        set { self[IsWideKey.self] = newValue }
    }
}

private struct WindowWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    /// The window's width in points (0 before it is measured).
    var windowWidth: CGFloat {
        get { self[WindowWidthKey.self] }
        set { self[WindowWidthKey.self] = newValue }
    }
}

private struct HasRailKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True when the tabs stand up in a column on the right (the iPhone Duo's screens) instead of sitting at the bottom.
    var hasRail: Bool {
        get { self[HasRailKey.self] }
        set { self[HasRailKey.self] = newValue }
    }
}

enum AdaptiveLayout {
    /// Width of the right-hand column that holds the tabs on the Duo.
    static let railWidth: CGFloat = 78
    /// Side-by-side pictures and text need this much room (the open Duo held sideways); upright it keeps one roomy column.
    static let twoPaneThreshold: CGFloat = 760
    /// Windows at least this wide (in points) switch to the two-pane layout.
    static let wideThreshold: CGFloat = 640
}

struct AdaptiveRoot<Content: View>: View {
    @State private var width: CGFloat = 0
    @ViewBuilder let content: Content
    var body: some View {
        content
            .environment(\.isWide, width >= AdaptiveLayout.wideThreshold)
            .environment(\.windowWidth, width)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { width = g.size.width }
                        .onChange(of: g.size.width) { _, w in width = w }
                }
            )
    }
}

extension View {
    /// Keeps long text at a comfortable line length on wide windows.
    func readable(_ maxWidth: CGFloat = 820) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}
