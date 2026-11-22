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

/// Where a cover (the full-screen map, say) is drawn on the Duo: over the whole page area, in front of the page it came
/// from, with the tab column still in view. RootView owns one and shows whatever is set here.
@Observable final class CoverHost {
    static let shared = CoverHost()
    var content: AnyView? = nil
    var owner: AnyHashable? = nil
    /// The Jero Plus panel, shown on the right half in the two-pane layout.
    var paywall: AnyView? = nil
    /// Set by RootView: true while the Duo layout (tabs in a column) is on, and how wide the page area is.
    var railActive = false
    var pageWidth: CGFloat = 0
}
private struct CoverHostKey: EnvironmentKey { static let defaultValue: CoverHost? = nil }
extension EnvironmentValues {
    var coverHost: CoverHost? {
        get { self[CoverHostKey.self] }
        set { self[CoverHostKey.self] = newValue }
    }
}

private struct RailCover<Item: Identifiable, Cover: View>: ViewModifier {
    @Binding var item: Item?
    let cover: (Item) -> Cover
    @Environment(\.hasRail) private var hasRail
    @Environment(\.coverHost) private var host
    @State private var token = UUID()

    func body(content: Content) -> some View {
        if hasRail, let host {
            content
                .onChange(of: item?.id as AnyHashable?, initial: true) { _, id in
                    if let it = item, id != nil {
                        host.owner = token
                        host.content = AnyView(cover(it).environment(\.coverClose, { item = nil }))
                    } else if host.owner == AnyHashable(token) {
                        host.content = nil; host.owner = nil
                    }
                }
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

/// Which pages have scrolled their big title up into the small top bar; the profile button steps aside when one has.
@Observable final class HeaderState {
    static let shared = HeaderState()
    var collapsed: [String: Bool] = [:]
}

// MARK: - Page chrome

/// Pushed pages. On a phone: the usual small navigation bar. On the Duo the bar is hidden, so every page starts at the same
/// height as the tab pages, and a round back button sits in the top-left corner instead.
private struct PageChrome: ViewModifier {
    @Environment(\.hasRail) private var hasRail
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowWidth) private var width

    func body(content: Content) -> some View {
        if hasRail {
            content
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if isPresented {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                    .frame(width: 34, height: 34).background(Circle().fill(Palette.card))
                                    .overlay(Circle().strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
                            }
                            .accessibilityLabel("Back")
                            Spacer()
                        }
                        .padding(.horizontal, Metrics.margin).padding(.top, 2).padding(.bottom, 2)
                    }
                }
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension View {
    func pageChrome() -> some View { modifier(PageChrome()) }
}
