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
    /// From the wine database when it is certainly this bottle: the critics' average score and the page that quotes it.
    var dbScore: Int? = nil
    var dbScoreLink: String? = nil
    /// Every critic's score ("Wine Advocate 96", "Jancis Robinson 17/20") and, in the same order, the shop page that quotes it.
    var dbCritics: [String]? = nil
    var dbCriticLinks: [String]? = nil
    var fromDatabase: Bool? = nil
    /// True once the grapes, region and notes were checked on the web (or came from the wine database).
    var checked: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case found, name, producer, region, country, grapes, vintage, style, palate, food, currency, confidence
        case tastingNotes = "tasting_notes", priceLow = "price_low", priceHigh = "price_high", funFact = "fun_fact"
        case drinkWindow = "drink_window", grapePercent = "grape_percent", dbScore = "db_score", dbScoreLink = "db_score_link", fromDatabase = "from_database"
        case dbCritics = "db_critics", dbCriticLinks = "db_critic_links"
        case checked
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
    /// The web check of a new wine (search fee plus tokens).
    var extraUSD: Double = 0
    /// True when today's allowance was used up before this new wine could be checked online: its grapes and notes are left out.
    var limited = false
    /// What is still to do after the bottle is on screen (`WineRecognizer.finish`): checking a wine the databases do not fully
    /// know. nil when the result is final.
    var pending: Pending? = nil
    enum Pending { case vet(sig: String?), fresh(sig: String?), typed }
    /// Claude Haiku 5.5: $0.10 / MTok input, $0.50 / MTok output (prompts ≤100K tokens).
    var costUSD: Double { Double(inputTokens) * 0.10 / 1_000_000 + Double(outputTokens) * 0.50 / 1_000_000 + extraUSD }
}

/// Every phone gets a small daily allowance for wines the databases don't know yet (those need a web check, which costs money).
/// Wines already in the phone's or the shared database are free and never count.
enum DailyBudget {
    static let limitUSD = 0.10
    private static let testKey = "jero.testLimit"
    /// TestFlight switch (Settings) to see what happens when the limit is reached.
    static var testLimit: Bool {
        get { UserDefaults.standard.bool(forKey: testKey) }
        set { UserDefaults.standard.set(newValue, forKey: testKey) }
    }
    private static var key: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return "jero.spend." + f.string(from: Date())
    }
    static var spent: Double { UserDefaults.standard.double(forKey: key) }
    static func add(_ c: Double) { if c > 0 { UserDefaults.standard.set(spent + c, forKey: key) } }
    /// The allowance for checking new wines on the web is used up (the TestFlight switch pretends it is).
    static var reached: Bool { testLimit || spent >= limitUSD }
    /// A safety stop far above the allowance: recognising wines is cheap, but not unlimited.
    static var hardStop: Bool { spent >= limitUSD * 5 }
}

