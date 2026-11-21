import SwiftUI

/// Foldable preview: shows the whole app in a frame the size of an iPhone Duo screen, scaled to fit this phone, so you can
/// click through every page exactly as it would lay out there. Switch it in Profile > Settings > Foldable preview.
enum DuoPreviewMode: Int, CaseIterable, Identifiable {
    case off, outside, insidePortrait, insideLandscape
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .outside: return "Outer screen"
        case .insidePortrait: return "Inside, upright"
        case .insideLandscape: return "Inside, sideways"
        }
    }
    /// The Duo's point sizes: outer 466×678, inner 669×951 (turned: 951×669).
    var size: CGSize? {
        switch self {
        case .off: return nil
        case .outside: return CGSize(width: 466, height: 678)
        case .insidePortrait: return CGSize(width: 669, height: 951)
        case .insideLandscape: return CGSize(width: 951, height: 669)
        }
    }
}

struct DuoPreviewHost<Content: View>: View {
    @AppStorage("jero.duoPreview") private var raw = 0
    @ViewBuilder let content: Content

    var body: some View {
        if let size = DuoPreviewMode(rawValue: raw)?.size {
            GeometryReader { geo in
                let s = min(geo.size.width / size.width, geo.size.height / size.height)
                ZStack {
                    Color.black.ignoresSafeArea()
                    content
                        .frame(width: size.width, height: size.height)
                        .ignoresSafeArea()
                        .background(Palette.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .scaleEffect(s)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .overlay(alignment: .top) {
                    Button { raw = 0 } label: {
                        Label("Exit \(DuoPreviewMode(rawValue: raw)?.title.lowercased() ?? "preview")", systemImage: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                    }
                    .padding(.top, 2)
                }
            }
        } else {
            content
        }
    }
}

/// The Settings control: Off, Outer screen, Inside upright, Inside sideways.
struct DuoPreviewPicker: View {
    @AppStorage("jero.duoPreview") private var raw = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Foldable preview")
            Text("See the whole app laid out for an iPhone Duo screen, right on this phone.")
                .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            HStack(spacing: 8) {
                ForEach(DuoPreviewMode.allCases) { m in
                    Button { raw = m.rawValue } label: {
                        Text(m.title).font(.system(size: 12.5, weight: .semibold)).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(raw == m.rawValue ? Palette.onWine : Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(raw == m.rawValue ? Palette.wine : Palette.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
