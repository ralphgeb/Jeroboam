import Foundation
import UIKit
import Vision

/// What Claude returns about a photographed wine.
struct WineIdentity: Codable, Hashable {
    var found: Bool
    var name: String
    var producer: String
    var region: String
    var country: String
    var grapes: [String]
    var vintage: String
    var style: String
    var tastingNotes: [String]
    var palate: String
    var food: [String]
    var priceLow: Double
    var priceHigh: Double
    var currency: String
    var confidence: String
    var funFact: String
    var drinkWindow: String? = nil
    /// Typical blend, in percent, in the same order as `grapes` (nil when unknown).
    var grapePercent: [Int]? = nil

    enum CodingKeys: String, CodingKey {
        case found, name, producer, region, country, grapes, vintage, style, palate, food, currency, confidence
        case tastingNotes = "tasting_notes", priceLow = "price_low", priceHigh = "price_high", funFact = "fun_fact"
        case drinkWindow = "drink_window", grapePercent = "grape_percent"
    }

    static let empty = WineIdentity(found: false, name: "", producer: "", region: "", country: "", grapes: [], vintage: "",
                                    style: "red", tastingNotes: [], palate: "", food: [], priceLow: 0, priceHigh: 0,
                                    currency: "USD", confidence: "low", funFact: "")
}

struct RecognitionResult {
    var identity: WineIdentity
    var usedImage: Bool
    var inputTokens: Int
    var outputTokens: Int
    /// Claude Haiku 5.5: $0.10 / MTok input, $0.50 / MTok output (prompts ≤100K tokens).
    var costUSD: Double { Double(inputTokens) * 0.10 / 1_000_000 + Double(outputTokens) * 0.50 / 1_000_000 }
}

enum RecognizerError: LocalizedError {
    case noKey, network(String), refused, badResponse
    var errorDescription: String? {
        switch self {
        case .noKey: return "Wine recognition isn't set up in this build."
        case .network(let m): return m
        case .refused: return "The wine couldn't be identified."
        case .badResponse: return "Unexpected response. Try again."
        }
    }
}

