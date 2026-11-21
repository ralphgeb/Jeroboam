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

// MARK: - Duo helpers

private struct CoverCloseKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    /// Set while a cover is drawn inside the window (not as a system full-screen cover): how to close it.
    var coverClose: (() -> Void)? {
        get { self[CoverCloseKey.self] }
        set { self[CoverCloseKey.self] = newValue }
    }
}

private struct RailCover<Item: Identifiable, Cover: View>: ViewModifier {
    @Binding var item: Item?
    let cover: (Item) -> Cover
    @Environment(\.hasRail) private var hasRail

    func body(content: Content) -> some View {
        if hasRail {
            // On the Duo the cover fills this page only (the tabs stay in their column) and stays inside the preview frame.
            content.overlay {
                if let it = item {
                    cover(it)
                        .environment(\.coverClose, { withAnimation(.easeInOut(duration: 0.25)) { item = nil } })
                        .background(Palette.paper.ignoresSafeArea())
                        .ignoresSafeArea()
                        .transition(.move(edge: .bottom))
                        .zIndex(5)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: item?.id as AnyHashable?)
        } else {
            content.fullScreenCover(item: $item) { cover($0) }
        }
    }
}

private struct BoolItem: Identifiable { let id = 1 }

extension View {
    func railCover<Item: Identifiable, Cover: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Cover) -> some View {
        modifier(RailCover(item: item, cover: content))
    }
    func railCover<Cover: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Cover) -> some View {
        railCover(item: Binding<BoolItem?>(get: { isPresented.wrappedValue ? BoolItem() : nil },
                                           set: { if $0 == nil { isPresented.wrappedValue = false } })) { _ in content() }
    }

    /// A page with no side detail: it takes the left half of a two-pane screen, like the pages that do have one,
    /// and the right half stays quiet.
    func halfPage() -> some View { modifier(HalfPage()) }
}

private struct HalfPage: ViewModifier {
    @Environment(\.windowWidth) private var width
    func body(content: Content) -> some View {
        if width >= AdaptiveLayout.twoPaneThreshold {
            HStack(spacing: 0) {
                content
                    .environment(\.windowWidth, width / 2)
                    .environment(\.isWide, false)
                    .frame(width: width / 2)
                Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                ZStack { Palette.paper; SplashMark().frame(width: 90, height: 90).opacity(0.08) }
                    .frame(width: width / 2 - 0.5)
            }
        } else {
            content
        }
    }
}
