import LocalAuthentication
import StoreKit
import SwiftUI

/// Where this copy of Jero came from. The same build goes to TestFlight and the App Store, so it's
/// worked out at run time: a TestFlight install carries a sandbox receipt, an App Store one doesn't.
enum Distribution {
    static let isTestFlight: Bool = {
        #if DEBUG || targetEnvironment(simulator)
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()
}

/// Jero Plus: every level but your starting one (and their guidebooks), every country in the atlas, unlimited atlas cards
/// and the Journal. Level 1, Practice, France and Italy stay free.
///
/// Buying goes through the App Store (StoreKit 2, `com.ralphgeb.jero.plus.monthly`) once the subscription
/// exists in App Store Connect; until then a test checkout that follows Apple's sheet (Face ID, nothing charged).
@Observable final class Plus {
    static let shared = Plus()
    static let productID = "com.ralphgeb.jero.plus.monthly"
    static let key = "jero.plus.active"
    static let storeKey = "jero.plus.store"
    /// Atlas sections free users can open a few cards in.
    static let freeOpens = 5
    static let freeCountries: Set<String> = ["France", "Italy"]

    private(set) var active: Bool
    var product: Product?

    private init() {
        #if targetEnvironment(simulator)
        // the simulator screenshot run shows everything, unless a screen asks to see the free version
        let args = ProcessInfo.processInfo.arguments
        let free = args.contains("-free") || ["freelearn", "journallocked", "freeregions", "paywall"].contains(args.firstIndex(of: "-screen").map { args[min($0 + 1, args.count - 1)] } ?? "")
        active = !free || UserDefaults.standard.bool(forKey: Self.key)
        #else
        active = UserDefaults.standard.bool(forKey: Self.key)
        #endif
    }

    /// "$0.99" / "£0.99", or the App Store's own price once the product loads.
    var price: String {
        if let product { return product.displayPrice }
        return Locale.current.currency?.identifier == "GBP" ? "£0.99" : "$0.99"
    }

    var locked: Bool { !active }

    func activate(fromStore: Bool) {
        let d = UserDefaults.standard
        d.set(fromStore, forKey: Self.storeKey)
        d.set(true, forKey: Self.key)
        active = true
    }

    /// TestFlight only: back to the free version.
    func reset() {
        UserDefaults.standard.set(false, forKey: Self.key)
        UserDefaults.standard.set(false, forKey: Self.storeKey)
        AtlasQuota.reset()
        active = false
    }

    // MARK: App Store

    func loadProduct() async {
        if product == nil { product = try? await Product.products(for: [Self.productID]).first }
    }

    enum Outcome: Equatable { case bought, cancelled, pending, failed(String) }

