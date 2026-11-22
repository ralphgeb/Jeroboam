import SwiftUI

/// A typographic mock label with numbered callouts.
struct WineLabelView: View {
    let label: WineLabel
    var numbered = true
    var selected: Int? = nil
    var onTap: ((Int) -> Void)? = nil

    private var style: (paper: Color, ink: Color, accent: Color, border: Int) {
        switch label.style {
        case "chateau": return (Color(hex: "#FBF6EC"), Color(hex: "#1D1416"), Color(hex: "#8B1538"), 2)
        case "burgundy": return (Color(hex: "#F7F1E4"), Color(hex: "#20160F"), Color(hex: "#7A4A1E"), 1)
        case "champagne": return (Color(hex: "#111111"), Color(hex: "#F3E7C9"), Color(hex: "#D4AF55"), 1)
        case "alsace": return (Color(hex: "#F4F7F1"), Color(hex: "#1B2418"), Color(hex: "#4E7A3A"), 0)
        case "german": return (Color(hex: "#FFFFFF"), Color(hex: "#151515"), Color(hex: "#B5121B"), 0)
        case "italian": return (Color(hex: "#FBF7EE"), Color(hex: "#231812"), Color(hex: "#9A2B1F"), 2)
        case "spanish": return (Color(hex: "#F6EBDD"), Color(hex: "#24130E"), Color(hex: "#B0472A"), 1)
        case "port": return (Color(hex: "#1E1416"), Color(hex: "#F1E4CF"), Color(hex: "#C79A4B"), 2)
        default: return (Color(hex: "#FFFFFF"), Color(hex: "#111111"), Color(hex: "#C2185B"), 0)
        }
    }

    var body: some View {
        let st = style
        VStack(spacing: 10) {
            ForEach(Array(label.fields.enumerated()), id: \.offset) { i, f in
                HStack(alignment: .center, spacing: 8) {
                    if numbered { badge(i + 1, on: selected == i).opacity(0) }
                    text(f, st: st)
                        .frame(maxWidth: .infinity)
                    if numbered { badge(i + 1, on: selected == i) }
                }
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Palette.pink, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .opacity(selected == i ? 1 : 0)
                        .padding(.horizontal, -4)
                )
                .opacity(selected == nil || selected == i ? 1 : 0.45)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(i) }
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 14)
        .background(st.paper)
        .overlay(borders(st))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    @ViewBuilder private func borders(_ st: (paper: Color, ink: Color, accent: Color, border: Int)) -> some View {
        switch st.border {
        case 2:
            ZStack {
                RoundedRectangle(cornerRadius: 4).strokeBorder(st.accent, lineWidth: 1.5).padding(6)
                RoundedRectangle(cornerRadius: 3).strokeBorder(st.accent.opacity(0.6), lineWidth: 0.6).padding(10)
            }
        case 1:
            Rectangle().strokeBorder(st.accent.opacity(0.7), lineWidth: 1).padding(8)
        default:
            VStack { Rectangle().fill(st.accent).frame(height: 6); Spacer() }
        }
    }

    private func badge(_ n: Int, on: Bool) -> some View {
        Text("\(n)").font(.system(size: 10.5, weight: .semibold).monospacedDigit()).foregroundStyle(on ? .white : Palette.pink)
            .frame(width: 19, height: 19)
            .background(Circle().fill(on ? Palette.pink : Color.white))
            .overlay(Circle().strokeBorder(Palette.pink, lineWidth: 1))
    }

    @ViewBuilder private func text(_ f: WineLabel.Field, st: (paper: Color, ink: Color, accent: Color, border: Int)) -> some View {
        let serifStyles = ["chateau", "burgundy", "italian", "port", "spanish"].contains(label.style)
        switch f.kind {
        case "title":
            Text(f.text)
                .font(serifStyles ? .system(size: 25, weight: .semibold, design: .serif) : .system(size: 24, weight: .bold))
                .foregroundStyle(st.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
        case "place":
            Text(f.text.uppercased()).font(.system(size: 15, weight: .bold)).kerning(2).foregroundStyle(st.accent)
                .multilineTextAlignment(.center)
        case "class":
            Text(f.text).font(serifStyles ? .system(size: 14, weight: .regular, design: .serif).italic() : .system(size: 15, weight: .semibold))
                .foregroundStyle(st.ink).multilineTextAlignment(.center)
        case "vintage":
            Text(f.text).font(.system(size: 18, weight: .bold, design: serifStyles ? .serif : .default)).foregroundStyle(st.ink)
        case "badge":
            Text(f.text.uppercased()).font(.system(size: 10.5, weight: .semibold)).kerning(1.2).foregroundStyle(st.paper)
                .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(st.accent))
                .multilineTextAlignment(.center)
        case "small":
            Text(f.text.uppercased()).font(.system(size: 10.5, weight: .semibold)).kerning(2).foregroundStyle(st.ink.opacity(0.75))
                .multilineTextAlignment(.center)
        default:
            Text(f.text).font(.system(size: 9.5, weight: .medium)).foregroundStyle(st.ink.opacity(0.65)).multilineTextAlignment(.center)
        }
    }
}

