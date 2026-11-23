import SwiftUI

/// Wraps an atlas card. Free users: France is open, other countries need Jero Plus, and each atlas
/// section (grapes, wines, styles, great wines…) opens five cards for free. A locked card shows faded under
/// the Bordeaux lock and brings up the Jero Plus sheet.
struct PlusGate<Content: View>: View {
    var quota: String? = nil
    var id: String = ""
    var country: String? = nil
    var reason = "Open every card in the atlas with Jero Plus."
    @ViewBuilder let content: () -> Content
    @State private var granted: Bool? = nil

    private var countryLocked: Bool { country.map { !Plus.freeCountries.contains($0) } ?? false }

    var body: some View {
        let open = Plus.shared.active || (granted ?? false)
        Group {
            if open {
                content()
            } else {
                content()
                    .blur(radius: 6)
                    .saturation(0.6)
                    .opacity(0.55)
                    .allowsHitTesting(false)
                    .overlay {
                        PlusCallout(title: countryLocked ? "\(country ?? "This country") is in Jero Plus" : "Your free cards are used",
                                    message: countryLocked ? "France is free. Every other country, map and appellation comes with Jero Plus."
                                                           : "You opened \(Plus.freeOpens) cards here for free. Jero Plus opens them all.")
                            .onTapGesture { PaywallPresenter.shared.show(reason) }
                    }
            }
        }
        .onAppear {
            guard granted == nil else { return }
            if countryLocked { granted = false }
            else if let q = quota { granted = AtlasQuota.use(q, id) }
            else { granted = true }
            if granted == false && !Plus.shared.active { PaywallPresenter.shared.show(reason) }
        }
    }
}

extension Region {
    /// The country this region belongs to, for the free-country rule.
    var gateCountry: String { country }
}
