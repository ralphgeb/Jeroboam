import SwiftUI

/// A grey placeholder bar with a light that sweeps across it: the "working on it" look of a web page that is still loading.
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var radius: CGFloat? = nil
    @State private var phase: CGFloat = -0.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let r = radius ?? height / 2
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(Palette.line.opacity(0.75))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, Palette.card.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: max(40, g.size.width * 0.45))
                        .offset(x: phase * g.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
                .allowsHitTesting(false)
            }
            .onAppear {
                // with Reduce Motion the bar stays still (a calm grey placeholder)
                if !reduceMotion { withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { phase = 1.1 } }
            }
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    var body: some View { SkeletonBar(width: size, height: size, radius: size / 2) }
}

/// The result of a scan, drawn as grey bars while the label is being read: the picture, then cards with no words yet.
struct ScanSkeleton: View {
    private static let steps = ["Reading the label…", "Finding the producer…", "Working out the region…", "Checking the grapes…", "Looking up the price…"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TimelineView(.periodic(from: .now, by: 1.7)) { ctx in
                let i = Int(ctx.date.timeIntervalSinceReferenceDate / 1.7) % Self.steps.count
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(Palette.wine)
                    Text(Self.steps[i]).font(.jero(size: 14.5, weight: .medium)).foregroundStyle(Palette.inkSoft)
                        .id(i).transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.3), value: i)
            }
            // the wine card
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    SkeletonBar(width: 110, height: 10)
                    SkeletonBar(height: 20)
                    SkeletonBar(width: 190, height: 20)
                    SkeletonBar(width: 120, height: 12)
                }
                SkeletonBar(height: 34, radius: 17)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 7) { SkeletonCircle(size: 28); SkeletonBar(width: 38, height: 8) }.frame(maxWidth: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBar(height: 11)
                    SkeletonBar(height: 11)
                    SkeletonBar(width: 150, height: 11)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
            // the price card
            HStack(spacing: 14) {
                SkeletonCircle(size: 40)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBar(width: 130, height: 18)
                    SkeletonBar(width: 190, height: 10)
                    SkeletonBar(width: 150, height: 10)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
            // the bottles row and the button
            HStack { SkeletonBar(width: 70, height: 14); Spacer(); SkeletonBar(width: 100, height: 30, radius: 15) }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            SkeletonBar(height: 52, radius: 26)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading the label")
    }
}

/// The wine profile card's place while the grapes are being checked (same title, five soft rows).
struct ProfileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wine profile").font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("Working it out from the grapes…").font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).padding(.top, -6)
            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonBar(width: 70, height: 10)
                        SkeletonBar(height: 8)
                    }
                    .opacity(1 - Double(i) * 0.1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
        .accessibilityLabel("Wine profile loading")
    }
}
