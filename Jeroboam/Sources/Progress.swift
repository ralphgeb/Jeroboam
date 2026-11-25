import Foundation
import SwiftUI
import Observation
import UserNotifications

struct LessonRecord: Codable, Hashable {
    var completions: Int = 0
    var bestAccuracy: Double = 0
    var perfect: Bool = false
    var lastDate: String = ""
}

struct ProgressData: Codable {
    var onboarded = false
    var name: String = ""
    var startLevel = 1
    var dailyGoal = 30
    var xp = 0
    var streak = 0
    var bestStreak = 0
    var lastActiveDay = ""
    var freezes = 1
    var lessons: [String: LessonRecord] = [:]
    var dailyXP: [String: Int] = [:]
    var mistakes: [String] = []           // card ids answered wrong (most recent last)
    var unlockedLevels: [Int] = [1]
    var answered = 0
    var correct = 0
    var achievements: [String] = []
    var achievementDates: [String: Date]? = nil     // when each badge was earned (badges earned before this existed have none)
    var reminders = false
    var reminderHour = 19
    var morningFacts: Bool? = nil        // nil = on with reminders
    var factHour: Int? = nil
    var appearance = 1                    // 0 auto, 1 light, 2 dark (the app starts in light mode)
    var practiceSessions = 0
    var perfectLessons = 0
    var viewedGrapes: [String] = []
    var viewedRegions: [String] = []
    /// Spaced review of corrected mistakes: card id -> its box (1–4) and the day it is due again (optional: older saves load).
    var reviews: [String: ReviewItem]? = nil
}

/// A corrected mistake coming back for review: after 1, 3, 7 and 21 days, then it graduates.
struct ReviewItem: Codable, Hashable {
    var box: Int
    var due: String
    static let intervals = [1, 3, 7, 21]
}

extension ProgressData {
    /// Two phones' progress put together, so neither goes backwards: completed lessons, badges, viewed pages and
    /// mistakes are joined, counters keep the higher value, the streak comes from the phone used last.
    /// This phone's own settings (goal, reminders, appearance) stay as they are.
    static func merged(local: ProgressData, remote: ProgressData) -> ProgressData {
        var m = local
        m.onboarded = local.onboarded || remote.onboarded
        if m.name.isEmpty { m.name = remote.name }
        if !local.onboarded && remote.onboarded {
            // a new phone takes the settings chosen on the other one
            m.startLevel = remote.startLevel; m.dailyGoal = remote.dailyGoal
            m.reminders = remote.reminders; m.reminderHour = remote.reminderHour
            m.morningFacts = remote.morningFacts; m.factHour = remote.factHour
        }
        m.xp = max(local.xp, remote.xp)
        if remote.lastActiveDay > local.lastActiveDay {
            m.streak = remote.streak; m.lastActiveDay = remote.lastActiveDay; m.freezes = remote.freezes
        } else if remote.lastActiveDay == local.lastActiveDay {
            m.streak = max(local.streak, remote.streak)
        }
        m.bestStreak = max(local.bestStreak, remote.bestStreak, m.streak)
        for (k, r) in remote.lessons {
            guard let l = local.lessons[k] else { m.lessons[k] = r; continue }
            m.lessons[k] = LessonRecord(completions: max(l.completions, r.completions), bestAccuracy: max(l.bestAccuracy, r.bestAccuracy),
                                        perfect: l.perfect || r.perfect, lastDate: max(l.lastDate, r.lastDate))
        }
        for (k, v) in remote.dailyXP { m.dailyXP[k] = max(local.dailyXP[k] ?? 0, v) }
        m.mistakes = local.mistakes + remote.mistakes.filter { !local.mistakes.contains($0) }
        if m.mistakes.count > 200 { m.mistakes.removeFirst(m.mistakes.count - 200) }
        if local.reviews != nil || remote.reviews != nil {
            var rv = remote.reviews ?? [:]
            for (k, v) in local.reviews ?? [:] { rv[k] = v }      // this phone's schedule wins for the same card
            for k in m.mistakes { rv[k] = nil }                    // a card answered wrong is a mistake again, not a review
            m.reviews = rv.isEmpty ? nil : rv
        }
        m.unlockedLevels = Array(Set(local.unlockedLevels).union(remote.unlockedLevels)).sorted()
        m.answered = max(local.answered, remote.answered)
        m.correct = max(local.correct, remote.correct)
        m.achievements = local.achievements + remote.achievements.filter { !local.achievements.contains($0) }
        if local.achievementDates != nil || remote.achievementDates != nil {
            var dates = remote.achievementDates ?? [:]
            for (k, v) in local.achievementDates ?? [:] { dates[k] = min(v, dates[k] ?? v) }
            m.achievementDates = dates
        }
        m.practiceSessions = max(local.practiceSessions, remote.practiceSessions)
        m.perfectLessons = max(local.perfectLessons, remote.perfectLessons)
        m.viewedGrapes = local.viewedGrapes + remote.viewedGrapes.filter { !local.viewedGrapes.contains($0) }
        m.viewedRegions = local.viewedRegions + remote.viewedRegions.filter { !local.viewedRegions.contains($0) }
        return m
    }
}