    func buy(_ product: Product) async -> Outcome {
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result else { return .failed("The App Store couldn\u{2019}t confirm the purchase.") }
                await t.finish()
                activate(fromStore: true)
                return .bought
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// What the App Store says you own: an App Store subscription that ended (or was refunded) ends Plus;
    /// a test-checkout one is left alone.
    func refresh() async {
        #if targetEnvironment(simulator)
        return
        #else
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        let d = UserDefaults.standard
        if owned {
            if !active || !d.bool(forKey: Self.storeKey) { activate(fromStore: true) }
        } else if d.bool(forKey: Self.storeKey) {
            d.set(false, forKey: Self.storeKey); d.set(false, forKey: Self.key)
            active = false
        }
        #endif
    }

    /// Renewals, refunds and purchases made elsewhere while Jero runs.
    func listen() async {
        for await result in StoreKit.Transaction.updates {
            if case .verified(let t) = result { await t.finish() }
            await refresh()
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        await refresh()
        return active
    }

    // MARK: Confirming it's you (test checkout)

    static func confirmOwner(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    static var biometrySymbol: (String, String) {
        let c = LAContext(); var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return ("lock.fill", "Confirming") }
        switch c.biometryType {
        case .faceID: return ("faceid", "Face ID")
        case .touchID: return ("touchid", "Touch ID")
        case .opticID: return ("opticid", "Optic ID")
        default: return ("lock.fill", "Confirming")
        }
    }
}

/// Free atlas cards: five per section (grapes, wines, styles…), counted once per card.
enum AtlasQuota {
    private static func key(_ section: String) -> String { "jero.quota." + section }
    static func opened(_ section: String) -> [String] { UserDefaults.standard.stringArray(forKey: key(section)) ?? [] }
    static func left(_ section: String) -> Int { max(0, Plus.freeOpens - opened(section).count) }
    /// True when the card may open (Plus, already opened, or a free open left, which it then uses).
    static func use(_ section: String, _ id: String) -> Bool {
        if Plus.shared.active { return true }
        var o = opened(section)
        if o.contains(id) { return true }
        guard o.count < Plus.freeOpens else { return false }
        o.append(id)
        UserDefaults.standard.set(o, forKey: key(section))
        return true
    }
    static func canOpen(_ section: String, _ id: String) -> Bool {
        Plus.shared.active || opened(section).contains(id) || opened(section).count < Plus.freeOpens
    }
    static func reset() {
        for (k, _) in UserDefaults.standard.dictionaryRepresentation() where k.hasPrefix("jero.quota.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}

/// Opens the Jero Plus sheet from anywhere. Every screen layer (the root, sheets, full-screen covers) hosts it with
/// `.plusSheetHost()`; the sheet opens on the topmost one, since a covered layer can't present.
@Observable final class PaywallPresenter {
    static let shared = PaywallPresenter()
    var reason: String? = nil
    var target: UUID? = nil
    @ObservationIgnored var hosts: [UUID] = []
    func show(_ reason: String) { self.reason = reason; target = hosts.last }
}

private struct PlusSheetHost: ViewModifier {
    @State private var id = UUID()
    func body(content: Content) -> some View {
        let p = PaywallPresenter.shared
        let ch = CoverHost.shared
        // on the Duo (two panes) the offer opens on the right half, with the page still visible on the left
        let inPane = ch.railActive && ch.pageWidth >= AdaptiveLayout.twoPaneThreshold
        content
            .onAppear { if !p.hosts.contains(id) { p.hosts.append(id) } }
            .onDisappear { p.hosts.removeAll { $0 == id } }
            .sheet(isPresented: Binding(get: { !inPane && p.target == id }, set: { if !$0 { p.target = nil } })) {
                PlusSheet(reason: p.reason)
            }
            .onChange(of: p.target) { _, t in
                if inPane, t == id {
                    ch.paywall = AnyView(
                        HStack(spacing: 0) {
                            Color.black.opacity(0.22).ignoresSafeArea().onTapGesture { p.target = nil }
                            PlusSheet(reason: p.reason)
                                .environment(\.coverClose, { p.target = nil })
                                .frame(width: ch.pageWidth / 2)
                                .background(Palette.paper.ignoresSafeArea())
                                .overlay(alignment: .leading) { Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea() }
                        }
                    )
                } else if t == nil {
                    ch.paywall = nil
                }
            }
    }
}

extension View {
    func plusSheetHost() -> some View { modifier(PlusSheetHost()) }
}

// MARK: - Badges and locks

/// "Jero Plus" on a frosted pill with a Bordeaux lock.
struct LockBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Circle().fill(Palette.bordeaux))
            Text("Jero Plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
        }
        .padding(.leading, 6).padding(.trailing, 12)
        .frame(height: 32)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

/// A small lock for list rows and tiles.
struct LockDot: View {
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: "lock.fill").font(.system(size: size * 0.48, weight: .bold)).foregroundStyle(.white)
            .frame(width: size, height: size).background(Circle().fill(Palette.bordeaux))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}

/// "3 of 5 free" in the top-right of an atlas section.
struct QuotaPill: View {
    let section: String
    var body: some View {
        if !Plus.shared.active {
            let left = AtlasQuota.left(section)
            Button { PaywallPresenter.shared.show("Open every card in the atlas with Jero Plus.") } label: {
                HStack(spacing: 5) {
                    Image(systemName: left > 0 ? "sparkles" : "lock.fill").font(.system(size: 10, weight: .bold))
                    Text(left > 0 ? "\(left) of \(Plus.freeOpens) free" : "Jero Plus").font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(left > 0 ? Palette.wine : .white)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Capsule().fill(left > 0 ? Palette.wineSoft : Palette.bordeaux))
            }
            .buttonStyle(.plain)
        }
    }
}

/// The pill in the navigation bar, without the system's extra glass blob around it (iOS 26 wraps every bar item in one).
struct QuotaToolbar: ToolbarContent {
    let section: String
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: section) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { QuotaPill(section: section) }
        }
    }
}

/// A locked panel: the content still shows, faded, with the Bordeaux lock and a line about what Plus adds.
struct PlusCallout: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.bordeaux).frame(width: 52, height: 52)
                    .shadow(color: Palette.bordeaux.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "lock.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(message).font(.system(size: 14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Unlock with Jero Plus")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).frame(height: 40)
                .background(Capsule().fill(Palette.bordeaux))
                .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}

