import Foundation

/// Corrections made anywhere (a "Not the right wine?" on any phone, the owner's page at halopro.xyz/jero, tools/fix_wines.py) reach
/// every phone: the worker keeps them in order (`GET /wine/fixes?since=`), and each phone takes in the new ones at launch and when
/// it comes back to the foreground (at most once an hour). A fix renames the wrong wine everywhere on the phone: the scan list,
/// cellar bottles and tastings (their own notes, photos, prices you paid and scores are kept), and the scan timings.
@MainActor enum WineFixes {
    private static let sinceKey = "jero.fixesSince"
    private static let lastKey = "jero.fixesChecked"
    private static weak var journal: JournalStore?

    static func start(_ j: JournalStore) { journal = j }

    /// Checks for new corrections unless that was done in the last hour (`force` skips the wait).
    static func sync(force: Bool = false) async {
        let d = UserDefaults.standard
        let last = d.double(forKey: lastKey)
        guard force || Date().timeIntervalSince1970 - last > 3600 else { return }
        d.set(Date().timeIntervalSince1970, forKey: lastKey)
        let fixes = await PriceCloud.fixes(since: d.integer(forKey: sinceKey))
        guard !fixes.isEmpty else { return }
        for f in fixes { apply(f) }
        d.set(fixes.map(\.id).max() ?? 0, forKey: sinceKey)
    }

    static func apply(_ f: PriceCloud.Fix) {
        guard let right = f.wine else { return }
        WineDB.shared.takeFix(from: f.from, to: right)
        guard let j = journal, j.persist else { return }
        var oldName: String? = nil
        for (i, b) in j.cellar.enumerated() where WineDB.key(b.wine) == f.from {
            oldName = oldName ?? b.wine.name
            var c = b
            c.wine = merged(b.wine, right)
            // the old price belonged to the wrong wine: the right wine's price from our list, else none until it is looked up
            if WineDB.key(c.wine) != f.from, c.price?.source != "You paid" { c.price = PriceBook.shared.price(for: c.wine) }
            j.cellar[i] = c
        }
        for (i, e) in j.entries.enumerated() where WineDB.key(e.wine) == f.from {
            oldName = oldName ?? e.wine.name
            var t = e
            t.wine = merged(e.wine, right)
            j.entries[i] = t
        }
        if let oldName, oldName != right.name { ScanClock.rename(from: oldName, to: right.name) }
    }

    /// For the scan list (no main actor needed).
    nonisolated static func mergedPlain(_ mine: WineIdentity?, _ right: WineIdentity) -> WineIdentity {
        guard let mine else { return right }
        var w = right
        if w.vintage.isEmpty { w.vintage = mine.vintage }
        if w.funFact.isEmpty { w.funFact = mine.funFact }
        if w.food.isEmpty { w.food = mine.food }
        if w.palate.isEmpty { w.palate = mine.palate }
        if (w.drinkWindow ?? "").isEmpty { w.drinkWindow = mine.drinkWindow }
        if w.tastingNotes.isEmpty { w.tastingNotes = mine.tastingNotes }
        return w
    }

    /// The corrected wine's details, keeping what the phone knows that the correction leaves empty (the vintage on your bottle,
    /// a fun fact already found).
    nonisolated static func merged(_ mine: WineIdentity, _ right: WineIdentity) -> WineIdentity { mergedPlain(mine, right) }
}

/// "Not the right wine?": the wine is identified again from the names you typed (our wine list first, else Claude and the online
/// check). What you typed wins (name, producer, vintage, and any place you changed); the rest comes from the new lookup.
enum WineRelook {
    static func lookUp(_ typed: WineIdentity, was old: WineIdentity) async -> (wine: WineIdentity, cost: Double) {
        let text = [typed.producer, typed.name, typed.vintage, typed.region, typed.country].filter { !$0.isEmpty }.joined(separator: " ")
        guard let r = try? await WineRecognizer.identify(text: text) else {
            var w = typed; w.found = true
            return (w, 0)
        }
        var w = r.identity
        w.found = true
        w.name = typed.name
        if !typed.producer.isEmpty { w.producer = typed.producer }
        if !typed.vintage.isEmpty { w.vintage = typed.vintage }
        if typed.region != old.region && !typed.region.isEmpty { w.region = typed.region }
        if typed.country != old.country && !typed.country.isEmpty { w.country = typed.country }
        return (w, r.costUSD)
    }
}