/// The player's progress: XP, streak, completed lessons and settings. Saved in UserDefaults.
@Observable
final class GameProgress {
    var data: ProgressData {
        didSet { save() }
    }

    @ObservationIgnored private let key = "jeroboam.progress.v1"
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let d = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = d
        } else {
            data = ProgressData()
        }
        // the app always starts in light mode: phones still on the old default (Automatic) are moved to Light once;
        // after that the choice in Settings is respected
        if !UserDefaults.standard.bool(forKey: "jero.lightStart") {
            UserDefaults.standard.set(true, forKey: "jero.lightStart")
            if data.appearance == 0 { data.appearance = 1 }
        }
        refreshStreakState()
    }

    /// Several changes in a row (one answer touches the counters, the mistakes and the review schedule) are written once.
    @ObservationIgnored private var savePending = false
    private func save() {
        guard !savePending else { return }
        savePending = true
        DispatchQueue.main.async { [weak self] in self?.saveNow() }
    }
    /// Writes straight away (the app going to the background calls this so nothing is lost).
    func saveNow() {
        savePending = false
        if let raw = try? JSONEncoder().encode(data) { defaults.set(raw, forKey: key); CloudSync.shared.pushProgress(raw) }
    }

    // MARK: Days

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    static func date(_ day: String) -> Date? { dayFormatter.date(from: day) }

    private func daysBetween(_ a: String, _ b: String) -> Int? {
        guard let da = Self.date(a), let db = Self.date(b) else { return nil }
        return Calendar.current.dateComponents([.day], from: da, to: db).day
    }

    /// Breaks the streak if a day (or more) was missed and no freeze covers it.
    func refreshStreakState() {
        guard !data.lastActiveDay.isEmpty, let gap = daysBetween(data.lastActiveDay, Self.day()) else { return }
        if gap >= 2 {
            if gap == 2 && data.freezes > 0 && data.streak > 0 {
                // A freeze covers exactly one missed day; keep the streak alive (it is consumed on the next lesson).
                return
            }
            if data.streak != 0 { data.streak = 0 }
        }
    }

    var todayXP: Int { data.dailyXP[Self.day()] ?? 0 }
    var goalReached: Bool { todayXP >= data.dailyGoal }
    var activeToday: Bool { data.lastActiveDay == Self.day() }

    /// Streak as it should be shown right now.
    var displayStreak: Int { data.streak }

    // MARK: Earning

    struct Reward {
        var xp: Int
        var streakIncreased: Bool
        var newStreak: Int
        var goalJustReached: Bool
        var newAchievements: [Achievement]
        var usedFreeze: Bool
    }

    @discardableResult
    func award(xp: Int) -> Reward {
        let today = Self.day()
        let wasGoal = goalReached
        var streakUp = false
        var usedFreeze = false
        var d = data
        if d.lastActiveDay != today {
            let gap = d.lastActiveDay.isEmpty ? nil : daysBetween(d.lastActiveDay, today)
            if gap == 1 {
                d.streak += 1
            } else if gap == 2 && d.freezes > 0 && d.streak > 0 {
                d.freezes -= 1
                usedFreeze = true
                d.streak += 1
            } else {
                d.streak = 1
            }
            d.lastActiveDay = today
            streakUp = true
            // Earn a streak freeze every 7 days (max 2).
            if d.streak % 7 == 0 && d.freezes < 2 { d.freezes += 1 }
        }
        d.bestStreak = max(d.bestStreak, d.streak)
        d.xp += xp
        d.dailyXP[today, default: 0] += xp
        data = d
        let newOnes = checkAchievements()
        return Reward(xp: xp, streakIncreased: streakUp, newStreak: data.streak,
                      goalJustReached: !wasGoal && goalReached, newAchievements: newOnes, usedFreeze: usedFreeze)
    }

    func recordAnswer(cardID: String, correct: Bool) {
        var d = data
        d.answered += 1
        var rv = d.reviews ?? [:]
        let today = Self.day()
        func inDays(_ n: Int) -> String { Self.day(Calendar.current.date(byAdding: .day, value: n, to: Date()) ?? Date()) }
        if correct {
            d.correct += 1
            if let i = d.mistakes.firstIndex(of: cardID) {
                // a corrected mistake is not forgotten: it comes back tomorrow, then after 3, 7 and 21 days
                d.mistakes.remove(at: i)
                rv[cardID] = ReviewItem(box: 1, due: inDays(ReviewItem.intervals[0]))
            } else if let r = rv[cardID], r.due <= today {
                let box = r.box + 1
                if box > ReviewItem.intervals.count { rv[cardID] = nil }   // remembered after 21 days: learned
                else { rv[cardID] = ReviewItem(box: box, due: inDays(ReviewItem.intervals[box - 1])) }
            }
        } else {
            d.mistakes.removeAll { $0 == cardID }
            d.mistakes.append(cardID)
            if d.mistakes.count > 200 { d.mistakes.removeFirst(d.mistakes.count - 200) }
            rv[cardID] = nil
        }
        d.reviews = rv.isEmpty ? nil : rv
        data = d
    }

    /// Questions to review now: recent mistakes first, then corrected ones whose review day has come.
    var dueReviews: [String] {
        let today = Self.day()
        let due = (data.reviews ?? [:]).filter { $0.value.due <= today && !data.mistakes.contains($0.key) }
            .sorted { $0.value.due < $1.value.due }.map(\.key)
        return data.mistakes + due
    }

    func completeLesson(_ id: String, accuracy: Double) {
        var r = data.lessons[id] ?? LessonRecord()
        r.completions += 1
        r.bestAccuracy = max(r.bestAccuracy, accuracy)
        if accuracy >= 0.999 {
            if !r.perfect { data.perfectLessons += 1 }
            r.perfect = true
        }
        r.lastDate = Self.day()
        data.lessons[id] = r
        // Finishing a whole level unlocks the next one.
        for level in ContentStore.shared.course.levels {
            let ids = level.courseUnits.flatMap { $0.lessons.map(\.id) }
            if !ids.isEmpty && ids.allSatisfy({ data.lessons[$0] != nil }) && !data.unlockedLevels.contains(level.number + 1) {
                data.unlockedLevels.append(level.number + 1)
            }
        }
    }

    func isCompleted(_ lessonID: String) -> Bool { data.lessons[lessonID] != nil }

    func isLevelUnlocked(_ n: Int) -> Bool { data.unlockedLevels.contains(n) || n <= data.startLevel }

    func unlockLevel(_ n: Int) {
        if !data.unlockedLevels.contains(n) { data.unlockedLevels.append(n) }
    }

    /// The first lesson not yet completed in a level (its "current" node).
    func currentLesson(in level: Level) -> Lesson? {
        level.courseUnits.flatMap(\.lessons).first { !isCompleted($0.id) }
    }

    func isUnlocked(_ lesson: Lesson, in level: Level) -> Bool {
        guard isLevelUnlocked(level.number) else { return false }
        if level.studyUnits.contains(where: { $0.lessons.contains(lesson) }) { return true }
        let all = level.courseUnits.flatMap(\.lessons)
        guard let i = all.firstIndex(of: lesson) else { return false }
        if i == 0 { return true }
        return isCompleted(all[i - 1].id) || isCompleted(lesson.id)
    }

    func levelProgress(_ level: Level) -> Double {
        let all = level.courseUnits.flatMap(\.lessons)
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { isCompleted($0.id) }.count) / Double(all.count)
    }

    func unitProgress(_ unit: Unit) -> Double {
        guard !unit.lessons.isEmpty else { return 0 }
        return Double(unit.lessons.filter { isCompleted($0.id) }.count) / Double(unit.lessons.count)
    }

    var accuracy: Double { data.answered == 0 ? 0 : Double(data.correct) / Double(data.answered) }

    var completedCount: Int { data.lessons.count }

    // MARK: Rank

    static let ranks: [(xp: Int, title: String)] = [
        (0, "Curious sipper"), (100, "Cellar hand"), (300, "Vineyard apprentice"), (700, "Wine enthusiast"),
        (1200, "Cellar master"), (2000, "Sommelier"), (3200, "Head sommelier"), (5000, "Master of wine")
    ]

    var rank: String { Self.ranks.last { data.xp >= $0.xp }?.title ?? "Curious sipper" }

    var nextRank: (xp: Int, title: String)? { Self.ranks.first { $0.xp > data.xp } }

    var rankProgress: Double {
        let cur = Self.ranks.last { data.xp >= $0.xp }?.xp ?? 0
        guard let next = nextRank else { return 1 }
        return Double(data.xp - cur) / Double(next.xp - cur)
    }

    // MARK: Achievements

    @discardableResult
    func checkAchievements() -> [Achievement] {
        var new: [Achievement] = []
        for a in Achievement.all where !data.achievements.contains(a.id) && a.test(self) {
            data.achievements.append(a.id)
            var d = data.achievementDates ?? [:]
            d[a.id] = Date()
            data.achievementDates = d
            new.append(a)
        }
        if !new.isEmpty, data.onboarded {
            let dates = data.achievementDates ?? [:]
            let list = new
            Task { @MainActor in BadgeCelebration.shared.announce(list, dates: dates) }
        }
        return new
    }

    func noteViewed(grape id: String) {
        if !data.viewedGrapes.contains(id) { data.viewedGrapes.append(id); checkAchievements() }
    }

    func noteViewed(region id: String) {
        if !data.viewedRegions.contains(id) { data.viewedRegions.append(id); checkAchievements() }
    }

    func reset() {
        var fresh = ProgressData()
        fresh.onboarded = true
        fresh.dailyGoal = data.dailyGoal
        fresh.appearance = data.appearance
        data = fresh
    }

    var colorScheme: ColorScheme? {
        switch data.appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    // MARK: Reminders

    func setReminders(_ on: Bool) {
        data.reminders = on
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
        guard on else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { self.data.reminders = false }
                return
            }
            self.scheduleReminder()
        }
    }

    func scheduleReminder() {
        Notifications.shared.reschedule(self)
    }
}

