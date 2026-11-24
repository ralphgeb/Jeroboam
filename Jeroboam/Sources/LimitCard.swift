import SwiftUI

/// An error line under a scan. The daily limit gets a proper card; anything else stays a short red note.
struct ErrorNote: View {
    let message: String
    var body: some View {
        if message == RecognizerError.limit.errorDescription {
            LimitReachedCard()
        } else {
            Text(message).font(.system(size: 13.5)).foregroundStyle(Palette.wrong)
        }
    }
}

/// "You've used today's new wines": an almost empty glass inside a filled ring, what still works, and when it opens again.
struct LimitReachedCard: View {
    @State private var ring: CGFloat = 0
    @State private var glow = false

    private var resetText: String {
        let cal = Calendar.current
        guard let next = cal.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) else { return "tomorrow" }
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        let s = f.string(from: Date(), to: next) ?? "tomorrow"
        return "in " + s
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Palette.wine.opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: ring)
                    .stroke(AngularGradient(colors: [Palette.bordeaux, Palette.pink, Palette.bordeaux], center: .center),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(Palette.wineSoft).padding(16)
                    .scaleEffect(glow ? 1.03 : 0.97)
                WineGlass(color: Palette.wine, fill: 0.1).frame(width: 48, height: 66)
            }
            .frame(width: 128, height: 128)
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("That's today's limit").font(.system(size: 21, weight: .bold)).foregroundStyle(Palette.ink)
                Text("You have used up today's new wines. They open again tomorrow.")
                    .font(.system(size: 14.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                tile("checkmark.seal.fill", "Known wines", "Still free")
                tile("clock.fill", "New wines", resetText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Palette.wineSoft, Palette.card], startPoint: .top, endPoint: .center))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { ring = 1 }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func tile(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Palette.wine)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    }
}
