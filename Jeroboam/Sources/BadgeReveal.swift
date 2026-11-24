import SwiftUI
import UIKit

/// The ways a new badge can be announced. One is active in the app; TestFlight builds can try them all (Settings > TestFlight).
enum BadgeStyle: String, CaseIterable, Identifiable {
    case spin, flip, pour, burst, stamp
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spin: return "Spin and color"
        case .flip: return "Flip and shine"
        case .pour: return "Pour"
        case .burst: return "Burst"
        case .stamp: return "Stamp"
        }
    }
    var blurb: String {
        switch self {
        case .spin: return "A white page, the badge as a silhouette spins and its colors appear"
        case .flip: return "The badge flips in and a light sweeps across it"
        case .pour: return "The badge fills with color from the bottom, like a glass"
        case .burst: return "Wine-red page, rays and sparks around the badge"
        case .stamp: return "The badge drops in and stamps the page with a ripple"
        }
    }
    private static let key = "jero.badgeStyle"
    static var active: BadgeStyle {
        get { BadgeStyle(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .spin }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// The full-page announcement: the badge name on top, the badge in the middle and the date you got it below.
struct BadgeAnnouncePage: View {
    let achievement: Achievement
    let date: Date?
    let style: BadgeStyle
    let onDone: () -> Void

    @State private var angle: Double
    @State private var color: Double = 0
    @State private var scale: CGFloat
    @State private var drop: CGFloat
    @State private var fill: CGFloat = 0
    @State private var shine: CGFloat = -1.2
    @State private var burst: CGFloat = 0
    @State private var ring: CGFloat = 0
    @State private var showText = false

    private let ink = Color(hex: "#1B0D12"), soft = Color(hex: "#6B5C61"), wine = Color(hex: "#8B1538")
    private let size: CGFloat = 230
    private var dark: Bool { style == .burst }

    init(achievement: Achievement, date: Date?, style: BadgeStyle, onDone: @escaping () -> Void) {
        self.achievement = achievement; self.date = date; self.style = style; self.onDone = onDone
        _angle = State(initialValue: style == .flip ? -180 : 0)
        _scale = State(initialValue: style == .flip ? 0.5 : (style == .burst ? 0.1 : (style == .stamp ? 1.6 : 1)))
        _drop = State(initialValue: style == .stamp ? -560 : 0)
    }

    var body: some View {
        ZStack {
            if dark {
                LinearGradient(colors: [Color(hex: "#8B1538"), Color(hex: "#3A0A1B")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                rays
            } else {
                Color.white.ignoresSafeArea()
            }
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(spacing: 8) {
                    Text("BADGE UNLOCKED").font(.system(size: 12, weight: .semibold)).kerning(1.6)
                        .foregroundStyle(dark ? Color.white.opacity(0.75) : wine)
                    Text(achievement.title).font(.system(size: 30, weight: .bold))
                        .foregroundStyle(dark ? Color.white : ink).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .opacity(showText ? 1 : 0).offset(y: showText ? 0 : 10)
                Spacer(minLength: 12)
                stage.frame(width: size + 70, height: size + 70)
                Spacer(minLength: 12)
                VStack(spacing: 6) {
                    Text(achievement.detail).font(.system(size: 16)).foregroundStyle(dark ? Color.white.opacity(0.85) : soft)
                        .multilineTextAlignment(.center)
                    if let date {
                        Text("Unlocked " + date.formatted(date: .long, time: .omitted))
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(dark ? Color.white.opacity(0.7) : wine)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(showText ? 1 : 0)
                Spacer(minLength: 24)
                Button(action: onDone) {
                    Text("Continue").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(dark ? wine : Color.white)
                        .frame(maxWidth: 360).frame(height: 52)
                        .background(Capsule().fill(dark ? Color.white : wine))
                }
                .padding(.horizontal, 28).padding(.bottom, 28)
                .opacity(showText ? 1 : 0)
            }
        }
        .onAppear(perform: run)
    }

    // MARK: pieces

    private func badge(_ unlocked: Bool = true) -> some View {
        AchievementBadge(achievement: achievement, unlocked: unlocked, size: size)
    }
    /// A flat grey copy of the badge (its outline only).
    private var silhouette: some View {
        Color(hex: "#DDD8D5").mask(badge())
    }

    @ViewBuilder private var stage: some View {
        switch style {
        case .spin:
            ZStack {
                silhouette
                badge().opacity(color)
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        case .flip:
            badge()
                .overlay {
                    LinearGradient(colors: [.clear, Color.white.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: size * 0.45).rotationEffect(.degrees(20)).offset(x: shine * size)
                        .mask(badge())
                }
                .scaleEffect(scale)
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        case .pour:
            ZStack {
                silhouette
                badge().mask {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().frame(height: size * fill)
                    }
                    .frame(width: size, height: size)
                }
            }
            .scaleEffect(scale)
        case .burst:
            ZStack {
                particles
                badge().scaleEffect(scale)
            }
        case .stamp:
            ZStack {
                Circle().stroke(wine.opacity(0.45), lineWidth: 6).frame(width: size, height: size)
                    .scaleEffect(0.6 + ring).opacity(Double(1 - ring))
                badge().scaleEffect(scale).offset(y: drop)
            }
        }
    }

    private var rays: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule().fill(Color.white.opacity(0.08)).frame(width: 44, height: 760).offset(y: -380)
                    .rotationEffect(.degrees(Double(i) * 30 + angle))
            }
        }
        .scaleEffect(burst > 0 ? 1 : 0.2).opacity(Double(burst))
    }

    private var particles: some View {
        let colors: [Color] = [Color(hex: "#FBE7A1"), Color.white, Color(hex: "#E8708A")]
        return ZStack {
            ForEach(0..<28, id: \.self) { i in
                let a = Double(i) / 28 * 2 * Double.pi
                let r = CGFloat(120 + (i % 4) * 26)
                Circle().fill(colors[i % 3])
                    .frame(width: CGFloat(6 + (i % 3) * 3), height: CGFloat(6 + (i % 3) * 3))
                    .offset(x: CGFloat(cos(a)) * r * burst, y: CGFloat(sin(a)) * r * burst + 40 * burst * burst)
                    .opacity(Double(1 - burst))
            }
        }
    }

    // MARK: motion

    private func after(_ s: Double, _ f: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: f) }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.5)) { showText = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func run() {
        switch style {
        case .spin:
            withAnimation(.easeInOut(duration: 3.0)) { angle = 1080 }
            withAnimation(.easeIn(duration: 2.4).delay(0.5)) { color = 1 }
            after(0.4) { withAnimation(.easeOut(duration: 0.6)) { showText = true } }
            after(3.1) { reveal() }
        case .flip:
            withAnimation(.spring(response: 0.9, dampingFraction: 0.65)) { angle = 0; scale = 1 }
            withAnimation(.easeInOut(duration: 1.1).delay(0.8)) { shine = 1.2 }
            after(1.2) { reveal() }
        case .pour:
            withAnimation(.easeInOut(duration: 2.2)) { fill = 1 }
            after(2.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { scale = 1.12 }
                after(0.25) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1 } }
                reveal()
            }
        case .burst:
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) { scale = 1 }
            withAnimation(.easeOut(duration: 1.8).delay(0.2)) { burst = 1 }
            withAnimation(.linear(duration: 8)) { angle = 120 }
            after(0.8) { reveal() }
        case .stamp:
            withAnimation(.easeIn(duration: 0.45)) { drop = 0; scale = 1 }
            after(0.45) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.easeOut(duration: 0.9)) { ring = 1 }
                reveal()
            }
        }
    }
}

