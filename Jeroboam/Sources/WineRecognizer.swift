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

    enum CodingKeys: String, CodingKey {
        case found, name, producer, region, country, grapes, vintage, style, palate, food, currency, confidence
        case tastingNotes = "tasting_notes", priceLow = "price_low", priceHigh = "price_high", funFact = "fun_fact"
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

    static func identify(image: UIImage) async throws -> RecognitionResult {
        guard let key = apiKey else { throw RecognizerError.noKey }
        let lines = await readText(image)
        if let text = usefulText(lines) {
            var r = try await call(key: key, content: [["type": "text", "text": "Text read from the wine label (OCR, may contain errors):\n\n" + text]])
            if r.identity.found && r.identity.confidence != "low" { return r }
            // fall back to the image, adding the cost of the first call
            if let jpeg = small(image) {
                var r2 = try await call(key: key, content: imageContent(jpeg, extra: "OCR text, for reference:\n" + text))
                r2.inputTokens += r.inputTokens
                r2.outputTokens += r.outputTokens
                r2.usedImage = true
                return r2.identity.found ? r2 : r
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
        return try await call(key: key, content: [["type": "text", "text": "The user typed this wine: " + text]])
    }

    private static func imageContent(_ jpeg: Data, extra: String?) -> [[String: Any]] {
        var c: [[String: Any]] = [["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]]]
        c.append(["type": "text", "text": "Identify the wine in this photo." + (extra.map { "\n\n" + $0 } ?? "")])
        return c
    }

    /// Downscale so the image costs roughly 1,000–1,500 input tokens.
    private static func small(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let s = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return img.jpegData(compressionQuality: 0.6)
    }

    private static let system = """
    You identify wines from label text or label photos for a wine-learning journal app. \
    Return your best identification. If you cannot tell which wine it is, set found=false and fill what you can (for example the region or grape). \
    tasting_notes: 4-6 short aroma/flavor descriptors typical of this wine (e.g. "Black cherry", "Vanilla"). \
    palate: one sentence on structure (sweetness, acidity, tannin, body). \
    price_low/price_high: typical current retail price range for one 750 ml bottle in US dollars, as an estimate from your knowledge (0 if unknown). \
    style: one of red, white, rose, sparkling, fortified, sweet, orange. confidence: high, medium or low. \
    fun_fact: one short, accurate sentence that teaches something about this wine, its region or grape. Keep every field concise.
    """

    private static var schema: [String: Any] {
        let str: [String: Any] = ["type": "string"]
        let strArr: [String: Any] = ["type": "array", "items": ["type": "string"]]
        let num: [String: Any] = ["type": "number"]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["found", "name", "producer", "region", "country", "grapes", "vintage", "style", "tasting_notes",
                         "palate", "food", "price_low", "price_high", "currency", "confidence", "fun_fact"],
            "properties": [
                "found": ["type": "boolean"], "name": str, "producer": str, "region": str, "country": str, "grapes": strArr,
                "vintage": str,
                "style": ["type": "string", "enum": ["red", "white", "rose", "sparkling", "fortified", "sweet", "orange"]],
                "tasting_notes": strArr, "palate": str, "food": strArr, "price_low": num, "price_high": num, "currency": str,
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]], "fun_fact": str
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