enum RecognizerError: LocalizedError {
    case noKey, network(String), refused, badResponse, limit
    var errorDescription: String? {
        switch self {
        case .limit: return "You've reached today's limit for checking new wines. Wines Jero already knows still work. Their details open again tomorrow."
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

    /// Claude is reached through Jero's own server (backend/cloudflare, route /claude), which holds the Anthropic key: the key is
    /// not in the app. A build without the server (old setup, local testing) can still call Anthropic with a key in the build.
    static var isAvailable: Bool { PriceCloud.claudeRequest() != nil || apiKey != nil }

    static func claudeRequest(timeout: TimeInterval) -> URLRequest? {
        var req: URLRequest
        if let r = PriceCloud.claudeRequest() {
            req = r
        } else if let key = apiKey {
            req = URLRequest(url: endpoint)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
        } else {
            return nil
        }
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        return req
    }

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
    /// The whole job in one go (the bottle, then its check); the scan screens use `identifyFast` + `finish` to show the bottle sooner.
    static func identify(image: UIImage) async throws -> RecognitionResult {
        let r = try await identifyFast(image: image)
        let f = await finish(r)
        var out = f; out.inputTokens = r.inputTokens; out.outputTokens = r.outputTokens; out.usedImage = r.usedImage
        return out
    }

    /// Who the bottle is, as fast as possible: the phone's database, else the shared online list and Claude side by side
    /// (the list gets a short head start, since a hit there is free). The online check of a new wine is left to `finish`.
    static func identifyFast(image: UIImage) async throws -> RecognitionResult {
        let sig = WineDB.signature(await readText(image))
        if let sig, let hit = WineDB.shared.entry(forSignature: sig) {
            var r = RecognitionResult(identity: hit.identity, usedImage: false, inputTokens: 0, outputTokens: 0)
            if needsVet(hit.identity) { r.pending = .vet(sig: sig) }
            return r
        }
        // someone else may have scanned this label already: their result is kept online, so this scan costs nothing
        let cloud = Task { () -> WineIdentity? in
            guard let sig else { return nil }
            return await PriceCloud.wine(sig: sig)
        }
        if let w = await firstOf(cloud, within: 0.8) {
            return cloudResult(w, sig: sig)
        }
        if DailyBudget.hardStop {
            if let w = await cloud.value { return cloudResult(w, sig: sig) }
            throw RecognizerError.limit
        }
        // the list is slow today: ask Claude now, and take whichever answers first
        let claude = Task { try await identifyFresh(image: image) }
        let winner = await withTaskGroup(of: Answer.self) { group -> Answer in
            group.addTask { if let w = await cloud.value { return .cloud(w) }; return .nothing }
            group.addTask { do { return .claude(try await claude.value) } catch { return .failed(error) } }
            var last: Answer = .nothing
            for await a in group {
                switch a {
                case .cloud, .claude: group.cancelAll(); return a
                case .failed: last = a                           // Claude's error is what to report
                case .nothing: break
                }
            }
            return last
        }
        switch winner {
        case .cloud(let w):
            claude.cancel()
            return cloudResult(w, sig: sig)
        case .claude(var r):
            DailyBudget.add(r.costUSD)
            r.identity = tidy(r.identity)
            r.identity = await Task.detached(priority: .userInitiated) { PriceBook.shared.overlay(r.identity) }.value
            r.pending = .fresh(sig: sig)
            return r
        case .failed(let e): throw e
        case .nothing: throw RecognizerError.badResponse
        }
    }

    private enum Answer { case cloud(WineIdentity), claude(RecognitionResult), failed(Error), nothing }

    private static func cloudResult(_ w: WineIdentity, sig: String?) -> RecognitionResult {
        WineDB.shared.save(w, signature: sig)
        var r = RecognitionResult(identity: w, usedImage: false, inputTokens: 0, outputTokens: 0)
        if needsVet(w) { r.pending = .vet(sig: sig) }
        return r
    }

    /// The task's answer if it comes within `seconds`, else nil (the task keeps running).
    private static func firstOf(_ task: Task<WineIdentity?, Never>, within seconds: Double) async -> WineIdentity? {
        await withTaskGroup(of: WineIdentity??.self) { group in
            group.addTask { .some(await task.value) }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9)); return .none }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }

    private static func needsVet(_ w: WineIdentity) -> Bool { w.found && !w.name.isEmpty && w.fromDatabase != true && w.checked != true }

    /// The rest of the job, while the bottle is already on screen: for a wine the databases do not fully know, look it up by
    /// name (free) or check it online. Returns the final result; its tokens are 0 and `extraUSD` is what the check cost.
    static func finish(_ r0: RecognitionResult) async -> RecognitionResult {
        guard let p = r0.pending else { return r0 }
        var r = RecognitionResult(identity: r0.identity, usedImage: r0.usedImage, inputTokens: 0, outputTokens: 0)
        switch p {
        case .vet(let sig):
            let v = await vetted(r0.identity, sig: sig)
            r.identity = v.identity; r.extraUSD = v.extraUSD; r.limited = v.limited
        case .fresh(let sig):
            // a wine already checked (here or on another phone) under its name: the web check is not paid for twice, even
            // when this photo's label words differ from the last one's
            if let k = await known(r0.identity, sig: sig) { r.identity = k; PriceCloud.shareWine(k, sig: sig); return r }
            let (w, cost, limited) = await verifyOnline(r0.identity)
            r.identity = w; r.extraUSD = cost; r.limited = limited
            WineDB.shared.save(r.identity, signature: sig)
            if !limited { PriceCloud.shareWine(r.identity, sig: sig) }   // an unchecked wine is not shared
        case .typed:
            if let k = await known(r0.identity, sig: nil) { r.identity = k; return r }
            let (w, cost, limited) = await verifyOnline(r0.identity)
            r.identity = w; r.extraUSD = cost; r.limited = limited
            WineDB.shared.save(r.identity)
        }
        return r
    }