/// Shows notifications as banners even while Jero is open (needed for "Send a fun fact now").
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Two gentle notifications a day: a wine fun fact in the morning, a nudge to practice in the evening.
/// Scheduled four weeks ahead (iOS keeps at most 64), and refreshed whenever Jero opens.
final class Notifications {
    static let shared = Notifications()
    private let center = UNUserNotificationCenter.current()

    private let evening: [(String, String)] = [
        ("Time for a glass of knowledge 🍷", "A five-minute lesson keeps your streak alive."),
        ("Quick tasting quiz?", "Ten questions, three minutes. How sharp is your palate tonight?"),
        ("Your streak is waiting", "One short lesson and you're done for the day."),
        ("Pop the cork on a quiz", "A daily mix of grapes, regions and styles is ready."),
        ("Before dinner…", "Brush up on food and wine in a quick practice round."),
        ("A little wine homework", "Review the questions you missed: it's the fastest way to learn."),
        ("Ready for a mock exam?", "Thirty questions to see how close you are to the next level."),
    ]

    func reschedule(_ p: GameProgress) {
        let ids = (0..<64).flatMap { ["fact-\($0)", "practice-\($0)"] } + ["daily-reminder"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard p.data.reminders else { return }
        let facts = ContentStore.shared.library.facts ?? []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayNumber = Int(today.timeIntervalSince1970 / 86400)
        for d in 0..<28 {
            guard let day = cal.date(byAdding: .day, value: d, to: today) else { continue }
            if p.data.morningFacts ?? true, !facts.isEmpty {
                let c = UNMutableNotificationContent()
                c.title = "Did you know? 🍇"
                c.body = facts[(dayNumber + d) % facts.count]
                c.sound = .default
                add("fact-\(d)", c, day, hour: p.data.factHour ?? 9, minute: 0)
            }
            let (t, b) = evening[(dayNumber + d) % evening.count]
            let c = UNMutableNotificationContent()
            c.title = t; c.body = b; c.sound = .default
            add("practice-\(d)", c, day, hour: p.data.reminderHour, minute: 0)
        }
    }

    private func add(_ id: String, _ c: UNMutableNotificationContent, _ day: Date, hour: Int, minute: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour; comps.minute = minute
        guard let fire = Calendar.current.date(from: comps), fire > Date() else { return }
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// TestFlight: a fun fact in five seconds.
    func sendTestFact() {
        let facts = ContentStore.shared.library.facts ?? []
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok, let f = facts.randomElement() else { return }
            let c = UNMutableNotificationContent()
            c.title = "Did you know? 🍇"; c.body = f; c.sound = .default
            self.center.add(UNNotificationRequest(identifier: "fact-test", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
        }
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let test: (GameProgress) -> Bool

    static func == (a: Achievement, b: Achievement) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// Set by the app so the journal badges can look at the cellar and tastings.
    static weak var journal: JournalStore?
    private static var cellarCount: Int { journal?.bottleCount ?? 0 }
    private static var tastingCount: Int { journal?.entries.count ?? 0 }
    private static var blindEntries: [JournalEntry] { journal?.entries.filter { $0.blind == true } ?? [] }
    private static var countryCount: Int {
        Set(((journal?.cellar.map(\.wine.country) ?? []) + (journal?.entries.map(\.wine.country) ?? [])).filter { !$0.isEmpty }.map { $0.lowercased() }).count
    }

    static let all: [Achievement] = [
        Achievement(id: "first-sip", title: "First sip", detail: "Finish your first lesson", icon: "wineglass") { $0.completedCount >= 1 },
        Achievement(id: "streak-3", title: "Three-day swirl", detail: "Reach a 3-day streak", icon: "flame") { $0.data.bestStreak >= 3 },
        Achievement(id: "streak-7", title: "Week in the cellar", detail: "Reach a 7-day streak", icon: "flame.fill") { $0.data.bestStreak >= 7 },
        Achievement(id: "streak-30", title: "Vintage habit", detail: "Reach a 30-day streak", icon: "calendar") { $0.data.bestStreak >= 30 },
        Achievement(id: "perfect", title: "Flawless pour", detail: "Finish a lesson without a mistake", icon: "star.fill") { $0.data.perfectLessons >= 1 },
        Achievement(id: "perfect-10", title: "Steady hand", detail: "10 perfect lessons", icon: "sparkles") { $0.data.perfectLessons >= 10 },
        Achievement(id: "xp-500", title: "Half a cellar", detail: "Earn 500 XP", icon: "bolt.fill") { $0.data.xp >= 500 },
        Achievement(id: "xp-2000", title: "Sommelier in training", detail: "Earn 2,000 XP", icon: "medal.fill") { $0.data.xp >= 2000 },
        Achievement(id: "level-1", title: "Foundations", detail: "Complete Level 1", icon: "1.circle.fill") { p in
            guard let l = ContentStore.shared.course.levels.first(where: { $0.number == 1 }) else { return false }
            return p.levelProgress(l) >= 1
        },
        Achievement(id: "level-2", title: "Essentials", detail: "Complete Level 2", icon: "2.circle.fill") { p in
            guard let l = ContentStore.shared.course.levels.first(where: { $0.number == 2 }) else { return false }
            return p.levelProgress(l) >= 1
        },
        Achievement(id: "level-3", title: "Intermediate", detail: "Complete Level 3", icon: "3.circle.fill") { p in
            guard let l = ContentStore.shared.course.levels.first(where: { $0.number == 3 }) else { return false }
            return p.levelProgress(l) >= 1
        },
        Achievement(id: "level-4", title: "Advanced", detail: "Complete Level 4", icon: "4.circle.fill") { p in
            guard let l = ContentStore.shared.course.levels.first(where: { $0.number == 4 }) else { return false }
            return p.levelProgress(l) >= 1
        },
        Achievement(id: "level-5", title: "Expert", detail: "Complete Level 5", icon: "5.circle.fill") { p in
            guard let l = ContentStore.shared.course.levels.first(where: { $0.number == 5 }) else { return false }
            return p.levelProgress(l) >= 1
        },
        Achievement(id: "ampelographer", title: "Ampelographer", detail: "Open 20 grape profiles", icon: "leaf.fill") { $0.data.viewedGrapes.count >= 20 },
        Achievement(id: "globetrotter", title: "Globetrotter", detail: "Explore 20 regions", icon: "globe.europe.africa.fill") { $0.data.viewedRegions.count >= 20 },
        Achievement(id: "practice-10", title: "Practice makes perfect", detail: "Finish 10 practice sessions", icon: "dumbbell.fill") { $0.data.practiceSessions >= 10 },
        Achievement(id: "answers-500", title: "Well read", detail: "Answer 500 questions", icon: "book.fill") { $0.data.answered >= 500 },
        Achievement(id: "streak-14", title: "Fortnight in the glass", detail: "Reach a 14-day streak", icon: "flame.circle.fill") { $0.data.bestStreak >= 14 },
        Achievement(id: "streak-100", title: "A hundred days", detail: "Reach a 100-day streak", icon: "crown.fill") { $0.data.bestStreak >= 100 },
        Achievement(id: "xp-5000", title: "Grand cru", detail: "Earn 5,000 XP", icon: "trophy.fill") { $0.data.xp >= 5000 },
        Achievement(id: "perfect-25", title: "Not a drop spilled", detail: "25 perfect lessons", icon: "star.circle.fill") { $0.data.perfectLessons >= 25 },
        Achievement(id: "answers-2000", title: "Walking encyclopedia", detail: "Answer 2,000 questions", icon: "books.vertical.fill") { $0.data.answered >= 2000 },
        Achievement(id: "practice-50", title: "Always practising", detail: "Finish 50 practice sessions", icon: "figure.run") { $0.data.practiceSessions >= 50 },
        Achievement(id: "grapes-50", title: "Grape collector", detail: "Open 50 grape profiles", icon: "leaf.circle.fill") { $0.data.viewedGrapes.count >= 50 },
        Achievement(id: "regions-60", title: "Atlas explorer", detail: "Explore 60 regions", icon: "map.fill") { $0.data.viewedRegions.count >= 60 },
        Achievement(id: "first-scan", title: "Label reader", detail: "Scan your first wine", icon: "camera.viewfinder") { _ in cellarCount >= 1 },
        Achievement(id: "cellar-10", title: "Cellar master", detail: "Keep 10 bottles in your cellar", icon: "square.stack.3d.up.fill") { _ in cellarCount >= 10 },
        Achievement(id: "cellar-50", title: "Private collection", detail: "Keep 50 bottles in your cellar", icon: "building.columns.fill") { _ in cellarCount >= 50 },
        Achievement(id: "first-tasting", title: "Note taker", detail: "Write your first tasting note", icon: "square.and.pencil") { _ in tastingCount >= 1 },
        Achievement(id: "blind-first", title: "Blindfolded", detail: "Finish a blind tasting", icon: "eye.slash.fill") { _ in !blindEntries.isEmpty },
        Achievement(id: "blind-80", title: "Palate of gold", detail: "Score 80 or more in a blind tasting", icon: "target") { _ in blindEntries.contains { ($0.score ?? 0) >= 80 } },
        Achievement(id: "blind-10", title: "Trained nose", detail: "Finish 10 blind tastings", icon: "checkmark.seal.fill") { _ in blindEntries.count >= 10 },
        Achievement(id: "countries-3", title: "Three countries", detail: "Taste wines from 3 countries", icon: "airplane") { _ in countryCount >= 3 },
        Achievement(id: "countries-10", title: "Around the world", detail: "Taste wines from 10 countries", icon: "globe.americas.fill") { _ in countryCount >= 10 },
    ]
}