/// Two-step identification to keep cost low:
/// 1. On-device OCR (Apple Vision, free) → send only the label text to Claude Haiku 5.5.
/// 2. Only if the text is too thin or the answer has low confidence → send a small JPEG of the photo.
enum WineRecognizer {
    static let model = "claude-haiku-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static var apiKey: String? {
        let k = (Bundle.main.object(forInfoDictionaryKey: "JeroAPIKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return k.isEmpty || k.hasPrefix("$(") ? nil : k
    }

    static var isAvailable: Bool { apiKey != nil }

    // MARK: OCR

    static func readText(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = false
            req.minimumTextHeight = 0.015
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
            do { try handler.perform([req]) } catch { return [] }
            let obs = req.results ?? []
            // biggest text first (names and appellations are usually large)
            return obs.sorted { $0.boundingBox.height > $1.boundingBox.height }
                .compactMap { $0.topCandidates(1).first?.string }
        }.value
    }

    static func usefulText(_ lines: [String]) -> String? {
        let joined = lines.prefix(40).joined(separator: "\n")
        let letters = joined.filter { $0.isLetter }.count
        return letters >= 12 ? joined : nil
    }

    // MARK: Identify

    /// A wine seen before comes straight from the phone's own database (WineDB): no network, no cost.
    static func identify(image: UIImage) async throws -> RecognitionResult {
        let sig = WineDB.signature(await readText(image))
        if let sig, let hit = WineDB.shared.entry(forSignature: sig) {
            return RecognitionResult(identity: hit.identity, usedImage: false, inputTokens: 0, outputTokens: 0)
        }
        // someone else may have scanned this label already: their result is kept online, so this scan costs nothing
        if let sig, let w = await PriceCloud.wine(sig: sig) {
            WineDB.shared.save(w, signature: sig)
            return RecognitionResult(identity: w, usedImage: false, inputTokens: 0, outputTokens: 0)
        }
        var r = try await identifyFresh(image: image)
        r.identity = tidy(r.identity)
        WineDB.shared.save(r.identity, signature: sig)
        PriceCloud.shareWine(r.identity, sig: sig)
        return r
    }

    /// "Château Batailley 2021" with vintage 2021 would show the year twice: keep it out of the name.
    static func tidy(_ w: WineIdentity) -> WineIdentity {
        var w = w
        let v = w.vintage.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty, w.name.hasSuffix(" " + v) { w.name = String(w.name.dropLast(v.count + 1)).trimmingCharacters(in: .whitespaces) }
        return w
    }

    private static func identifyFresh(image: UIImage) async throws -> RecognitionResult {
        guard let key = apiKey else { throw RecognizerError.noKey }
        let lines = await readText(image)
        if let text = usefulText(lines) {
            var r = try await call(key: key, content: [["type": "text", "text": "Text read from the wine label (OCR, may contain errors):\n\n" + text]])
            // Text alone is enough only for a confident, named answer; otherwise look at the photo too
            // (script or curved labels such as López de Heredia often defeat OCR).
            if r.identity.found && !r.identity.name.isEmpty && r.identity.confidence == "high" { return r }
            // fall back to the image, adding the cost of the first call
            if let jpeg = small(image) {
                var r2 = try await call(key: key, content: imageContent(jpeg, extra: "OCR text, for reference:\n" + text))
                r2.inputTokens += r.inputTokens
                r2.outputTokens += r.outputTokens
                r2.usedImage = true
                return (r2.identity.found && !r2.identity.name.isEmpty) || !r.identity.found ? r2 : r
            }
            r.usedImage = false
            return r
        }
        guard let jpeg = small(image) else { throw RecognizerError.badResponse }
        var r = try await call(key: key, content: imageContent(jpeg, extra: nil))
        r.usedImage = true
        return r
    }

    static func identify(text: String) async throws -> RecognitionResult {
        guard let key = apiKey else { throw RecognizerError.noKey }
        var r = try await call(key: key, content: [["type": "text", "text": "The user typed this wine: " + text]])
        r.identity = tidy(r.identity)
        WineDB.shared.save(r.identity)
        return r
    }

    private static func imageContent(_ jpeg: Data, extra: String?) -> [[String: Any]] {
        var c: [[String: Any]] = [["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]]]
        c.append(["type": "text", "text": "Identify the wine in this photo." + (extra.map { "\n\n" + $0 } ?? "")])
        return c
    }

    /// Downscale so the image costs roughly 1,000–1,500 input tokens.
    private static func small(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1400
        let s = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return img.jpegData(compressionQuality: 0.72)
    }

    private static let system = """
    You identify wines from label text or label photos for a wine-learning journal app. \
    Return your best identification. Read the producer and wine name carefully, including script, cursive or curved lettering \
    (for example "López de Heredia Viña Tondonia"). If you can name the producer or the wine, set found=true and give your best guess, \
    lowering confidence when unsure. Only if you cannot name it at all, set found=false and fill what you can (for example the region or grape). \
    tasting_notes: 4-6 short aroma/flavor descriptors typical of this wine (e.g. "Black cherry", "Vanilla"). \
    palate: one sentence on structure (sweetness, acidity, tannin, body). \
    price_low/price_high: typical current retail price range for one 750 ml bottle in US dollars, as an estimate from your knowledge (0 if unknown). \
    region: always name the wine region or appellation (for example Mendoza, Pauillac, Rioja), working it out from the producer and wine when the label does not print it.     style: one of red, white, rose, sparkling, fortified, sweet, orange. confidence: high, medium or low. \
    fun_fact: one short, accurate sentence that teaches something about this wine, its region or grape. \
    drink_window: when to drink it, e.g. "Now–2030" or "Drink now". \
    grape_percent: the usual blend in whole percent, in the same order as grapes, adding up to 100 (a single-variety wine is [100]). Keep every field concise.
    """

    private static var schema: [String: Any] {
        let str: [String: Any] = ["type": "string"]
        let strArr: [String: Any] = ["type": "array", "items": ["type": "string"]]
        let num: [String: Any] = ["type": "number"]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["found", "name", "producer", "region", "country", "grapes", "vintage", "style", "tasting_notes",
                         "palate", "food", "price_low", "price_high", "currency", "confidence", "fun_fact", "drink_window"],
            "properties": [
                "found": ["type": "boolean"], "name": str, "producer": str, "region": str, "country": str, "grapes": strArr,
                "vintage": str,
                "style": ["type": "string", "enum": ["red", "white", "rose", "sparkling", "fortified", "sweet", "orange"]],
                "tasting_notes": strArr, "palate": str, "food": strArr, "price_low": num, "price_high": num, "currency": str,
                "grape_percent": ["type": "array", "items": ["type": "integer"]],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]], "fun_fact": str, "drink_window": str
            ]
        ]
    }

