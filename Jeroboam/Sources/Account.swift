import SwiftUI
import CloudKit
import CryptoKit

/// iCloud sync, with no account and no sign-in: progress, profile and the journal follow the iCloud account the phone is
/// signed in to (Settings > Sync with iCloud, on by default).
///
/// - Progress, profile details and the avatar: the iCloud key-value store (small and immediate). The two phones' progress is
///   merged field by field, so neither ever goes backwards.
/// - Tastings and cellar bottles with their full-size photos: CloudKit, in the player's private database (one record per
///   tasting or bottle, the photo as an asset; no size cap of our own, it counts against the player's iCloud storage).
///   CloudKit needs the iCloud container `iCloud.com.ralphgeb.jero` in the build (Info.plist `JeroCloudKit` = 1, see
///   build-ios.yml). Builds without it keep the journal in the key-value store as before (text and small pictures).
@Observable
final class Account {
    static let shared = Account()

    /// Settings switch. On by default; turning it on fetches what iCloud has, then sends this phone's data.
    var syncEnabled: Bool = (UserDefaults.standard.object(forKey: "jero.icloudSync") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: "jero.icloudSync")
            if syncEnabled && !oldValue { CloudSync.shared.restore() }
        }
    }
    var restoring = false
    var lastSync: Date? = UserDefaults.standard.object(forKey: "jero.lastSync") as? Date
    /// True when the phone is signed in to iCloud (otherwise nothing can sync, whatever the switch says).
    var iCloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
    /// Kept for the call sites that ask whether syncing is on.
    var signedIn: Bool { syncEnabled }

    private init() {
        // Sign in with Apple is gone: forget the identifiers earlier versions stored
        for k in ["jero.appleUserID", "jero.appleEmail"] { UserDefaults.standard.removeObject(forKey: k) }
    }

    func markSynced() {
        lastSync = Date()
        UserDefaults.standard.set(lastSync, forKey: "jero.lastSync")
    }

    /// Settings > Erase all my data: everything on this phone and in iCloud. The app then starts again from the welcome screen.
    @MainActor
    func eraseEverything(progress: GameProgress, journal: JournalStore) async {
        await CloudSync.shared.eraseCloud()
        journal.cellar = []
        journal.entries = []
        try? FileManager.default.removeItem(at: JournalStore.photoDir)
        let d = UserDefaults.standard
        for (k, _) in d.dictionaryRepresentation() where k.hasPrefix("jero.") || k.hasPrefix("jeroboam.") {
            if k == Plus.key || k == Plus.storeKey { continue }   // a paid subscription is the App Store's to end, not ours
            d.removeObject(forKey: k)
        }
        lastSync = nil
        syncEnabled = true
        progress.data = ProgressData()
    }
}

/// The key-value half of iCloud sync (progress, profile, avatar; the journal too when CloudKit is not in the build),
/// and the switchboard for the CloudKit half (`JournalCloud`).
final class CloudSync {
    static let shared = CloudSync()
    private let kv = NSUbiquitousKeyValueStore.default
    private weak var progress: GameProgress?
    private weak var journal: JournalStore?
    private let profileKeys = ["jero.name", "jero.ageRange", "jero.experience", "jero.country", "jero.favorite"]
    private var pushWork: DispatchWorkItem?
    private var merging = false

