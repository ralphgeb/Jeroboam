import SwiftUI

/// A label photo shown cropped in a page header; a tap opens the whole picture full screen (pinch or double-tap to zoom,
/// drag to look around, the X or a swipe down to close).
struct TappablePhoto: View {
    let image: UIImage
    var height: CGFloat = 260
    @State private var open = false

    var body: some View {
        Image(uiImage: image).resizable().scaledToFill().allowsHitTesting(false)
            .frame(height: height).frame(maxWidth: .infinity).clipped()
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(.black.opacity(0.35)))
                    .padding(10)
                    .accessibilityHidden(true)
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            .onTapGesture { Haptics.tap(); open = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo of the label")
            .accessibilityHint("Opens the whole picture")
            .accessibilityAddTraits(.isButton)
            .fullScreenCover(isPresented: $open) { PhotoViewer(image: image) }
    }
}

/// The whole photo on black, fitted to the screen, with zoom.
struct PhotoViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(zoom)
                    .offset(offset)
                    .gesture(MagnifyGesture()
                        .onChanged { v in zoom = min(5, max(1, lastZoom * v.magnification)) }
                        .onEnded { _ in
                            lastZoom = zoom
                            if zoom <= 1.01 { withAnimation(.easeOut(duration: 0.2)) { offset = .zero }; lastOffset = .zero }
                        })
                    .simultaneousGesture(DragGesture()
                        .onChanged { v in
                            if zoom > 1.01 {
                                offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
                            } else {
                                offset = CGSize(width: 0, height: max(0, v.translation.height))   // pull down to close
                            }
                        }
                        .onEnded { v in
                            if zoom > 1.01 { lastOffset = offset }
                            else if v.translation.height > 120 { dismiss() }
                            else { withAnimation(.easeOut(duration: 0.2)) { offset = .zero } }
                        })
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if zoom > 1.01 { zoom = 1; offset = .zero } else { zoom = 2.5 }
                        }
                        lastZoom = zoom; lastOffset = offset
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(Circle().fill(.white.opacity(0.18)))
            }
            .accessibilityLabel("Close")
            .padding(.top, 8).padding(.trailing, 16)
        }
        .statusBarHidden()
    }
}
