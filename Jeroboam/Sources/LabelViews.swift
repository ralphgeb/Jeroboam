import SwiftUI

/// A typographic mock label with numbered callouts.
struct WineLabelView: View {
    let label: WineLabel
    var numbered = true

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
                    if numbered { badge(i + 1, accent: st.accent).opacity(0) }
                    text(f, st: st)
                        .frame(maxWidth: .infinity)
                    if numbered { badge(i + 1, accent: st.accent) }
                }
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

    private func badge(_ n: Int, accent: Color) -> some View {
        Text("\(n)").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            .frame(width: 20, height: 20).background(Circle().fill(Palette.pink))
    }

    @ViewBuilder private func text(_ f: WineLabel.Field, st: (paper: Color, ink: Color, accent: Color, border: Int)) -> some View {
        let serifStyles = ["chateau", "burgundy", "italian", "port", "spanish"].contains(label.style)
        switch f.kind {
        case "title":
            Text(f.text)
                .font(serifStyles ? .system(size: 27, weight: .semibold, design: .serif) : .display(32, .black))
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
            Text(f.text.uppercased()).font(.system(size: 10.5, weight: .heavy)).kerning(1.2).foregroundStyle(st.paper)
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

/// Label + numbered explanations.
struct LabelDecoderCard: View {
    let label: WineLabel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WineLabelView(label: label)
                .padding(.horizontal, 18)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(label.fields.enumerated()), id: \.offset) { i, f in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 20, height: 20).background(Circle().fill(Palette.pink))
                        Text(rich(f.note)).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct LabelsScreen: View {
    @State private var selected: String = "bordeaux"
    var body: some View {
        let labels = ContentStore.shared.library.labels ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Read any bottle")
                    Text("LABEL DECODER").font(.display(42)).foregroundStyle(Palette.ink)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labels) { l in
                            Button { withAnimation(.easeInOut(duration: 0.2)) { selected = l.id } } label: {
                                Text(l.title).font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(selected == l.id ? Palette.onWine : Palette.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(selected == l.id ? Palette.wine : Palette.cardAlt))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let l = labels.first(where: { $0.id == selected }) {
                    Text(rich(l.summary)).font(.system(size: 15.5, weight: .medium)).foregroundStyle(Palette.inkSoft)
                    LabelDecoderCard(label: l)
                        .id(l.id)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