    /// What can be shown while the check runs: grapes and notes not yet confirmed stay hidden (a guess is never shown as a fact).
    static func provisional(_ r: RecognitionResult) -> WineIdentity {
        guard r.pending != nil, r.identity.checked != true, r.identity.fromDatabase != true else { return r.identity }
        return hideUnchecked(r.identity)
    }

    /// A wine we already hold: when nothing has checked its grapes yet, check them now (if today's allowance lasts).
    /// Without a check the grapes and notes stay hidden: a guess is never shown as a fact.
    private static func vetted(_ w: WineIdentity, sig: String?) async -> RecognitionResult {
        var r = RecognitionResult(identity: w, usedImage: false, inputTokens: 0, outputTokens: 0)
        guard w.found, !w.name.isEmpty, w.fromDatabase != true, w.checked != true else { return r }
        if !isAvailable { r.identity = hideUnchecked(w); return r }
        let (v, cost, limited) = await verifyOnline(w)
        r.identity = v; r.extraUSD = cost; r.limited = limited
        if !limited { WineDB.shared.save(v, signature: sig); PriceCloud.shareWine(v, sig: sig) }
        return r
    }

    private static func hideUnchecked(_ w: WineIdentity) -> WineIdentity {
        var w = w
        w.grapes = []; w.grapePercent = nil; w.tastingNotes = []
        return w
    }

