import Foundation

/// The free part of the wine check: the app fetches a few web pages itself (the shop page we already know, plus the first
/// search results) and cuts each one down to the sentences about grapes and taste. Claude then only reads that short text.
enum WebFacts {
    private static let skipHosts = ["facebook.", "instagram.", "youtube.", "pinterest.", "amazon.", "tripadvisor.", "twitter.", "x.com", "tiktok.", "reddit."]
    private static let keywords = ["grape", "variet", "cépage", "cepage", "uva ", "uvas", "blend", "made from", "made with", "tasting", "aroma", "nose", "palate", "flavo"]

    /// Up to about 4,500 characters of relevant text, each page labelled with its site. Empty when nothing useful was found.
    static func pages(for query: String, shopURL: String?) async -> String {
        var urls: [URL] = []
        if let s = shopURL, let u = URL(string: s), u.scheme?.hasPrefix("http") == true { urls.append(u) }
        urls += await searchResults(query + " grape variety")
        var seen = Set<String>()
        let list = urls.filter { seen.insert($0.absoluteString).inserted }.prefix(4)
        let found = await withTaskGroup(of: (Int, String, String).self) { group -> [(Int, String, String)] in
            for (i, u) in list.enumerated() { group.addTask { (i, u.host ?? "", await excerpt(of: u)) } }
            var r: [(Int, String, String)] = []
            for await x in group { r.append(x) }
            return r.sorted { $0.0 < $1.0 }
        }
        var out = ""
        for (_, host, text) in found where !text.isEmpty {
            if out.count > 3500 { break }
            out += "Source: \(host)\n\(text)\n\n"
        }
        return String(out.prefix(4500))
    }

    /// First few result links from DuckDuckGo's plain HTML page (no account, no fee).
    private static func searchResults(_ q: String) async -> [URL] {
        var c = URLComponents(string: "https://html.duckduckgo.com/html/")!
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = c.url, let html = await fetch(url, timeout: 6),
              let re = try? NSRegularExpression(pattern: "uddg=([^&\"']+)") else { return [] }
        var out: [URL] = []
        let ns = html as NSString
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            guard let raw = ns.substring(with: m.range(at: 1)).removingPercentEncoding, let u = URL(string: raw),
                  u.scheme?.hasPrefix("http") == true, let host = u.host?.lowercased(),
                  !skipHosts.contains(where: { host.contains($0) }), !raw.lowercased().hasSuffix(".pdf") else { continue }
            out.append(u)
            if out.count >= 4 { break }
        }
        return out
    }

    private static func fetch(_ url: URL, timeout: TimeInterval) async -> String? {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    /// The sentences of a page that talk about grapes and taste (empty when the page has none).
    private static func excerpt(of url: URL) async -> String {
        guard let html = await fetch(url, timeout: 6) else { return "" }
        let text = plain(html)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).map { $0.trimmingCharacters(in: .whitespaces) }
        var out: [String] = []
        var size = 0
        for s in sentences where s.count > 12 && s.count < 400 {
            let l = s.lowercased()
            guard keywords.contains(where: { l.contains($0) }) else { continue }
            out.append(s); size += s.count
            if size > 1400 { break }
        }
        return out.joined(separator: ". ")
    }

    private static func plain(_ html: String) -> String {
        var s = html
        for pattern in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<[^>]+>"] {
            s = s.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        for (a, b) in [("&amp;", "&"), ("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&eacute;", "é"), ("&egrave;", "è"), ("&ntilde;", "ñ"), ("&lt;", "<"), ("&gt;", ">")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        return s.replacingOccurrences(of: "[ \\t\\r]+", with: " ", options: .regularExpression)
    }
}
