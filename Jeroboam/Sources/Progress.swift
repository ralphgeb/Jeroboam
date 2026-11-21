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
    var reminders = false
    var reminderHour = 19
    var morningFacts: Bool? = nil        // nil = on with reminders
    var factHour: Int? = nil
    var appearance = 0                    // 0 auto, 1 light, 2 dark
    var practiceSessions = 0
    var perfectLessons = 0
    var viewedGrapes: [String] = []
    var viewedRegions: [String] = []
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
        refreshStreakState()
    }

    private func save() {
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
        data.answered += 1
        if correct {
            data.correct += 1
            if let i = data.mistakes.firstIndex(of: cardID) { data.mistakes.remove(at: i) }
        } else {
            data.mistakes.removeAll { $0 == cardID }
            data.mistakes.append(cardID)
            if data.mistakes.count > 200 { data.mistakes.removeFirst(data.mistakes.count - 200) }
        }
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
            new.append(a)
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
    ]
}