    func start(_ progress: GameProgress, _ journal: JournalStore) {
        self.progress = progress
        self.journal = journal
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv, queue: .main) { [weak self] _ in
            self?.pull()
        }
        Task { @MainActor in JournalCloud.shared.journal = journal }
        // a new phone (or a reinstall) looks for its progress first: iCloud can take a few seconds to hand it over
        if !progress.data.onboarded && enabled { restore() } else { kv.synchronize(); pull(); syncJournal() }
    }

    var enabled: Bool { Account.shared.syncEnabled }

    /// Fetch what iCloud has first (it can take a few seconds on a new phone), send this phone's data only afterwards.
    func restore() {
        guard enabled else { return }
        Account.shared.restoring = true
        kv.synchronize()
        pull()
        syncJournal()
        for delay in [1.5, 4.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.kv.synchronize(); self?.pull() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.pull(); Account.shared.restoring = false; self?.pushAll()
        }
    }

    func syncNow() { kv.synchronize(); pull(); pushAll() }

    func pushProgress(_ raw: Data) { schedulePush() }
    func journalChanged() { schedulePush() }

    private func schedulePush() {
        guard enabled, !merging, !Account.shared.restoring else { return }
        pushWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.pushAll() }
        pushWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func syncJournal() {
        guard enabled, JournalCloud.configured else { return }
        Task { @MainActor in JournalCloud.shared.sync() }
    }

    private func isBlank(_ d: ProgressData) -> Bool { !d.onboarded && d.xp == 0 && d.lessons.isEmpty }

    private func encoded(_ d: ProgressData) -> Data? {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try? e.encode(d)
    }

    func pushAll() {
        guard enabled, !merging else { return }
        if let p = progress, !isBlank(p.data) {
            // never overwrite the other phone's progress: send the union of both
            let remote = kv.data(forKey: "progress").flatMap { try? JSONDecoder().decode(ProgressData.self, from: $0) }
            let merged = remote.map { ProgressData.merged(local: p.data, remote: $0) } ?? p.data
            if let raw = encoded(merged) { kv.set(raw, forKey: "progress") }
        }
        var profile: [String: String] = [:]
        for k in profileKeys { if let v = UserDefaults.standard.string(forKey: k), !v.isEmpty { profile[k] = v } }
        if !profile.isEmpty { kv.set(profile, forKey: "profile") }
        if let img = UserProfile.photo(), let small = Self.thumbnail(img) { kv.set(small, forKey: "avatar") }
        if let j = journal, j.persist, !JournalCloud.working {
            // until CloudKit has synced once (or in builds without it) the journal also travels in the key-value store
            // (1 MB in all, bottles with small pictures), so nothing stops syncing while the switch-over happens
            let entries = j.entries.map { e -> JournalEntry in var c = e; c.photo = nil; return c }
            var data: Data? = nil
            for (w, h, q) in [(288, 360, 0.6), (192, 240, 0.58), (144, 180, 0.55), (96, 120, 0.55)] as [(CGFloat, CGFloat, CGFloat)] {
                let cellar = j.cellar.map { b -> CellarBottle in
                    var c = b
                    if let img = JournalStore.image(b.photo) { c.thumb = Self.bottleThumb(img, w: w, h: h, quality: q) }
                    c.photo = nil
                    return c
                }
                data = try? JSONEncoder().encode(cellar)
                if let d = data, d.count < 600_000 { break }
            }
            if let d = try? JSONEncoder().encode(entries), d.count < 400_000 { kv.set(d, forKey: "journal") }
            if let d = data, d.count < 600_000 { kv.set(d, forKey: "cellar") }
        }
        kv.set(Array(Self.deleted), forKey: "deleted")
        kv.synchronize()
        syncJournal()
        Account.shared.markSynced()
    }

    // ids of tastings and bottles deleted on this phone, so they are not brought back by the merge
    static var deleted: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "jero.deletedIDs") ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(500)), forKey: "jero.deletedIDs") }
    }
    func noteDeleted(_ id: UUID) { Self.deleted.insert(id.uuidString); schedulePush() }

    private func pull() {
        guard enabled else { return }
        merging = true
        defer { merging = false }
        if let p = progress, let raw = kv.data(forKey: "progress"), let remote = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            let merged = ProgressData.merged(local: p.data, remote: remote)
            if encoded(merged) != encoded(p.data) { p.data = merged }
        }
        if let profile = kv.dictionary(forKey: "profile") as? [String: String] {
            for (k, v) in profile where (UserDefaults.standard.string(forKey: k) ?? "").isEmpty { UserDefaults.standard.set(v, forKey: k) }
            if let n = profile["jero.name"], let p = progress, p.data.name.isEmpty { p.data.name = n }
        }
        if UserProfile.photo() == nil, let data = kv.data(forKey: "avatar"), let img = UIImage(data: data) {
            UserProfile.savePhoto(img)
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "jero.avatarVersion") + 1, forKey: "jero.avatarVersion")
        }
        let gone = Self.deleted.union((kv.array(forKey: "deleted") as? [String]) ?? [])
        Self.deleted = gone
        // the journal from the key-value store: builds without CloudKit, and older versions' data on the way to CloudKit
        if let j = journal, j.persist {
            if let raw = kv.data(forKey: "journal"), let remote = try? JSONDecoder().decode([JournalEntry].self, from: raw) {
                let have = Set(j.entries.map(\.id))
                let add = remote.filter { !have.contains($0.id) && !gone.contains($0.id.uuidString) }
                if !add.isEmpty { j.entries = (j.entries + add).sorted { $0.date > $1.date } }
            }
            if let raw = kv.data(forKey: "cellar"), let remote = try? JSONDecoder().decode([CellarBottle].self, from: raw) {
                let have = Set(j.cellar.map(\.id))
                // restore each bottle's picture from its small iCloud copy
                func withPhoto(_ b: CellarBottle) -> CellarBottle {
                    var c = b
                    if let t = b.thumb, let img = UIImage(data: t) { c.photo = j.savePhoto(img, id: b.id) }
                    c.thumb = nil
                    return c
                }
                let add = remote.filter { !have.contains($0.id) && !gone.contains($0.id.uuidString) }.map(withPhoto)
                if !add.isEmpty { j.cellar = (j.cellar + add).sorted { $0.added > $1.added } }
                // a bottle already here without a picture gets it from iCloud
                for r in remote where r.thumb != nil {
                    if let i = j.cellar.firstIndex(where: { $0.id == r.id }), j.cellar[i].photo == nil { j.cellar[i].photo = withPhoto(r).photo }
                }
            }
        }
        Account.shared.markSynced()
    }

    /// Erase all my data: the key-value store and the CloudKit journal.
    @MainActor
    func eraseCloud() async {
        for k in ["progress", "profile", "avatar", "journal", "cellar", "deleted"] { kv.removeObject(forKey: k) }
        kv.synchronize()
        if JournalCloud.configured { await JournalCloud.shared.eraseAll() }
    }

    /// A small portrait picture of a bottle (key-value store fallback only).
    static func bottleThumb(_ image: UIImage, w: CGFloat = 288, h: CGFloat = 360, quality: CGFloat = 0.6) -> Data? {
        let size = CGSize(width: w, height: h)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let s = max(w / image.size.width, h / image.size.height)
        let drawn = CGSize(width: image.size.width * s, height: image.size.height * s)
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(x: (w - drawn.width) / 2, y: (h - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        return img.jpegData(compressionQuality: quality)
    }

    static func thumbnail(_ image: UIImage) -> Data? {
        let side: CGFloat = 600
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return img.jpegData(compressionQuality: 0.7)
    }
}

/// Tastings and cellar bottles in CloudKit (the player's private database, zone "Journal"): one record per tasting
/// ("Tasting") or bottle ("Bottle"), the JSON in `payload`, the full-size photo as the `photo` asset.
/// Only what changed since the last sync goes up; edits and deletions made on another phone come down.
@MainActor
final class JournalCloud {
    static let shared = JournalCloud()
    static let containerID = "iCloud.com.ralphgeb.jero"
    /// The build has the iCloud container (set together with its entitlement in build-ios.yml).
    nonisolated static var configured: Bool { (Bundle.main.object(forInfoDictionaryKey: "JeroCloudKit") as? String) == "1" }
    /// CloudKit has completed a sync on this phone (its record types exist in the container's production schema).
    nonisolated static var working: Bool { configured && UserDefaults.standard.bool(forKey: "jero.ck.ok") }

    weak var journal: JournalStore?
    private var running = false
    private var again = false
    private lazy var container = CKContainer(identifier: Self.containerID)
    private var db: CKDatabase { container.privateCloudDatabase }
    private let zoneID = CKRecordZone.ID(zoneName: "Journal", ownerName: CKCurrentUserDefaultName)

    // a fingerprint of what was last sent (or received) for each record, so unchanged tastings and bottles stay put
    private var sent: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "jero.ck.sent") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "jero.ck.sent") }
    }
    private var deletedSent: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "jero.ck.deletedSent") ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(1000)), forKey: "jero.ck.deletedSent") }
    }
    private var zoneReady: Bool {
        get { UserDefaults.standard.bool(forKey: "jero.ck.zone") }
        set { UserDefaults.standard.set(newValue, forKey: "jero.ck.zone") }
    }
    private var token: CKServerChangeToken? {
        get {
            guard let d = UserDefaults.standard.data(forKey: "jero.ck.token") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: d)
        }
        set {
            if let t = newValue, let d = try? NSKeyedArchiver.archivedData(withRootObject: t, requiringSecureCoding: true) {
                UserDefaults.standard.set(d, forKey: "jero.ck.token")
            } else {
                UserDefaults.standard.removeObject(forKey: "jero.ck.token")
            }
        }
    }

    /// Runs one sync (pull, then push); calls made while one is running are folded into one more pass.
    func sync() {
        guard Self.configured, Account.shared.syncEnabled else { return }
        if running { again = true; return }
        running = true
        Task {
            await run()
            running = false
            if again { again = false; sync() }
        }
    }

    private func run() async {
        guard let j = journal, j.persist else { return }
        do {
            guard try await container.accountStatus() == .available else { return }
            if !zoneReady {
                _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
                zoneReady = true
            }
            try await pull(j)
            try await push(j)
            UserDefaults.standard.set(true, forKey: "jero.ck.ok")
            Account.shared.markSynced()
        } catch let e as CKError where e.code == .changeTokenExpired {
            token = nil
        } catch let e as CKError where e.code == .zoneNotFound || e.code == .userDeletedZone {
            // the zone went away (erased on another phone): start clean, everything goes up again next time
            zoneReady = false; token = nil; sent = [:]
        } catch {
            // offline, iCloud full, throttled: the next change or launch tries again
        }
    }

    private static func fingerprint(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return e }()

    private func payload(_ e: JournalEntry) -> Data? { try? Self.encoder.encode(e) }
    private func payload(_ b: CellarBottle) -> Data? { var c = b; c.thumb = nil; return try? Self.encoder.encode(c) }

    // MARK: Down

    private func pull(_ j: JournalStore) async throws {
        var entries = j.entries, cellar = j.cellar
        var changed = false
        var sentNow = sent
        let gone = CloudSync.deleted
        var more = true
        while more {
            let r = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, result) in r.modificationResultsByID {
                guard case .success(let m) = result, let data = m.record["payload"] as? Data else { continue }
                let rid = m.record.recordID.recordName
                if gone.contains(rid) { continue }
                let fp = Self.fingerprint(data)
                let asset = m.record["photo"] as? CKAsset
                if m.record.recordType == "Tasting", var e = try? JSONDecoder().decode(JournalEntry.self, from: data) {
                    e.photo = Self.keepPhoto(asset, name: e.photo, id: e.id)
                    if let i = entries.firstIndex(where: { $0.id == e.id }) {
                        // take the other phone's edit unless this phone changed the tasting since the last sync
                        let local = payload(entries[i]).map(Self.fingerprint)
                        if local == sentNow[rid], local != fp { entries[i] = e; changed = true }
                    } else {
                        entries.append(e); changed = true
                    }
                    sentNow[rid] = fp
                } else if m.record.recordType == "Bottle", var b = try? JSONDecoder().decode(CellarBottle.self, from: data) {
                    b.photo = Self.keepPhoto(asset, name: b.photo, id: b.id)
                    if let i = cellar.firstIndex(where: { $0.id == b.id }) {
                        let local = payload(cellar[i]).map(Self.fingerprint)
                        if local == sentNow[rid], local != fp { cellar[i] = b; changed = true }
                        else if cellar[i].photo == nil, b.photo != nil { cellar[i].photo = b.photo; changed = true }
                    } else {
                        cellar.append(b); changed = true
                    }
                    sentNow[rid] = fp
                }
            }
            for d in r.deletions {
                let rid = d.recordID.recordName
                let before = entries.count + cellar.count
                entries.removeAll { $0.id.uuidString == rid }
                cellar.removeAll { $0.id.uuidString == rid }
                if entries.count + cellar.count != before { changed = true }
                sentNow[rid] = nil
            }
            token = r.changeToken
            more = r.moreComing
        }
        sent = sentNow
        if changed {
            // one assignment each, so the store saves once
            j.entries = entries.sorted { $0.date > $1.date }
            j.cellar = cellar.sorted { $0.added > $1.added }
        }
    }

    /// The downloaded photo is copied next to the others (a bigger copy replaces a small one from an older version).
    private static func keepPhoto(_ asset: CKAsset?, name: String?, id: UUID) -> String? {
        guard let src = asset?.fileURL else { return name }
        let file = name ?? (id.uuidString + ".jpg")
        let dest = JournalStore.photoDir.appendingPathComponent(file)
        let fm = FileManager.default
        let newSize = (try? fm.attributesOfItem(atPath: src.path)[.size] as? Int) ?? 0
        let oldSize = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? -1
        if newSize > oldSize {
            try? fm.removeItem(at: dest)
            try? fm.copyItem(at: src, to: dest)
        }
        return file
    }

    // MARK: Up

    private func push(_ j: JournalStore) async throws {
        var records: [CKRecord] = []
        var prints: [String: String] = [:]
        let sentNow = sent
        func add(type: String, id: UUID, data: Data?, photo: String?) {
            guard let data else { return }
            let rid = id.uuidString
            let fp = Self.fingerprint(data)
            if sentNow[rid] == fp { return }
            let rec = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: rid, zoneID: zoneID))
            rec["payload"] = data
            if let p = photo {
                let url = JournalStore.photoDir.appendingPathComponent(p)
                if FileManager.default.fileExists(atPath: url.path) { rec["photo"] = CKAsset(fileURL: url) }
            }
            records.append(rec)
            prints[rid] = fp
        }
        for e in j.entries { add(type: "Tasting", id: e.id, data: payload(e), photo: e.photo) }
        for b in j.cellar { add(type: "Bottle", id: b.id, data: payload(b), photo: b.photo) }
        let toDelete = CloudSync.deleted.subtracting(deletedSent).map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        guard !records.isEmpty || !toDelete.isEmpty else { return }

        var sentAfter = sentNow
        var deletedAfter = deletedSent
        // small batches: each request carries photos, and CloudKit limits the size of one request
        var start = 0
        while start < max(records.count, toDelete.count) {
            let saves = Array(records[min(start, records.count)..<min(start + 50, records.count)])
            let dels = Array(toDelete[min(start, toDelete.count)..<min(start + 50, toDelete.count)])
            let r = try await db.modifyRecords(saving: saves, deleting: dels, savePolicy: .allKeys, atomically: false)
            for (id, result) in r.saveResults {
                if case .success = result { sentAfter[id.recordName] = prints[id.recordName] }
            }
            for (id, result) in r.deleteResults {
                switch result {
                case .success: deletedAfter.insert(id.recordName); sentAfter[id.recordName] = nil
                case .failure(let e): if (e as? CKError)?.code == .unknownItem { deletedAfter.insert(id.recordName) }
                }
            }
            start += 50
        }
        sent = sentAfter
        deletedSent = deletedAfter
    }

    /// Erase all my data: the whole zone goes; on the next sync it is created again, empty.
    func eraseAll() async {
        _ = try? await db.modifyRecordZones(saving: [], deleting: [zoneID])
        UserDefaults.standard.removeObject(forKey: "jero.ck.ok")
        zoneReady = false
        token = nil
        sent = [:]
        deletedSent = []
    }
}

