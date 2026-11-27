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
        w.confidence = "high"                                // sure, but the producer isn't on the label: wait for the photo
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: label))
        w.producer = "Domaine Les Cousins"                   // sure and printed
        XCTAssertTrue(WineRecognizer.textIsEnough(w, label: label))
        w.confidence = "low"
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: label))
    }

    private func sampleList() -> LabelMatcher {
        var m = LabelMatcher()
        m.add(name: "Ferrari Maximum Rosé", producer: "Ferrari", place: "Trentino Trento", appellation: "Trento")
        m.add(name: "Trento DOC \"Maximum Blanc de Blancs\" - Ferrari", producer: "Ferrari", place: "Trentino Trento", appellation: "Trento")
        m.add(name: "Domaine Humbert Charmes Chambertin Grand Cru", producer: "Domaine Humbert Frères", place: "Burgundy Charmes-Chambertin", appellation: "Charmes-Chambertin")
        m.add(name: "Domaine Humbert Gevrey Chambertin Vieilles Vignes", producer: "Domaine Humbert Frères", place: "Burgundy Gevrey-Chambertin", appellation: "Gevrey-Chambertin")
        m.add(name: "Domaine Humbert Fixin Vieilles Vignes", producer: "Domaine Humbert Frères", place: "Burgundy Fixin", appellation: "Fixin")
        m.add(name: "St Hallett Faith Shiraz Red Wine", producer: "St Hallett", place: "Barossa Valley", appellation: "Barossa Valley")
        m.add(name: "Bread & Butter - Chardonnay - California", producer: "Bread & Butter", place: "California", appellation: "California")
        return m
    }

    func testLabelFindsTheRightCuvee() {
        let m = sampleList()
        // Blanc de Blancs label: never the Rosé
        let bdb = m.match(lines: ["FERRARI", "MAXIMUM", "BLANC DE BLANCS", "TRENTO DOC"])
        XCTAssertEqual(bdb.map(LabelMatcher.displayName), "Maximum Blanc de Blancs")
        XCTAssertEqual(m.match(lines: ["Ferrari", "Maximum", "Rosé"])?.name, "Ferrari Maximum Rosé")
        // the appellation picks Gevrey over Fixin; "Grand Vin de Bourgogne" alone is not the Grand Cru
        XCTAssertEqual(m.match(lines: ["Domaine Humbert Frères", "Gevrey-Chambertin", "Vieilles Vignes", "Grand Vin de Bourgogne"])?.name,
                       "Domaine Humbert Gevrey Chambertin Vieilles Vignes")
        XCTAssertNil(m.match(lines: ["Domaine Humbert", "Grand Vin de Bourgogne"]))
        // an OCR slip in the producer's name
        XCTAssertEqual(m.match(lines: ["ST HALTETT", "FAITH", "SHIRAZ", "BAROSSA"])?.maker, "St Hallett")
        // a wine the list does not have
        XCTAssertNil(m.match(lines: ["Atibaia", "Les Cousins", "75cl"]))
        XCTAssertEqual(m.match(lines: ["BREAD & BUTTER", "CHARDONNAY", "2025"]).map(LabelMatcher.displayName), "Chardonnay")
        XCTAssertEqual(LabelMatcher.vintage(["Fundada en 1877", "CHARDONNAY 2025"]), "2025")
        // Guigal's address (Château d'Ampuis) is on every label: the Côtes du Rhône must not become their Côte-Rôtie
        var g = LabelMatcher()
        g.add(name: "E. Guigal - Château d'Ampuis", producer: "E. Guigal", place: "Rhône Valley Côte-Rôtie", appellation: "Côte-Rôtie")
        g.add(name: "Guigal Côtes du Rhône Red (France)", producer: "Guigal", place: "Rhône Valley Côtes du Rhône", appellation: "Côtes du Rhône")
        g.add(name: "Cotes du Rhone Blanc Guigal", producer: "Guigal", place: "Rhône Valley Côtes du Rhône", appellation: "Côtes du Rhône")
        let cdr = ["E.GUIGAL", "2016", "E.GUIGAL", "CÔTES DU RHÔNE", "Appellation Côtes du Rhône Contrôlée", "E.GUIGAL",
                   "ÉLEVÉ ET MIS EN BOUTEILLE PAR E.GUIGAL CHATEAU D'AMPUIS - RHONE - FRANCE"]
        XCTAssertEqual(g.match(lines: cdr)?.name, "Guigal Côtes du Rhône Red (France)")
        XCTAssertNil(g.match(lines: ["E.GUIGAL", "2016", "MIS EN BOUTEILLE PAR E.GUIGAL CHATEAU D'AMPUIS"]))   // the neck label only: not enough
        // a named cuvée beats the producer's plain wine of the same appellation
        g.add(name: "Guigal Côte-Rôtie", producer: "Guigal", place: "Rhône Valley Côte-Rôtie", appellation: "Côte-Rôtie")
        g.add(name: "Guigal Côte-Rôtie La Landonne", producer: "Guigal", place: "Rhône Valley Côte-Rôtie", appellation: "Côte-Rôtie")
        XCTAssertEqual(g.match(lines: ["E. GUIGAL", "LA LANDONNE", "CÔTE-RÔTIE", "2017"])?.name, "Guigal Côte-Rôtie La Landonne")
        // (Guigal's plain Côte-Rôtie is the one labelled "Brune et Blonde", so the plain wine is the right answer here)
        XCTAssertEqual(g.match(lines: ["E. GUIGAL", "CÔTE-RÔTIE", "Brune et Blonde", "2017"])?.name, "Guigal Côte-Rôtie")
    }

    func testChateauNameIsNotItsClassification() {
        var w = WineIdentity.empty
        w.found = true; w.producer = "Château Lynch-Bages"; w.name = "Grand Vin Grand Cru Classé"; w.region = "Pauillac, Bordeaux"
        XCTAssertEqual(WineRecognizer.chateauName(w), "Château Lynch-Bages")
        w.producer = "Chateau Angelus"; w.name = "Premier Grand Cru Classe B Saint-Emilion Grand Cru"; w.region = "Saint-Émilion, Bordeaux"
        XCTAssertEqual(WineRecognizer.chateauName(w), "Chateau Angelus")
        w.producer = "Château Lynch-Bages"; w.name = "Echo de Lynch-Bages"   // a real second wine keeps its name
        XCTAssertEqual(WineRecognizer.chateauName(w), "Echo de Lynch-Bages")
        w.producer = "Bargylus"; w.name = "Grand Vin de Syrie"              // not a château: untouched
        XCTAssertEqual(WineRecognizer.chateauName(w), "Grand Vin de Syrie")
    }

    func testFamousLabelsFoundInTheList() {
        var m = LabelMatcher()
        m.add(name: "Lynch Bages", producer: "Chateau Lynch-Bages", place: "Bordeaux Pauillac", appellation: "Pauillac")
        m.add(name: "Echo De Lynch Bages 17 Pauillac", producer: "Echo de Lynch Bages", place: "Bordeaux Pauillac", appellation: "Pauillac")
        m.add(name: "Blanc de Lynch Bages", producer: "Chateau Lynch-Bages", place: "Bordeaux Pauillac", appellation: "Pauillac")
        m.add(name: "Lopez de Heredia Rioja Bosconia Reserva", producer: "Lopez de Heredia", place: "Rioja", appellation: "")
        m.add(name: "Lopez de Heredia Rioja Bosconia Gran Reserva", producer: "Lopez de Heredia", place: "Rioja", appellation: "")
        XCTAssertEqual(m.match(lines: ["CHÂTEAU LYNCH-BAGES", "GRAND VIN", "GRAND CRU CLASSÉ EN 1855", "PAUILLAC", "2017"])?.name, "Lynch Bages")
        XCTAssertEqual(m.match(lines: ["VIÑA BOSCONIA", "RIOJA", "RESERVA", "R. LÓPEZ DE HEREDIA", "VIÑA TONDONIA S.A.", "HARO", "2012"])?.name,
                       "Lopez de Heredia Rioja Bosconia Reserva")
    }

    func testClassificationAloneIsNotEnough() {
        // a curved CHÂTEAU MARGAUX label read as "Château Nâteau" + "Premier Grand Cru Classé": wait for the photo
        var w = WineIdentity.empty
        w.found = true; w.producer = "Château Nâteau"; w.name = "Premier Grand Cru Classé"; w.confidence = "high"; w.region = "Saint-Émilion"
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: "NÂTEAU 2018 GRAND VIN PREMIER GRAND CRU CLASSE"))
        var m = LabelMatcher()
        m.add(name: "Chateau Margaux", producer: "Chateau Margaux", place: "Bordeaux Margaux", appellation: "Margaux")
        XCTAssertTrue(m.knows(["margaux"]))
        XCTAssertFalse(m.knows(["nateau"]))
        // Château Margaux is found from its label; a Château Palmer label (also "Margaux") never becomes Château Margaux
        m.add(name: "Chateau Palmer", producer: "Chateau Palmer", place: "Bordeaux Margaux", appellation: "Margaux")
        XCTAssertEqual(m.match(lines: ["CHÂTEAU MARGAUX", "2018", "GRAND VIN", "PREMIER GRAND CRU CLASSÉ"])?.maker, "Chateau Margaux")
        XCTAssertEqual(m.match(lines: ["CHÂTEAU PALMER", "MARGAUX", "2016", "APPELLATION MARGAUX CONTRÔLÉE"])?.maker, "Chateau Palmer")
    }

    func testRareNameWithoutProducer() {
        // La Pialade's label never prints Rayas: the rare name + its appellation find it; a common word never does
        var m = LabelMatcher()
        m.add(name: "Chateau Rayas Cotes du Rhone La Pialade", producer: "Chateau Rayas", place: "Rhône Valley Côtes du Rhône", appellation: "Côtes du Rhône")
        m.add(name: "Guigal Côtes du Rhône Red (France)", producer: "Guigal", place: "Rhône Valley Côtes du Rhône", appellation: "Côtes du Rhône")
        m.add(name: "Domaine Grand Veneur Côtes du Rhône Réserve", producer: "Domaine Grand Veneur", place: "Rhône Valley Côtes du Rhône", appellation: "Côtes du Rhône")
        let label = ["2015", "LA PIALADE", "CÔTES DU RHÔNE", "MIS EN BOUTEILLE PAR LE PROPRIÉTAIRE", "APPELLATION CÔTES-DU-RHÔNE CONTRÔLÉE", "13,5% Vol"]
        XCTAssertEqual(m.match(lines: label)?.maker, "Chateau Rayas")
        XCTAssertNil(m.match(lines: ["RÉSERVE", "CÔTES DU RHÔNE", "2019"]))   // "Réserve" is not a name only one producer uses
        // a confident answer whose producer is not on the label waits for the photo
        var w = WineIdentity.empty
        w.found = true; w.producer = "Château de la Gardine"; w.name = "La Pialade"; w.confidence = "high"
        XCTAssertFalse(WineRecognizer.textIsEnough(w, label: label.joined(separator: "\n")))
    }
}
