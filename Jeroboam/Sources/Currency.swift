import Foundation

/// The currency prices are shown in: set in Settings, starting from the phone's own region (and following the country
/// you give under "About you"). Prices are kept in the currency they were found in and converted when shown.
enum Currency {
    private static let key = "jero.currency"

    static var regionDefault: String { Locale.current.currency?.identifier ?? "USD" }

    static var code: String {
        get { UserDefaults.standard.string(forKey: key) ?? regionDefault }
        set { UserDefaults.standard.set(newValue, forKey: key); UserDefaults.standard.set(true, forKey: key + ".chosen") }
    }

    /// The currency of a country (by the name the country picker uses), if it has one.
    static func forCountry(named name: String) -> String? {
        for r in Locale.Region.isoRegions where r.subRegions.isEmpty && r.identifier.count == 2 {
            if Locale.current.localizedString(forRegionCode: r.identifier) == name {
                return Locale(identifier: "und_" + r.identifier).currency?.identifier
            }
        }
        return nil
    }

    /// The ones offered in Settings.
    static let choices = ["USD", "EUR", "GBP", "CHF", "CAD", "AUD", "NZD", "JPY", "CNY", "HKD", "SGD", "INR", "AED", "SEK", "NOK", "DKK",
                          "PLN", "CZK", "HUF", "TRY", "ZAR", "BRL", "MXN", "ARS", "CLP", "ILS", "KRW", "THB"]

    // MARK: rates (units of currency per 1 US dollar)

    private static let fallback: [String: Double] = [
        "USD": 1, "EUR": 0.91, "GBP": 0.762, "CHF": 0.88, "CAD": 1.40, "AUD": 1.55, "NZD": 1.68, "JPY": 150, "CNY": 7.2, "HKD": 7.8,
        "SGD": 1.35, "INR": 83, "AED": 3.67, "SEK": 10.5, "NOK": 10.8, "DKK": 6.8, "PLN": 4.0, "CZK": 23, "HUF": 360, "TRY": 33,
        "ZAR": 18.5, "BRL": 5.2, "MXN": 18, "ARS": 900, "CLP": 950, "ILS": 3.7, "KRW": 1330, "THB": 35,
    ]
    private static var live: [String: Double] = {
        (UserDefaults.standard.dictionary(forKey: "jero.rates") as? [String: Double]) ?? [:]
    }()

    static func rate(_ c: String) -> Double? { live[c] ?? fallback[c] }

    /// Fresh rates once a day (European Central Bank, through frankfurter.dev); the built-in ones are used until then.
    static func refresh() async {
        let last = UserDefaults.standard.double(forKey: "jero.rates.date")
        guard Date().timeIntervalSince1970 - last > 86_400, let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD") else { return }
        guard let (data, resp) = try? await URLSession.shared.data(from: url), (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], var rates = o["rates"] as? [String: Double] else { return }
        rates["USD"] = 1
        live = rates
        UserDefaults.standard.set(rates, forKey: "jero.rates")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "jero.rates.date")
    }

    static func convert(_ v: Double, from: String, to: String) -> Double {
        let f = from.isEmpty ? "USD" : from
        guard f != to, let rf = rate(f), let rt = rate(to), rf > 0 else { return v }
        return v / rf * rt
    }

    /// A price in the chosen currency.
    static func format(_ v: Double, from: String) -> String {
        let to = code
        let n = NumberFormatter()
        n.numberStyle = .currency
        n.currencyCode = (rate(to) != nil || to == from) ? to : "USD"
        n.maximumFractionDigits = 0
        let shown = (rate(to) != nil) ? convert(v, from: from, to: to) : convert(v, from: from, to: "USD")
        return n.string(from: NSNumber(value: shown)) ?? "\(Int(shown))"
    }
}