    private static func call(key: String, content: [[String: Any]]) async throws -> RecognitionResult {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "system": system,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": content]]
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RecognizerError.badResponse }
        if status != 200 {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Request failed (\(status))."
            throw RecognizerError.network(status == 429 ? "Too many requests. Try again in a moment." : msg)
        }
        if (json["stop_reason"] as? String) == "refusal" { throw RecognizerError.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let tdata = text.data(using: .utf8) else { throw RecognizerError.badResponse }
        let identity = try JSONDecoder().decode(WineIdentity.self, from: tdata)
        let usage = json["usage"] as? [String: Any] ?? [:]
        return RecognitionResult(identity: identity, usedImage: false,
                                 inputTokens: usage["input_tokens"] as? Int ?? 0, outputTokens: usage["output_tokens"] as? Int ?? 0)
    }
}

// MARK: - Average price (web search on Wine-Searcher / CellarTracker)

/// A bottle price, either looked up on the web or estimated by the model.
struct PriceInfo: Codable, Hashable {
    var average: Double
    var low: Double
    var high: Double
    var currency: String
    var source: String          // "Wine-Searcher", "CellarTracker" or "Estimate"
    var url: String?
    var checked: Date = Date()

    var isEstimate: Bool { source == "Estimate" }

    static func estimate(from w: WineIdentity) -> PriceInfo? {
        guard w.priceHigh > 0 else { return nil }
        let avg = w.priceLow > 0 ? (w.priceLow + w.priceHigh) / 2 : w.priceHigh
        return PriceInfo(average: avg, low: w.priceLow, high: w.priceHigh, currency: w.currency.isEmpty ? "USD" : w.currency, source: "Estimate")
    }

    /// In the currency chosen in Settings (the price itself stays in the currency it was found in).
    func format(_ v: Double) -> String { Currency.format(v, from: currency) }
    var averageText: String { format(average) }
}

extension WineRecognizer {
    /// Web search: $10 per 1,000 searches (pricing at time of writing; check current rates).
    static let searchUSD = 0.01

    /// Looks up the average retail price for one bottle on Wine-Searcher (or CellarTracker),
    /// using Claude's web search tool limited to those sites. Falls back to the model's estimate.
    /// Live price lookups are off for now: the app shows Claude's estimate from the identification (no extra cost).
    static let livePrices = false

    /// Cheapest first: our own database, the Great wines list, the model's estimate from the identification, and only then
    /// one tiny question to Haiku (no web search, a fraction of a cent). Whatever is found is kept in the database.
    static func averagePrice(for w: WineIdentity) async -> (PriceInfo?, Double) {
        // 1. this phone's own database, then the shared one online (a price anyone has already found)
        // (prices saved by older builds as 'Average of N shops' are looked up again: the list now gives the cheapest shop)
        if let p = WineDB.shared.entry(for: w)?.price, !p.source.hasPrefix("Average of") { return (p, 0) }
        // 2. the shop price list (about 70,000 wines, with the cheapest shop's link) comes first, then the shared list online
        // (a price someone's phone had to search for), then the Great wines list, then the model's own estimate
        var found: PriceInfo? = nil
        var cost = 0.0
        let shop = await Task.detached(priority: .userInitiated) { PriceBook.shared.price(for: w) }.value
        if let p = shop { found = p }
        else if let p = await PriceCloud.price(for: w) { WineDB.shared.save(w, price: p); return (p, 0) }
        else if let p = WineDB.greatPrice(for: w) { found = p }
        else if !livePrices {
            if let p = PriceInfo.estimate(from: w) { found = p }
            else { let (p, c) = await quickEstimate(for: w); found = p; cost = c }
        } else {
            let (p, c) = await livePrice(for: w); found = p; cost = c
        }
        // 3. whatever was found goes into both databases, so nobody has to look for it again
        if let p = found { WineDB.shared.save(w, price: p); PriceCloud.share(w, price: p) }
        return (found, cost)
    }

