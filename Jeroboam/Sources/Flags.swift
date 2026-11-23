import Foundation

/// Country name -> flag emoji, for the wine countries (and a globe for anything else).
enum Flag {
    private static let codes: [String: String] = [
        "france": "FR", "italy": "IT", "spain": "ES", "portugal": "PT", "germany": "DE", "austria": "AT", "hungary": "HU", "greece": "GR",
        "united states": "US", "usa": "US", "us": "US", "united states of america": "US", "chile": "CL", "argentina": "AR", "australia": "AU",
        "new zealand": "NZ", "south africa": "ZA", "lebanon": "LB", "england": "GB", "united kingdom": "GB", "uk": "GB", "wales": "GB",
        "scotland": "GB", "switzerland": "CH", "croatia": "HR", "slovenia": "SI", "romania": "RO", "bulgaria": "BG", "moldova": "MD",
        "georgia": "GE", "armenia": "AM", "turkey": "TR", "cyprus": "CY", "israel": "IL", "canada": "CA", "mexico": "MX", "brazil": "BR",
        "uruguay": "UY", "china": "CN", "japan": "JP", "india": "IN", "morocco": "MA", "tunisia": "TN", "czech republic": "CZ", "czechia": "CZ",
        "slovakia": "SK", "luxembourg": "LU", "belgium": "BE", "netherlands": "NL", "ukraine": "UA", "serbia": "RS", "north macedonia": "MK",
        "malta": "MT", "peru": "PE", "bolivia": "BO", "thailand": "TH", "russia": "RU", "denmark": "DK", "sweden": "SE", "norway": "NO",
    ]
    private static func key(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().trimmingCharacters(in: .whitespaces)
    }
    static func emoji(for country: String) -> String {
        guard let code = codes[key(country)] else { return "🌍" }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }
}
