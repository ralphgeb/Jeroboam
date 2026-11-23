import Foundation
import UIKit

/// Every wine you have scanned or looked up, kept on the phone, so the same bottle is never searched (or paid for) twice.
/// Looked up by the label's own text (a second photo of the same label), or by producer, name and vintage.
final class WineDB {
    static let shared = WineDB()

    struct Entry: Codable {
        var identity: WineIdentity
        var price: PriceInfo?
        var saved = Date()
        /// When it was last scanned or looked up, how many times, and a small picture of the label (kept even if the bottle leaves the cellar).
        var lastSeen: Date? = nil
        var scans: Int? = nil
        var thumb: Data? = nil
    }
    private struct Store: Codable {
        var wines: [String: Entry] = [:]
        var signatures: [String: String] = [:]
    }

    private var store = Store()
    private let lock = NSLock()
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("winedb.json")

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Store.self, from: d) { store = s }
    }

    // MARK: keys

    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
    }
    static func key(_ w: WineIdentity) -> String {
        let name = fold(w.name).split(separator: " ").joined(separator: " ")
        return [fold(w.producer), name, fold(w.vintage)].map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "|")
    }
    /// The big words on the label (OCR lists the largest text first), the same for two photos of one label.
    static func signature(_ lines: [String]) -> String? {
        let words = lines.prefix(4).flatMap { fold($0).split(separator: " ").map(String.init) }.filter { $0.count >= 4 }
        guard words.count >= 2 else { return nil }
        return Array(Set(words)).sorted().prefix(8).joined(separator: " ")
    }

    // MARK: lookups

    func entry(forSignature sig: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        return store.signatures[sig].flatMap { store.wines[$0] }
    }
    /// Prices found by the shop list before it told red from white are looked up again (once).
    func dropShopPricesOnce() {
        let flag = "jero.shopPricesColorFix2"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        lock.lock()
        for (k, e) in store.wines {
            if let src = e.price?.source, src.hasPrefix("Cheapest of") || src.hasPrefix("Shop price") || src.hasPrefix("Average of") {
                var c = e; c.price = nil; store.wines[k] = c
            }
        }
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
    }
    /// Remembers a scan: the wine stays in this list for good, even when it is removed from the cellar or the tastings.
    func noteScan(_ w: WineIdentity, image: UIImage?) {
        guard !w.name.isEmpty else { return }
        PriceCloud.shareWine(w)   // counted anonymously, so we can see what people scan
        let small: Data? = image.flatMap { img in
            let side = max(img.size.width, img.size.height)
            let k = min(1, 240 / max(1, side))
            let size = CGSize(width: img.size.width * k, height: img.size.height * k)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.6)
        }
        lock.lock()
        let k = Self.key(w)
        var e = store.wines[k] ?? Entry(identity: w, price: nil)
        e.identity = w
        e.lastSeen = Date()
        e.scans = (e.scans ?? 0) + 1
        if let small { e.thumb = small }
        store.wines[k] = e
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
    }

    /// Everything ever scanned, newest first.
    func history() -> [Entry] {
        allEntries().filter { !$0.identity.name.isEmpty && ($0.lastSeen != nil || $0.scans != nil) }
            .sorted { ($0.lastSeen ?? $0.saved) > ($1.lastSeen ?? $1.saved) }
    }

    func allEntries() -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.wines.values)
    }
    func entry(for w: WineIdentity) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        return store.wines[Self.key(w)]
    }

    // MARK: saving

    func save(_ w: WineIdentity, price: PriceInfo? = nil, signature: String? = nil) {
        guard w.found, !w.name.isEmpty else { return }
        lock.lock()
        let k = Self.key(w)
        var e = store.wines[k] ?? Entry(identity: w, price: nil)
        e.identity = w
        if let price { e.price = price }
        store.wines[k] = e
        if let signature { store.signatures[signature] = k }
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
    }

    // MARK: the Great wines list

    /// Wine-Searcher average from the app's own Great wines list, when this bottle is on it.
    static func greatPrice(for w: WineIdentity) -> PriceInfo? {
        let name = fold(w.name + " " + w.producer)
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        for g in ContentStore.shared.library.great ?? [] where (g.avgPrice ?? 0) > 0 {
            let n = fold(g.name), p = fold(g.producer)
            let last = p.split(separator: " ").last.map(String.init) ?? p
            if !n.isEmpty, name.contains(n), last.isEmpty || name.contains(last) {
                let avg = Double(g.avgPrice ?? 0)
                return PriceInfo(average: avg, low: avg * 0.8, high: avg * 1.25, currency: "USD",
                                 source: (g.source ?? "").contains("wine-searcher") ? "Wine-Searcher" : "Estimate", url: g.source)
            }
        }
        return nil
    }
}
