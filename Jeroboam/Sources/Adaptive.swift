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

enum AdaptiveLayout {
    /// Windows at least this wide (in points) switch to the two-pane layout.
    static let wideThreshold: CGFloat = 640
}

struct AdaptiveRoot<Content: View>: View {
    @State private var width: CGFloat = 0
    @ViewBuilder let content: Content
    var body: some View {
        content
            .environment(\.isWide, width >= AdaptiveLayout.wideThreshold)
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
