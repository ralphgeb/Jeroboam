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
        /// Wines taken out of the list (a corrected wrong wine) and when: kept so every phone removes them too, and so an
        /// older copy from iCloud never brings them back.
        var removed: [String: Date]? = nil
    }

    /// The iCloud copy: the list and its removals.
    private struct Backup: Codable {
        var wines: [String: Entry]
        var removed: [String: Date]?
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
    /// Labels remembered by builds whose list matching could pick the wrong wine (Guigal's Côtes du Rhône became their Château
    /// d'Ampuis from the "bottled by" line): the label -> wine links are forgotten once, so those labels are identified again.
    /// The wines themselves (scan history, journal) are kept.
    func forgetLabelLinksOnce() {
        // reset 2: links saved before the "longer producer name" and "scattered producer" rules (La Croix de Marbuzet, Wairau Cove)
        let flag = "jero.labelLinksReset2"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        lock.lock()
        store.signatures = [:]
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
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
        DailyBudget.countScan()
        PriceCloud.shareWine(w, count: true)   // counted anonymously (once per scan), so we can see what people scan
        DispatchQueue.main.async { CloudSync.shared.journalChanged() }   // the scan list is backed up to iCloud with the journal
        if let image { LabelPrint.share(image, for: w) }   // the label's fingerprint, for picture matching later (numbers, not the photo)
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

    /// A correction made elsewhere (another phone, the owner's page): the wrong wine's entry and its label links move to the right
    /// wine on this phone. Nothing is sent back (the server already has it).
    func takeFix(from old: String, to right: WineIdentity) {
        lock.lock()
        let nk = Self.key(right)
        let was = store.wines[old]
        guard was != nil || store.signatures.values.contains(old) else { lock.unlock(); return }
        if old != nk {
            store.wines[old] = nil
            var gone = store.removed ?? [:]
            gone[old] = Date()
            store.removed = gone
        }
        var e = store.wines[nk] ?? Entry(identity: right, price: nil)
        e.identity = WineFixes.mergedPlain(was?.identity, right)
        e.lastSeen = e.lastSeen ?? was?.lastSeen
        e.scans = max(e.scans ?? 0, was?.scans ?? 0)
        e.thumb = e.thumb ?? was?.thumb
        store.wines[nk] = e
        for (sig, k) in store.signatures where k == old { store.signatures[sig] = nk }
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
        DispatchQueue.main.async { CloudSync.shared.journalChanged() }
    }

    /// The owner corrected a wine that was read wrongly: the wrong entry (and the label signatures pointing at it) goes, the right one stays.
    func correct(from old: WineIdentity, to new: WineIdentity, image: UIImage?) {
        lock.lock()
        let ok = Self.key(old), nk = Self.key(new)
        let was = store.wines[ok]
        if ok != nk {
            store.wines[ok] = nil
            var gone = store.removed ?? [:]
            gone[ok] = Date()            // other phones remove it too (iCloud backup)
            store.removed = gone
        }
        store.removed?[nk] = nil         // the corrected wine is wanted, even if it was removed once before
        var e = store.wines[nk] ?? Entry(identity: new, price: was?.price)
        e.identity = new
        e.lastSeen = Date(); e.scans = (was?.scans ?? 1)
        e.thumb = e.thumb ?? was?.thumb
        store.wines[nk] = e
        var sigs: [String] = []
        for (sig, k) in store.signatures where k == ok { store.signatures[sig] = nk; sigs.append(sig) }
        let snapshot = store
        lock.unlock()
        if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
        // the corrected wine goes up with this label's signature, so the next scan of the label finds it online too
        PriceCloud.shareWine(new, sig: sigs.first)
        // online: the wrong wine's row goes, its label signature and fingerprints move to the corrected wine
        if ok != nk { PriceCloud.correctWine(from: ok, to: nk) }
        ScanClock.rename(from: old.name, to: new.name)
        DispatchQueue.main.async { CloudSync.shared.journalChanged() }   // the scan list backup follows
    }

    // MARK: iCloud backup of the scan list (JournalCloud: one record "scan-history" in the journal zone)

    /// Every wine looked up on this phone, with all its details, price and small label picture (the label-text links are left
    /// out: they are only a shortcut). Sorted keys, so an unchanged list gives the same bytes and is not sent again.
    func backupData() -> Data? {
        lock.lock(); let wines = store.wines, removed = store.removed; lock.unlock()
        guard !wines.isEmpty || !(removed ?? [:]).isEmpty else { return nil }
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try? e.encode(Backup(wines: wines, removed: removed))
    }

    /// Wines from the iCloud copy that this phone lacks (a new phone, a reinstall, another phone's scans) are added; a wine both
    /// have keeps the copy seen most recently, and its scan count is the larger of the two.
    func merge(backup: Data) {
        // older builds sent the list alone, newer ones the list and its removals
        let copy = (try? JSONDecoder().decode(Backup.self, from: backup))
            ?? (try? JSONDecoder().decode([String: Entry].self, from: backup)).map { Backup(wines: $0, removed: nil) }
        guard let copy else { return }
        let theirs = copy.wines
        lock.lock()
        var changed = false
        // removals first: a wine removed on another phone goes here too, unless it was scanned again here after the removal
        var gone = store.removed ?? [:]
        for (k, when) in copy.removed ?? [:] {
            if gone[k] == nil || gone[k]! < when { gone[k] = when; changed = true }
            if let mine = store.wines[k], (mine.lastSeen ?? mine.saved) <= when {
                store.wines[k] = nil
                changed = true
                for (sig, v) in store.signatures where v == k { store.signatures[sig] = nil }
            }
        }
        store.removed = gone.isEmpty ? nil : gone
        for (k, t) in theirs {
            if let when = gone[k], (t.lastSeen ?? t.saved) <= when { continue }   // removed after this copy was made
            if let mine = store.wines[k] {
                let newer = (t.lastSeen ?? t.saved) > (mine.lastSeen ?? mine.saved)
                var m = newer ? t : mine
                m.scans = max(mine.scans ?? 0, t.scans ?? 0) == 0 ? nil : max(mine.scans ?? 0, t.scans ?? 0)
                m.thumb = m.thumb ?? mine.thumb ?? t.thumb
                if newer || m.scans != mine.scans || m.thumb != mine.thumb { store.wines[k] = m; changed = true }
            } else {
                store.wines[k] = t; changed = true
            }
        }
        let snapshot = store
        lock.unlock()
        if changed, let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
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