    /// Checks a wine the database doesn't know. First the cheap way: read the shop page we already know and a few
    /// search-result pages ourselves (free), and let Claude read only that text (a fraction of a cent, no tools).
    /// Only when those pages don't settle the grapes is one paid web search used. Whatever stays unconfirmed is Claude's guess.
    static func verifyOnline(_ w: WineIdentity) async -> (WineIdentity, Double, Bool) {
        guard w.found, !w.name.isEmpty, w.fromDatabase != true else { return (w, 0, false) }
        guard isAvailable else { return (w, 0, false) }
        let wine = [w.producer, w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")
        let place = w.region.isEmpty ? "" : " (" + w.region + ")"
        let format = """
        Reply with only one JSON object and nothing else:
        {"confirmed": true or false, "region": "", "country": "", "grapes": ["..."], "grape_percent": [100], "style": "red|white|rose|sparkling|fortified|sweet|orange", "tasting_notes": ["..."], "palate": "one sentence"}
        Set confirmed to false and grapes to [] if it does not clearly state the grapes of this wine. Use "" or [] for anything not stated.
        """
        var total = 0.0
        var v = w
        // 1. free pages, read by Claude without tools
        let shopURL = await Task.detached(priority: .userInitiated) { PriceBook.shared.price(for: w)?.url }.value ?? WineDB.shared.entry(for: w)?.price?.url
        let pages = await WebFacts.pages(for: wine + " " + w.region, shopURL: shopURL)
        if !pages.isEmpty {
            let prompt = "Wine: \(wine)\(place).\nBelow is text from web pages. Report only what these pages say about this exact wine; never fill gaps from memory.\n\n\(pages)\n\n" + format
            if let (obj, cost) = await askJSON(prompt: prompt, tools: nil, maxTokens: 500) {
                total += cost
                if apply(obj, to: &v) { v.checked = true; return (v, total, false) }
            }
        }
        // 2. one paid search, only if today's allowance allows it
        // the paid search is what the daily allowance protects: without it nothing about this wine has been checked, so its grapes and notes stay hidden
        if DailyBudget.reached { return (hideUnchecked(w), total, true) }
        let prompt = "Use web search to check this wine: \(wine)\(place). Use the producer's own page, a wine shop page or a critic's page for this exact wine. Report only what those pages say; never fill gaps from memory.\n" + format
        let tools: [[String: Any]] = [["type": "web_search_20250305", "name": "web_search", "max_uses": 1]]
        guard let (obj, cost) = await askJSON(prompt: prompt, tools: tools, maxTokens: 600) else {
            // no connection: not marked as checked, so it is tried again next time
            return (w, total, false)
        }
        total += cost
        v.checked = true
        _ = apply(obj, to: &v)
        return (v, total, false)
    }

    /// One Claude call that must answer with a JSON object. Returns the object and what the call cost (also counted against today's allowance).
    private static func askJSON(prompt: String, tools: [[String: Any]]?, maxTokens: Int) async -> ([String: Any], Double)? {
        var body: [String: Any] = ["model": model, "max_tokens": maxTokens, "messages": [["role": "user", "content": prompt]]]
        if let tools { body["tools"] = tools }
        do {
            guard var req = claudeRequest(timeout: 60) else { throw RecognizerError.noKey }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let usage = json["usage"] as? [String: Any] ?? [:]
            let searches = ((usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int) ?? 0
            let cost = Double(usage["input_tokens"] as? Int ?? 0) * 0.10 / 1_000_000
                + Double(usage["output_tokens"] as? Int ?? 0) * 0.50 / 1_000_000 + Double(searches) * searchUSD
            DailyBudget.add(cost)
            let text = (json["content"] as? [[String: Any]] ?? []).filter { ($0["type"] as? String) == "text" }.compactMap { $0["text"] as? String }.joined()
            guard let o = text.lastIndex(of: "{"), let c = text.lastIndex(of: "}"), o < c,
                  let obj = try? JSONSerialization.jsonObject(with: Data(text[o...c].utf8)) as? [String: Any] else { return ([:], cost) }
            return (obj, cost)
        } catch { return nil }
    }

    /// Takes the confirmed facts into the wine. False when the pages did not clearly state the grapes.
    private static func apply(_ obj: [String: Any], to v: inout WineIdentity) -> Bool {
        guard (obj["confirmed"] as? Bool) == true else { return false }
        let grapes = (obj["grapes"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !grapes.isEmpty else { return false }
        v.grapes = grapes
        let pct = (obj["grape_percent"] as? [NSNumber])?.map { $0.intValue } ?? []
        if pct.count == grapes.count, (95...105).contains(pct.reduce(0, +)) { v.grapePercent = pct }
        else if grapes.count == 1 { v.grapePercent = [100] }
        else { v.grapePercent = nil }
        if let s = obj["region"] as? String, !s.isEmpty { v.region = s }
        if let s = obj["country"] as? String, !s.isEmpty { v.country = s }
        if let s = obj["style"] as? String, ["red", "white", "rose", "sparkling", "fortified", "sweet", "orange"].contains(s) { v.style = s }
        let notes = (obj["tasting_notes"] as? [String] ?? []).filter { !$0.isEmpty }
        if !notes.isEmpty { v.tastingNotes = notes }
        if let s = obj["palate"] as? String, !s.isEmpty { v.palate = s }
        return true
    }

    /// "Château Batailley 2021" with vintage 2021 would show the year twice: keep it out of the name.
    static func tidy(_ w: WineIdentity) -> WineIdentity {
        var w = w
        let v = w.vintage.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty, w.name.hasSuffix(" " + v) { w.name = String(w.name.dropLast(v.count + 1)).trimmingCharacters(in: .whitespaces) }
        return w
    }

    private static func identifyFresh(image: UIImage) async throws -> RecognitionResult {
        guard isAvailable else { throw RecognizerError.noKey }
        let lines = await readText(image)
        if let text = usefulText(lines) {
            var r = try await call(content: [["type": "text", "text": "Text read from the wine label (OCR, may contain errors):\n\n" + text]])
            // Text alone is enough only for a confident, named answer; otherwise look at the photo too
            // (script or curved labels such as López de Heredia often defeat OCR).
            if r.identity.found && !r.identity.name.isEmpty && r.identity.confidence == "high" { return r }
            // fall back to the image, adding the cost of the first call
            if let jpeg = small(image) {
                var r2 = try await call(content: imageContent(jpeg, extra: "OCR text, for reference:\n" + text))
                r2.inputTokens += r.inputTokens
                r2.outputTokens += r.outputTokens
                r2.usedImage = true
                return (r2.identity.found && !r2.identity.name.isEmpty) || !r.identity.found ? r2 : r
            }
            r.usedImage = false
            return r
        }
        guard let jpeg = small(image) else { throw RecognizerError.badResponse }
        var r = try await call(content: imageContent(jpeg, extra: nil))
        r.usedImage = true
        return r
    }

    static func identify(text: String) async throws -> RecognitionResult {
        let r = try await identifyFast(text: text)
        let f = await finish(r)
        var out = f; out.inputTokens = r.inputTokens; out.outputTokens = r.outputTokens
        return out
    }

    /// A typed wine name: Claude names it; the check is left to `finish`.
    static func identifyFast(text: String) async throws -> RecognitionResult {
        guard isAvailable else { throw RecognizerError.noKey }
        if DailyBudget.hardStop { throw RecognizerError.limit }
        var r = try await call(content: [["type": "text", "text": "The user typed this wine: " + text]])
        DailyBudget.add(r.costUSD)
        r.identity = tidy(r.identity)
        r.identity = await Task.detached(priority: .userInitiated) { PriceBook.shared.overlay(r.identity) }.value
        r.pending = .typed
        return r
    }

    /// The same wine (producer, name and vintage) already checked: on this phone first, then in the shared online list.
    /// The label signature of this photo is remembered too, so the next photo like it is found before any Claude call.
    private static func known(_ w: WineIdentity, sig: String?) async -> WineIdentity? {
        guard w.found, !w.name.isEmpty, w.fromDatabase != true else { return nil }
        func usable(_ x: WineIdentity) -> Bool { x.found && !x.name.isEmpty && (x.checked == true || x.fromDatabase == true) }
        if let e = WineDB.shared.entry(for: w), usable(e.identity) {
            if let sig { WineDB.shared.save(e.identity, signature: sig) }
            return e.identity
        }
        if let c = await PriceCloud.wine(sig: nil, key: WineDB.key(w)), usable(c) {
            WineDB.shared.save(c, signature: sig)
            return c
        }
        return nil
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
    lowering confidence when unsure. \
    name is the wine's own name exactly as the label prints it (the cuvée, vineyard or appellation, for example "Delicado" or "Tondonia Reserva"), \
    never a grape or style you invented; producer is the winery on the label (for example "Ximénez-Spínola"). \
    Read the largest words on the label first and do not replace them with a better-known wine. Only if you cannot name it at all, set found=false and fill what you can (for example the region or grape). \
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

    private static func call(content: [[String: Any]]) async throws -> RecognitionResult {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "system": system,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": content]]
        ]
        guard var req = claudeRequest(timeout: 45) else { throw RecognizerError.noKey }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RecognizerError.badResponse }
        if status != 200 {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Request failed (\(status))."
            if status == 429, ((json["error"] as? [String: Any])?["type"] as? String) == "limit" { throw RecognizerError.limit }
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
        guard isAvailable, !w.name.isEmpty, !DailyBudget.reached else { return (nil, 0) }
        let wine = [w.producer, w.name, w.vintage].filter { !$0.isEmpty }.joined(separator: " ")
        let body: [String: Any] = [
            "model": model, "max_tokens": 120,
            "messages": [["role": "user", "content": "Typical current retail price in US dollars of one 750 ml bottle of \(wine)\(w.region.isEmpty ? "" : " (" + w.region + ")"). Reply with only JSON: {\"low\": number, \"average\": number, \"high\": number}. Use your best estimate; never 0."]]
        ]
        do {
            guard var req = claudeRequest(timeout: 30) else { throw RecognizerError.noKey }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (nil, 0) }
            let usage = json["usage"] as? [String: Any] ?? [:]
            let cost = Double(usage["input_tokens"] as? Int ?? 0) * 0.10 / 1_000_000 + Double(usage["output_tokens"] as? Int ?? 0) * 0.50 / 1_000_000
            DailyBudget.add(cost)
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
        guard isAvailable, !w.name.isEmpty else { return (PriceInfo.estimate(from: w), 0) }
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
            guard var req = claudeRequest(timeout: 60) else { throw RecognizerError.noKey }
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