/// Label + numbered explanations: tap a part of the label (or step with the arrows).
struct LabelDecoderCard: View {
    let label: WineLabel
    @State private var current = 0

    static func kindName(_ k: String) -> String {
        switch k {
        case "title": return "Name"
        case "place": return "Place of origin"
        case "class": return "Classification"
        case "vintage": return "Vintage"
        case "badge": return "Quality mark"
        case "small": return "Detail"
        default: return "Small print"
        }
    }

    var body: some View {
        let fields = label.fields
        VStack(alignment: .leading, spacing: 16) {
            WineLabelView(label: label, selected: current) { i in
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.2)) { current = i }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)

            if fields.indices.contains(current) {
                let f = fields[current]
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("\(current + 1)").font(.system(size: 10.5, weight: .semibold).monospacedDigit()).foregroundStyle(.white)
                            .frame(width: 19, height: 19).background(Circle().fill(Palette.pink))
                        Text(Self.kindName(f.kind)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(current + 1) of \(fields.count)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkFaint)
                        stepButton("chevron.left", enabled: current > 0) { current -= 1 }
                        stepButton("chevron.right", enabled: current < fields.count - 1) { current += 1 }
                    }
                    Text(rich(f.note)).font(.system(size: 15)).foregroundStyle(Palette.ink.opacity(0.9)).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(current)
                        .transition(.opacity)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
            }
        }
        .onChange(of: label.id) { _, _ in current = 0 }
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.cardAlt))
                .foregroundStyle(enabled ? Palette.ink : Palette.inkFaint)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct LabelsScreen: View {
    @State private var selected: String? = "bordeaux"
    @Environment(\.windowWidth) private var width
    var body: some View {
        if width >= AdaptiveLayout.twoPaneThreshold { wideBody } else { narrowBody }
    }

    /// Duo: the regions listed on the left, the chosen label (with its numbered parts) on the right.
    private var wideBody: some View {
        let labels = ContentStore.shared.library.labels ?? []
        let current = labels.first { $0.id == selected } ?? labels.first
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ScreenHeader(eyebrow: "Read any bottle", title: "Label decoder",
                                 subtitle: "Pick a region, then tap a numbered part of its label to see what it tells you.")
                        .padding(.bottom, 6)
                    ForEach(labels) { l in
                        Button { withAnimation(.smooth(duration: 0.25)) { selected = l.id } } label: {
                            HStack {
                                Text(l.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(current?.id == l.id ? Palette.wineSoft : Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .strokeBorder(current?.id == l.id ? Palette.wine.opacity(0.55) : Palette.line.opacity(0.6), lineWidth: current?.id == l.id ? 1.2 : 0.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .frame(width: width / 2)
            Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
            ScrollView {
                if let l = current {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(l.title).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(rich(l.summary)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        LabelDecoderCard(label: l)
                    }
                    .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
                    .id(l.id)
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: width / 2 - 0.5)
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
    }

    private var narrowBody: some View {
        let labels = ContentStore.shared.library.labels ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Read any bottle", title: "Label decoder",
                             subtitle: "Swipe between regions, then tap a numbered part of the label to see what it tells you.")
                    .padding(.horizontal, Metrics.margin)
                    .readable(720)
                ScrollViewReader { chips in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(labels) { l in
                                Button { withAnimation(.smooth(duration: 0.35)) { selected = l.id } } label: {
                                    Text(l.title).font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selected == l.id ? Palette.onWine : Palette.ink)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(selected == l.id ? Palette.wine : Palette.cardAlt))
                                }
                                .buttonStyle(.plain)
                                .id(l.id)
                            }
                        }
                        .padding(.horizontal, Metrics.margin)
                    }
                    .onChange(of: selected) { _, id in withAnimation(.smooth) { chips.scrollTo(id, anchor: .center) } }
                }
                // One page per label: swipe left and right, the cards slide whole.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(labels) { l in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(rich(l.summary)).font(.system(size: 15)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                LabelDecoderCard(label: l)
                            }
                            .padding(.horizontal, Metrics.margin)
                            .containerRelativeFrame(.horizontal)
                            .id(l.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selected)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        .background(Palette.paper.ignoresSafeArea())
        .pageChrome()
    }
}