// MARK: - The Jero Plus sheet

struct PlusSheet: View {
    var reason: String? = nil
    @Environment(\.dismiss) private var dismissEnv
    @Environment(\.coverClose) private var coverClose
    /// Closes the sheet, or the right-hand panel on the Duo.
    private func dismiss() { if let c = coverClose { c() } else { dismissEnv() } }
    @State private var step = Step.offer
    @State private var showCheckout = false
    @State private var showPrivacy = false
    @State private var note: String?
    @State private var shimmer = false
    private var plus: Plus { Plus.shared }

    enum Step { case offer, paying, done }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if step == .done {
                    welcome.transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    offer.padding(.horizontal, 20).padding(.top, 22).transition(.opacity)
                }
            }
            .padding(.bottom, 14)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.height(590)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .animation(.smooth(duration: 0.35), value: step)
        .animation(.smooth(duration: 0.25), value: note)
        .sensoryFeedback(.success, trigger: step == .done)
        .interactiveDismissDisabled(step == .paying)
        .task { await plus.loadProduct() }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                JeroPrivacyView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPrivacy = false } } }
            }
        }
        .sheet(isPresented: $showCheckout) {
            TestCheckoutSheet { bought in
                if bought { welcomeThenClose(fromStore: false) } else { step = .offer }
            }
        }
    }

    private var offer: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(reason ?? "Unlock the whole cellar.")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    Text("Jero").frame(width: 62)
                    Text("Plus").foregroundStyle(Palette.wine).frame(width: 62)
                }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, 14).frame(height: 34)
                row("Your starting level", free: true, plus: true)
                row("Other levels and guidebooks", free: false, plus: true)
                row("Practice quizzes", free: true, plus: true)
                row("Atlas: France and Italy", free: true, plus: true)
                row("Atlas: all 15 countries", free: false, plus: true)
                row("Journal, cellar and blind tastings", free: false, plus: true)
                row("Great wines to try", free: false, plus: true)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))

            Button(action: subscribe) {
                ZStack {
                    if step == .paying { ProgressView().tint(.white) }
                    else { Text("Subscribe · \(plus.price)/month").font(.system(size: 16.5, weight: .semibold)) }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.bordeaux))
            }
            .buttonStyle(PressableStyle())
            .disabled(step == .paying)

            if let note {
                Text(note).font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
            }
            Text("Renews automatically until cancelled. Cancel any time in Settings › Apple Account › Subscriptions.")
                .font(.system(size: 11)).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Restore Purchases") { restore() }.disabled(step == .paying)
                Button("Privacy Policy") { showPrivacy = true }
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .buttonStyle(.plain)
        }
    }

    private func row(_ title: String, free: Bool, plus: Bool) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                Text(title).font(.system(size: 14.5)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
                mark(free).frame(width: 62)
                mark(plus).frame(width: 62)
            }
            .padding(.horizontal, 14).frame(height: 38)
        }
    }

    private func mark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark" : "minus").font(.system(size: 13, weight: .bold))
            .foregroundStyle(on ? Palette.wine : Palette.inkFaint)
    }

    private func subscribe() {
        note = nil
        step = .paying
        Task {
            await plus.loadProduct()
            guard let product = plus.product else { showCheckout = true; return }
            switch await plus.buy(product) {
            case .bought: welcomeThenClose(fromStore: true)
            case .cancelled: step = .offer
            case .pending: step = .offer; note = "Waiting for approval. Plus turns on as soon as it\u{2019}s approved."
            case .failed(let why): step = .offer; note = why
            }
        }
    }

    private func restore() {
        note = nil
        step = .paying
        Task {
            if await plus.restore() { welcomeThenClose(fromStore: true) }
            else { step = .offer; note = "No Jero Plus purchase found for this Apple Account." }
        }
    }

    private func welcomeThenClose(fromStore: Bool) {
        if !plus.active { plus.activate(fromStore: fromStore) }
        step = .done
        Task { try? await Task.sleep(for: .milliseconds(1900)); dismiss() }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            ZStack {
                Circle().fill(Palette.wineSoft).frame(width: 110, height: 110)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(Palette.wine)
                    .symbolEffect(.bounce, value: step == .done)
            }
            Text("Welcome to Jero Plus").font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
            Text("You're subscribed. Every level, map, wine and your journal are now open. Santé!")
                .font(.system(size: 16)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .padding(.horizontal, 30).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                welcomePoint("Levels 1 to 3 and every guidebook")
                welcomePoint("All 15 countries in the atlas")
                welcomePoint("Journal, cellar and blind tastings")
                welcomePoint("Great wines to try, with prices")
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            .padding(.horizontal, 20)
            Button("Start exploring") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
            Spacer(minLength: 10)
        }
        .frame(minHeight: 500)
    }

    private func welcomePoint(_ t: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.wine)
            Text(t).font(.system(size: 15)).foregroundStyle(Palette.ink)
        }
    }
}