/// Shows badge announcements in a window of their own, above everything (lessons, sheets, maps), one after another.
@MainActor final class BadgeCelebration {
    static let shared = BadgeCelebration()
    private struct Item { let achievement: Achievement; let date: Date?; let style: BadgeStyle }
    private var queue: [Item] = []
    private var window: UIWindow?
    private static var isTesting: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    /// New badges: announced with the style chosen for the app.
    func announce(_ list: [Achievement], dates: [String: Date]) {
        guard !Self.isTesting else { return }
        for a in list { queue.append(Item(achievement: a, date: dates[a.id] ?? Date(), style: BadgeStyle.active)) }
        showNext()
    }

    /// Shows one badge again (a tap on it in the profile, or a try-out in TestFlight).
    func play(_ a: Achievement, date: Date?, style: BadgeStyle = BadgeStyle.active) {
        guard !Self.isTesting else { return }
        queue.append(Item(achievement: a, date: date, style: style))
        showNext()
    }

    private func showNext() {
        guard window == nil, !queue.isEmpty else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        let item = queue.removeFirst()
        let w = UIWindow(windowScene: scene)
        w.windowLevel = UIWindow.Level.alert + 1
        w.backgroundColor = .clear
        let page = BadgeAnnouncePage(achievement: item.achievement, date: item.date, style: item.style) { [weak self] in self?.finish() }
            .preferredColorScheme(.light)
        let host = UIHostingController(rootView: page)
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.alpha = 0
        w.isHidden = false
        UIView.animate(withDuration: 0.25) { w.alpha = 1 }
        window = w
    }

    private func finish() {
        guard let w = window else { return }
        UIView.animate(withDuration: 0.25, animations: { w.alpha = 0 }, completion: { [weak self] _ in
            w.isHidden = true
            self?.window = nil
            self?.showNext()
        })
    }
}