    /// One short question, no tools: about $0.0002.
    private static func quickEstimate(for w: WineIdentity) async -> (PriceInfo?, Double) {
        guard let key = apiKey, !w.name.isEmpty else { return (nil, 0) }
        let wine = [w.producer, w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")
        let body: [String: Any] = [
            "model": model, "max_tokens": 120,
            "messages": [["role": "user", "content": "Typical current retail price in US dollars of one 750 ml bottle of \(wine)\(w.region.isEmpty ? "" : " (" + w.region + ")"). Reply with only JSON: {\"low\": number, \"average\": number, \"high\": number}. Use your best estimate; never 0."]]
        ]
        do {
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"; req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (nil, 0) }
            let usage = json["usage"] as? [String: Any] ?? [:]
            let cost = Double(usage["input_tokens"] as? Int ?? 0) * 0.10 / 1_000_000 + Double(usage["output_tokens"] as? Int ?? 0) * 0.50 / 1_000_000
            let text = (json["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
            guard let o = text.firstIndex(of: "{"), let c = text.lastIndex(of: "}"), o < c,
                  let obj = try? JSONSerialization.jsonObject(with: Data(text[o...c].utf8)) as? [String: Any] else { return (nil, cost) }
            func num(_ k: String) -> Double { (obj[k] as? NSNumber)?.doubleValue ?? 0 }
            let avg = num("average")
            guard avg > 0 else { return (nil, cost) }
            return (PriceInfo(average: avg, low: num("low") > 0 ? num("low") : avg * 0.8, high: num("high") > 0 ? num("high") : avg * 1.25, currency: "USD", source: "Estimate"), cost)
        } catch { return (nil, 0) }
    }

    private static func livePrice(for w: WineIdentity) async -> (PriceInfo?, Double) {
        guard let key = apiKey, !w.name.isEmpty else { return (PriceInfo.estimate(from: w), 0) }
        let wine = [w.producer, w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")
        let prompt = """
        Find the current average retail price of one 750 ml bottle of this wine: \(wine)\(w.region.isEmpty ? "" : " (" + w.region + ")").
        Prefer Wine-Searcher's "Avg Price (ex-tax)"; if Wine-Searcher has nothing, use CellarTracker's community valuation.
        Use the exact vintage if listed, otherwise the wine across vintages.
        Reply with only one JSON object and nothing else:
        {"average": number, "low": number, "high": number, "currency": "USD", "source": "Wine-Searcher" or "CellarTracker", "url": "page used"}
        Use 0 for numbers you could not find.
        """
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
            "tools": [["type": "web_search_20250305", "name": "web_search", "max_uses": 2,
                       "allowed_domains": ["wine-searcher.com", "cellartracker.com"]]],
            "messages": [["role": "user", "content": prompt]]
        ]
        do {
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (PriceInfo.estimate(from: w), 0) }
            let usage = json["usage"] as? [String: Any] ?? [:]
            let searches = ((usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int) ?? 0
            let cost = Double(usage["input_tokens"] as? Int ?? 0) * 0.10 / 1_000_000
                + Double(usage["output_tokens"] as? Int ?? 0) * 0.50 / 1_000_000
                + Double(searches) * searchUSD
            if (json["stop_reason"] as? String) == "refusal" { return (PriceInfo.estimate(from: w), cost) }
            let text = (json["content"] as? [[String: Any]] ?? [])
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
            guard let open = text.lastIndex(of: "{"), let close = text.lastIndex(of: "}"), open < close,
                  let obj = try? JSONSerialization.jsonObject(with: Data(text[open...close].utf8)) as? [String: Any] else {
                return (PriceInfo.estimate(from: w), cost)
            }
            func num(_ k: String) -> Double { (obj[k] as? NSNumber)?.doubleValue ?? 0 }
            let avg = num("average")
            guard avg > 0 else { return (PriceInfo.estimate(from: w), cost) }
            let source = (obj["source"] as? String) ?? "Wine-Searcher"
            return (PriceInfo(average: avg, low: num("low"), high: num("high"),
                              currency: (obj["currency"] as? String) ?? "USD",
                              source: source.localizedCaseInsensitiveContains("cellar") ? "CellarTracker" : "Wine-Searcher",
                              url: obj["url"] as? String), cost)
        } catch {
            return (PriceInfo.estimate(from: w), 0)
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
