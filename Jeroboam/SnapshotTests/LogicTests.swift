import XCTest
@testable import Jeroboam

/// Plain logic, no screens: the iCloud merge, the spaced review of mistakes, streaks and the blind-tasting score.
/// Runs with the snapshot tests (snapshots.yml).
@MainActor
final class LogicTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // keep the test run away from iCloud
        Account.shared.syncEnabled = false
    }

    private func day(_ offset: Int) -> String {
        GameProgress.day(Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }

    // MARK: iCloud merge

    func testMergeNeverGoesBackwards() {
        var local = ProgressData()
        local.onboarded = true; local.xp = 120; local.lessons["a"] = LessonRecord(completions: 1, bestAccuracy: 0.6, perfect: false, lastDate: "2026-01-01")
        local.achievements = ["first"]; local.dailyGoal = 20
        var remote = ProgressData()
        remote.onboarded = true; remote.xp = 300; remote.lessons["a"] = LessonRecord(completions: 2, bestAccuracy: 0.9, perfect: true, lastDate: "2026-01-03")
        remote.lessons["b"] = LessonRecord(completions: 1, bestAccuracy: 1, perfect: true, lastDate: "2026-01-02")
        remote.achievements = ["first", "streak7"]; remote.dailyGoal = 50

        let m = ProgressData.merged(local: local, remote: remote)
        XCTAssertEqual(m.xp, 300)
        XCTAssertEqual(Set(m.lessons.keys), ["a", "b"])
        XCTAssertEqual(m.lessons["a"]?.completions, 2)
        XCTAssertEqual(m.lessons["a"]?.bestAccuracy, 0.9)
        XCTAssertEqual(m.lessons["a"]?.perfect, true)
        XCTAssertEqual(Set(m.achievements), ["first", "streak7"])
        XCTAssertEqual(m.dailyGoal, 20, "this phone's own settings stay")

        // merging the other way round keeps the same learning record
        let back = ProgressData.merged(local: remote, remote: local)
        XCTAssertEqual(back.xp, 300)
        XCTAssertEqual(Set(back.lessons.keys), ["a", "b"])
    }

    func testMergeTakesStreakFromLastUsedPhone() {
        var local = ProgressData(); local.onboarded = true; local.streak = 3; local.lastActiveDay = "2026-03-01"; local.bestStreak = 9
        var remote = ProgressData(); remote.onboarded = true; remote.streak = 5; remote.lastActiveDay = "2026-03-04"
        let m = ProgressData.merged(local: local, remote: remote)
        XCTAssertEqual(m.streak, 5)
        XCTAssertEqual(m.lastActiveDay, "2026-03-04")
        XCTAssertEqual(m.bestStreak, 9)
    }

    func testNewPhoneAdoptsProgressAndSettings() {
        let fresh = ProgressData()
        var remote = ProgressData(); remote.onboarded = true; remote.dailyGoal = 50; remote.startLevel = 2; remote.xp = 40
        let m = ProgressData.merged(local: fresh, remote: remote)
        XCTAssertTrue(m.onboarded)
        XCTAssertEqual(m.dailyGoal, 50)
        XCTAssertEqual(m.startLevel, 2)
    }

    // MARK: Spaced review

    func testCorrectedMistakeComesBackTomorrow() {
        let p = GameProgress()
        p.data = ProgressData()
        p.recordAnswer(cardID: "q1", correct: false)
        XCTAssertEqual(p.dueReviews, ["q1"])

        p.recordAnswer(cardID: "q1", correct: true)
        XCTAssertFalse(p.data.mistakes.contains("q1"))
        XCTAssertEqual(p.data.reviews?["q1"]?.box, 1)
        XCTAssertEqual(p.data.reviews?["q1"]?.due, day(1))
        XCTAssertFalse(p.dueReviews.contains("q1"), "not due again today")
    }

    func testReviewClimbsBoxesThenGraduates() {
        let p = GameProgress()
        var d = ProgressData()
        d.reviews = ["q2": ReviewItem(box: 1, due: day(0))]
        p.data = d
        XCTAssertEqual(p.dueReviews, ["q2"])
        p.recordAnswer(cardID: "q2", correct: true)
        XCTAssertEqual(p.data.reviews?["q2"]?.box, 2)
        XCTAssertEqual(p.data.reviews?["q2"]?.due, day(3))

        p.data.reviews?["q2"] = ReviewItem(box: 4, due: day(-1))
        p.recordAnswer(cardID: "q2", correct: true)
        XCTAssertNil(p.data.reviews?["q2"], "remembered after the last interval: learned")
    }

    func testWrongReviewBecomesMistakeAgain() {
        let p = GameProgress()
        var d = ProgressData()
        d.reviews = ["q3": ReviewItem(box: 3, due: day(0))]
        p.data = d
        p.recordAnswer(cardID: "q3", correct: false)
        XCTAssertNil(p.data.reviews?["q3"])
        XCTAssertEqual(p.data.mistakes, ["q3"])
    }

    func testOldSavedProgressStillLoads() throws {
        // a save from before reviews existed has no "reviews" key
        var old = ProgressData(); old.xp = 77
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "reviews")
        let raw = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(ProgressData.self, from: raw)
        XCTAssertEqual(back.xp, 77)
        XCTAssertNil(back.reviews)
    }

    // MARK: Streaks

    func testMissedDayBreaksStreakWithoutFreeze() {
        let p = GameProgress()
        var d = ProgressData(); d.streak = 6; d.freezes = 0; d.lastActiveDay = day(-2)
        p.data = d
        p.refreshStreakState()
        XCTAssertEqual(p.data.streak, 0)
    }

    func testFreezeCoversOneMissedDay() {
        let p = GameProgress()
        var d = ProgressData(); d.streak = 6; d.freezes = 1; d.lastActiveDay = day(-2)
        p.data = d
        p.refreshStreakState()
        XCTAssertEqual(p.data.streak, 6)
    }

    // MARK: Blind tasting score

    func testBlindScoreIsOutOf100() {
        var e = JournalEntry()
        e.wine.grapes = ["Nebbiolo"]; e.wine.country = "Italy"; e.wine.tastingNotes = ["Rose", "Tar", "Cherry"]
        e.guessGrape = "nebbiolo"; e.guessCountry = "Italy"; e.aromas = ["Rose", "Tar", "Cherry"]
        XCTAssertTrue(TastingScore.grapeRight(e))
        XCTAssertTrue(TastingScore.countryRight(e))
        let s = TastingScore.total(e)
        XCTAssertGreaterThanOrEqual(s, 50)
        XCTAssertLessThanOrEqual(s, 100)

        var miss = e
        miss.guessGrape = "Riesling"; miss.guessCountry = "Germany"; miss.aromas = []
        XCTAssertFalse(TastingScore.grapeRight(miss))
        XCTAssertLessThan(TastingScore.total(miss), s)
    }

    func testLabelTextConfirmsAFairlySureAnswer() {
        var w = WineIdentity.empty
        w.found = true; w.producer = "Domaine Les Cousins"; w.name = "La Montagne Sacrée"; w.confidence = "medium"
        let label = "LES COUSINS\nLa Montagne Sacree\n2021\nVin de France"
        XCTAssertTrue(WineRecognizer.textIsEnough(w, label: label))
        w.producer = "Château Margaux"                       // a producer that is not on the label: look at the photo
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: label))
        w.confidence = "high"                                // Claude is sure
        XCTAssertTrue(WineRecognizer.textIsEnough(w, label: label))
        w.confidence = "low"
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: label))
    }
}
