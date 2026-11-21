import SwiftUI
import Observation

/// Two-pane pages for the Duo opened sideways: the list or overview sits on the left, and whatever you pick opens on the
/// right (the first item is already open). On a narrow window the same links simply push the page as before.
@Observable final class DetailPane {
    var value: AnyHashable? = nil
}

private struct DetailPaneKey: EnvironmentKey { static let defaultValue: DetailPane? = nil }
extension EnvironmentValues {
    var detailPane: DetailPane? {
        get { self[DetailPaneKey.self] }
        set { self[DetailPaneKey.self] = newValue }
    }
}

extension View {
    /// Turns a list page into list-left, detail-right when the window is wide enough. `first` is open until you pick another.
    func detailPane(first: AnyHashable?) -> some View { modifier(DetailPaneModifier(first: first)) }
}

private struct DetailPaneModifier: ViewModifier {
    let first: AnyHashable?
    @State private var pane = DetailPane()
    @Environment(\.windowWidth) private var width

    func body(content: Content) -> some View {
        if width >= AdaptiveLayout.twoPaneThreshold {
            HStack(spacing: 0) {
                content
                    .environment(\.detailPane, pane)
                    .frame(width: width / 2)
                Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                Group {
                    if let v = pane.value ?? first {
                        DetailDestination(value: v).id(v)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: width / 2 - 0.5)
                .background(Palette.paper.ignoresSafeArea())
            }
        } else {
            content
        }
    }
}

/// A row or card that opens its page on the right when the window is wide, and pushes it otherwise.
struct DetailLink<Label: View, V: Hashable>: View {
    let value: V
    @ViewBuilder let label: Label
    @Environment(\.detailPane) private var pane

    var body: some View {
        if let pane {
            Button { pane.value = AnyHashable(value) } label: { label }
        } else {
            NavigationLink(value: value) { label }
        }
    }
}

/// Which page opens for which kind of item.
struct DetailDestination: View {
    let value: AnyHashable
    var body: some View {
        Group {
            if let g = value.base as? Grape {
                PlusGate(quota: "grapes", id: g.id) { GrapeDetailView(grape: g) }
            } else if let r = value.base as? Region {
                PlusGate(country: r.gateCountry, reason: "Every country and appellation comes with Jero Plus.") { RegionDetailView(region: r) }
            } else if let w = value.base as? Wine {
                PlusGate(quota: "wines", id: w.id) { WineDetailView(wine: w) }
            } else if let w = value.base as? GreatWine {
                PlusGate(quota: "great", id: w.id) { GreatWinePager(wine: w) }
            } else if let s = value.base as? WineStyle {
                PlusGate(quota: "styles", id: s.id) { StyleDetailView(style: s) }
            } else {
                Color.clear
            }
        }
    }
}

extension View {
    /// Content on the left half and `right` on the right half, when the window is wide enough; otherwise just the content.
    func rightPane<R: View>(@ViewBuilder _ right: @escaping () -> R) -> some View { modifier(RightPaneModifier(right: right)) }
}

private struct RightPaneModifier<R: View>: ViewModifier {
    let right: () -> R
    @Environment(\.windowWidth) private var width
    func body(content: Content) -> some View {
        if width >= AdaptiveLayout.twoPaneThreshold {
            HStack(spacing: 0) {
                content.frame(width: width / 2)
                Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                right().frame(width: width / 2 - 0.5).background(Palette.paper.ignoresSafeArea())
            }
        } else {
            content
        }
    }
}
