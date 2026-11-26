import Foundation
import UserNotifications

/// A wine's drinking window ("2025–2035", "Now–2032", "by 2030", "Drink now") as years.
enum DrinkWindow {
    static func years(_ window: String?) -> (start: Int, end: Int)? {
        guard let window, !window.isEmpty else { return nil }
        let now = Calendar.current.component(.year, from: Date())
        let found = window.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.filter { (1900...2100).contains($0) }
        let lower = window.lowercased()
        if found.count >= 2 { return (min(found[0], found[1]), max(found[0], found[1])) }
        if found.count == 1 {
            let y = found[0]
            if lower.contains("by") || lower.contains("until") || lower.contains("now") || lower.contains("before") { return (min(now, y), max(now, y)) }
            return (y, y + 6)
        }
        if lower.contains("now") { return (now, now + 2) }
        return nil
    }

    enum Phase { case young, ready, past }
    static func phase(_ window: String?, on date: Date = Date()) -> Phase? {
        guard let w = years(window) else { return nil }
        let y = Calendar.current.component(.year, from: date)
        return y < w.start ? .young : (y > w.end ? .past : .ready)
    }
}

/// Drinking-window alerts: when a cellar bottle reaches its window, three notifications a month apart, each worded
/// differently ("it's ready", "plan it", "don't miss it"). Bottles that turn ready in the same month share one notification.
/// A bottle stops getting them once it leaves the cellar or is tasted in the journal. Settings > Drinking-window alerts.
enum DrinkAlerts {
    static var enabled: Bool {
        get { (UserDefaults.standard.object(forKey: "jero.drinkAlerts") as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "jero.drinkAlerts") }
    }
    /// iOS keeps 64 pending notifications; the daily ones use 56, so only the next few alerts are queued at a time
    /// (the schedule is rebuilt each time Jero opens).
    static let maxPending = 6

    struct Alert {
        let date: Date
        let stage: Int              // 0, 1, 2
        let bottles: [CellarBottle]
    }

    /// The first Friday of a month, so the nudge lands before the weekend.
    private static func firstFriday(year: Int, month: Int) -> DateComponents? {
        let cal = Calendar.current
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        let wd = cal.component(.weekday, from: first)           // Sunday = 1 … Friday = 6
        let day = 1 + (6 - wd + 7) % 7
        return DateComponents(year: year, month: month, day: day)
    }

    /// The three alert months of one bottle: from the month its window opens (or the month after it was added, when it was
    /// already ready then), squeezed so all of them fall inside the window when the window is short.
    static func months(for b: CellarBottle, now: Date = Date()) -> [DateComponents] {
        guard let w = DrinkWindow.years(b.wine.drinkWindow) else { return [] }
        let cal = Calendar.current
        let opens = cal.date(from: DateComponents(year: w.start, month: 1, day: 1)) ?? now
        let afterAdded = cal.date(byAdding: .month, value: 1, to: b.added) ?? b.added
        let start = max(opens, afterAdded)
        guard let ends = cal.date(from: DateComponents(year: w.end, month: 12, day: 31)), start <= ends else { return [] }
        var out: [DateComponents] = []
        for k in 0..<3 {
            guard let d = cal.date(byAdding: .month, value: k, to: start), d <= ends else { break }
            out.append(cal.dateComponents([.year, .month], from: d))
        }
        return out
    }

    /// Upcoming alerts, soonest first, bottles in the same month grouped.
    static func plan(cellar: [CellarBottle], tastings: [JournalEntry], hour: Int, now: Date = Date()) -> [Alert] {
        let tasted = Set(tastings.map { WineDB.key($0.wine) })
        var byMonth: [String: (date: Date, stage: Int, bottles: [CellarBottle])] = [:]
        let cal = Calendar.current
        for b in cellar where b.quantity > 0 && !tasted.contains(WineDB.key(b.wine)) {
            for (stage, m) in months(for: b, now: now).enumerated() {
                guard let y = m.year, let mo = m.month, var c = firstFriday(year: y, month: mo) else { continue }
                c.hour = hour; c.minute = 0
                guard let date = cal.date(from: c), date > now else { continue }
                let key = "\(y)-\(mo)"
                var slot = byMonth[key] ?? (date, stage, [])
                slot.bottles.append(b)
                slot.stage = max(slot.stage, stage)         // the most urgent wording wins when several share a month
                byMonth[key] = slot
            }
        }
        return byMonth.values.sorted { $0.date < $1.date }.prefix(maxPending).map { Alert(date: $0.date, stage: $0.stage, bottles: $0.bottles) }
    }

    static func content(_ a: Alert) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.sound = .default
        let b = a.bottles[0]
        let name = [b.wine.producer, b.wine.name].filter { !$0.isEmpty }.joined(separator: " ")
        let wine = b.wine.vintage.isEmpty ? name : b.wine.vintage + " " + name
        let food = b.wine.food.first.map { $0.lowercased() }
        let end = DrinkWindow.years(b.wine.drinkWindow)?.end
        if a.bottles.count > 1 {
            let n = a.bottles.count
            switch a.stage {
            case 0: c.title = "\(n) bottles are ready 🍷"; c.body = "\(wine) and \(n - 1) more in your cellar have reached their drinking window."
            case 1: c.title = "Still waiting in your cellar"; c.body = "\(n) bottles are at their best now, starting with the \(wine). Worth planning a dinner around one?"
            default: c.title = "Last nudge for \(n) bottles"; c.body = "\(wine) and \(n - 1) more are in their prime. Don't let them slip past it."
            }
            return c
        }
        switch a.stage {
        case 0:
            c.title = "It's ready 🍷"
            c.body = "Your \(wine) has opened its drinking window." + (food.map { " Lovely with \($0)." } ?? "")
        case 1:
            c.title = "Plan a bottle this month?"
            c.body = "The \(wine) is still waiting in your cellar" + (food.map { ", and \($0) would suit it." } ?? ". A good dinner would suit it.")
        default:
            c.title = "Don't miss it"
            c.body = "Last nudge for the \(wine): it's at its best now" + (end.map { " and drinks well until \($0)." } ?? ", and it won't be forever.")
        }
        return c
    }

    /// Days (start of day) that carry an alert: the morning fun fact steps aside on those mornings.
    static func days(_ alerts: [Alert]) -> Set<Date> {
        Set(alerts.map { Calendar.current.startOfDay(for: $0.date) })
    }
}