/// The checkout used until the subscription is live in App Store Connect: Apple's purchase sheet step by step
/// (App Store, the app, the terms, Subscribe, Face ID, Done). It says Test where Apple's says Sandbox; nothing is charged.
struct TestCheckoutSheet: View {
    var onFinish: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var stage = Stage.ready
    @State private var finished = false
    @State private var allSet = false
    enum Stage { case ready, authenticating, purchasing, done }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("App Store").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Cancel") { finish(false) }.font(.system(size: 17)).disabled(stage != .ready)
            }
            .padding(.horizontal, 20).frame(height: 56)
            Divider()
            HStack(alignment: .top, spacing: 14) {
                Image("IconPreview").resizable().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14.5, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jero Plus").font(.system(size: 17, weight: .semibold))
                    Text("Jero").font(.system(size: 15)).foregroundStyle(.secondary)
                    Text("Subscription").font(.system(size: 15)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            Divider().padding(.leading, 20)
            VStack(alignment: .leading, spacing: 6) {
                Text("Starts today. \(Plus.shared.price)/month.").font(.system(size: 15, weight: .semibold))
                Text("Renews automatically every month until cancelled. Cancel at least a day before each renewal date in Settings › Apple Account › Subscriptions.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 14)
            Divider().padding(.leading, 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { Text("Account:").foregroundStyle(.secondary); Text("Test account") }.font(.system(size: 15))
                Text("[Environment: Test]").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 14)
            Spacer(minLength: 8)
            button.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .presentationDetents([.height(468)])
        .presentationCornerRadius(38)
        .interactiveDismissDisabled(stage != .ready)
        .animation(.smooth(duration: 0.25), value: stage)
        .alert("You\u{2019}re all set.", isPresented: $allSet) {
            Button("OK") { finish(true) }
        } message: { Text("Your purchase was successful.\n[Environment: Test]") }
        .onDisappear { if !finished { finished = true; onFinish(false) } }
    }

    @ViewBuilder private var button: some View {
        let bio = Plus.biometrySymbol
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(stage == .done ? Color(uiColor: .secondarySystemFill) : Color.blue)
            switch stage {
            case .ready: Text("Subscribe").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            case .authenticating:
                HStack(spacing: 8) { Image(systemName: bio.0).font(.system(size: 18)); Text(bio.1).font(.system(size: 17, weight: .semibold)) }
                    .foregroundStyle(.white)
            case .purchasing: ProgressView().tint(.white)
            case .done:
                HStack(spacing: 6) { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)); Text("Done").font(.system(size: 17, weight: .semibold)) }
                    .foregroundStyle(Color.blue)
            }
        }
        .frame(height: 50)
        .contentShape(Rectangle())
        .onTapGesture { if stage == .ready { subscribe() } }
    }

    private func subscribe() {
        stage = .authenticating
        Task {
            guard await Plus.confirmOwner(reason: "Subscribe to Jero Plus for \(Plus.shared.price) a month") else { stage = .ready; return }
            stage = .purchasing
            try? await Task.sleep(for: .milliseconds(1200))
            stage = .done
            try? await Task.sleep(for: .milliseconds(700))
            allSet = true
        }
    }

    private func finish(_ bought: Bool) {
        guard !finished else { return }
        finished = true
        onFinish(bought)
        dismiss()
    }
}

struct JeroPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Jero is a wine-learning app. Your progress, profile and journal are stored on your iPhone and, if you sign in with Apple, in your own iCloud.")
                section("Wine scans", "When you scan a label, the label text (and, if needed, a small copy of the photo) is sent to Anthropic's Claude to identify the wine. Nothing else is sent, and Jero keeps no servers of its own.")
                section("Jero Plus", "Subscriptions are bought and managed by Apple through the App Store. Jero only learns whether your subscription is active.")
                section("No tracking", "No ads, no analytics and no selling of data.")
                section("Contact", "Through the App Store page's support link.")
            }
            .font(.system(size: 15))
            .padding(20)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func section(_ t: String, _ x: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.system(size: 15, weight: .semibold))
            Text(x).foregroundStyle(.secondary)
        }
    }
}