/// Settings card: iCloud sync on or off, when it last ran, and erasing everything.
struct AccountCard: View {
    @State private var account = Account.shared
    @Environment(GameProgress.self) private var progress
    @Environment(JournalStore.self) private var journal
    @State private var confirmErase = false
    @State private var erasing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: account.syncEnabled ? "checkmark.icloud.fill" : "icloud.slash")
                    .font(.system(size: 22)).foregroundStyle(Palette.wine)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync with iCloud").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(status).font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Sync with iCloud", isOn: $account.syncEnabled).labelsHidden().tint(Palette.wine)
            }
            HStack(spacing: 10) {
                if account.syncEnabled {
                    Button { CloudSync.shared.syncNow() } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 13.5, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 9).background(Capsule().fill(Palette.wineSoft)).foregroundStyle(Palette.wine)
                    }
                }
                Button(role: .destructive) { confirmErase = true } label: {
                    Text(erasing ? "Erasing…" : "Erase all my data").font(.jero(size: 13.5, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 9).background(Capsule().fill(Palette.cardAlt)).foregroundStyle(Palette.wrong)
                }
                .disabled(erasing)
            }
            .buttonStyle(.plain)
        }
        .cardStyle(padding: 16)
        .confirmationDialog("Erase all your data?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                erasing = true
                Task { await account.eraseEverything(progress: progress, journal: journal); erasing = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress, streak, tastings, cellar and photos are deleted from this iPhone and from iCloud. This can't be undone. A Jero Plus subscription is managed in your Apple account settings.")
        }
    }

    private var status: String {
        if !account.syncEnabled { return "Off. Your progress and journal stay on this iPhone only." }
        if !account.iCloudAvailable { return "Sign in to iCloud in the Settings app to keep your progress safe." }
        if account.restoring { return "Restoring your progress…" }
        if let d = account.lastSync { return "Your progress, tastings and cellar follow your iCloud account · " + d.formatted(date: .abbreviated, time: .shortened) }
        return "Your progress, tastings and cellar follow your iCloud account."
    }
}
