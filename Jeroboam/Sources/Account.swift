import SwiftUI
import AuthenticationServices

/// Sign in with Apple identity + iCloud key-value sync of progress, profile details and avatar.
/// No passwords and no server: the player's Apple ID is the account, iCloud carries the data to a new phone.
@Observable
final class Account {
    static let shared = Account()
    private(set) var userID: String? = UserDefaults.standard.string(forKey: "jero.appleUserID")
    private(set) var email: String? = UserDefaults.standard.string(forKey: "jero.appleEmail")
    var restoring = false
    var lastSync: Date? = UserDefaults.standard.object(forKey: "jero.lastSync") as? Date
    var signedIn: Bool { userID != nil }

    func signedIn(with credential: ASAuthorizationAppleIDCredential) {
        userID = credential.user
        UserDefaults.standard.set(credential.user, forKey: "jero.appleUserID")
        if let e = credential.email { email = e; UserDefaults.standard.set(e, forKey: "jero.appleEmail") }
        let given = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        if !given.isEmpty, (UserDefaults.standard.string(forKey: "jero.name") ?? "").isEmpty {
            UserDefaults.standard.set(given, forKey: "jero.name")
        }
        CloudSync.shared.restore()
    }

    func signOut() {
        userID = nil; email = nil
        UserDefaults.standard.removeObject(forKey: "jero.appleUserID")
        UserDefaults.standard.removeObject(forKey: "jero.appleEmail")
    }

    /// Apple can revoke the credential (e.g. the user stopped using Sign in with Apple for this app).
    func checkCredential() {
        guard let id = userID else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { state, _ in
            if state == .revoked || state == .notFound { DispatchQueue.main.async { self.signOut() } }
        }
    }

    func markSynced() {
        lastSync = Date()
        UserDefaults.standard.set(lastSync, forKey: "jero.lastSync")
    }
}

/// iCloud key-value store: small (1 MB), automatic, per Apple ID. Progress, profile, avatar, tastings and cellar
/// (text only, no photos) are saved there and merged back in on any phone signed in with the same Apple ID.
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
        kv.synchronize()
        pull()
        Account.shared.checkCredential()
    }

    var enabled: Bool { Account.shared.signedIn }

    /// After signing in: fetch what iCloud has first (it can take a few seconds on a new phone), push only afterwards.
    func restore() {
        Account.shared.restoring = true
        kv.synchronize()
        pull()
        for delay in [1.5, 4.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.kv.synchronize(); self?.pull() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.pull(); self?.pushAll(); Account.shared.restoring = false
        }
    }

    func syncNow() { kv.synchronize(); pull(); pushAll() }

    func pushProgress(_ raw: Data) { schedulePush() }
    func journalChanged() { schedulePush() }

    private func schedulePush() {
        guard enabled, !Account.shared.restoring else { return }
        pushWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.pushAll() }
        pushWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func isBlank(_ d: ProgressData) -> Bool { !d.onboarded && d.xp == 0 && d.lessons.isEmpty }

    func pushAll() {
        guard enabled, !merging else { return }
        if let p = progress, !isBlank(p.data) {
            let remote = kv.data(forKey: "progress").flatMap { try? JSONDecoder().decode(ProgressData.self, from: $0) }
            let behind = remote.map { $0.xp > p.data.xp || ($0.onboarded && !p.data.onboarded) } ?? false
            if !behind, let raw = try? JSONEncoder().encode(p.data) { kv.set(raw, forKey: "progress") }
        }
        var profile: [String: String] = [:]
        for k in profileKeys { if let v = UserDefaults.standard.string(forKey: k), !v.isEmpty { profile[k] = v } }
        if !profile.isEmpty { kv.set(profile, forKey: "profile") }
        if let img = UserProfile.photo(), let small = Self.thumbnail(img) { kv.set(small, forKey: "avatar") }
        if let j = journal, j.persist {
            let entries = j.entries.map { e -> JournalEntry in var c = e; c.photo = nil; return c }
            // each bottle keeps a small picture (three times the old size: 288 x 360); with a big cellar the pictures step
            // down in size until everything fits the 1 MB iCloud key-value limit
            var cellar = j.cellar
            var data: Data? = nil
            for (w, h, q) in [(288, 360, 0.6), (192, 240, 0.58), (144, 180, 0.55), (96, 120, 0.55)] as [(CGFloat, CGFloat, CGFloat)] {
                cellar = j.cellar.map { b -> CellarBottle in
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
            let adopt = (remote.onboarded && !p.data.onboarded) || remote.xp > p.data.xp
                || (remote.xp == p.data.xp && remote.lessons.count > p.data.lessons.count)
            if adopt { p.data = remote }
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
        if let j = journal, j.persist {
            if let raw = kv.data(forKey: "journal"), let remote = try? JSONDecoder().decode([JournalEntry].self, from: raw) {
                let have = Set(j.entries.map(\.id))
                let add = remote.filter { !have.contains($0.id) && !gone.contains($0.id.uuidString) }
                if !add.isEmpty { j.entries = (j.entries + add).sorted { $0.date > $1.date } }
            }
            if let raw = kv.data(forKey: "cellar"), let remote = try? JSONDecoder().decode([CellarBottle].self, from: raw) {
                let have = Set(j.cellar.map(\.id))
                // restore each bottle's picture from its tiny iCloud copy
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

    /// A small portrait picture of a bottle for the cellar (about 4–8 KB).
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

/// Profile card: sign in with Apple to keep progress safe across phones.
struct AccountCard: View {
    @State private var account = Account.shared
    @Environment(\.colorScheme) private var scheme
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if account.signedIn {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.icloud.fill").font(.system(size: 22)).foregroundStyle(Palette.wine)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in with Apple").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(account.restoring ? "Restoring your progress…" : account.lastSync.map { "Saved to iCloud · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Progress syncs with iCloud")
                            .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button { CloudSync.shared.syncNow() } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 13.5, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Palette.wineSoft)).foregroundStyle(Palette.wine)
                    }
                    Button(role: .destructive) { account.signOut() } label: {
                        Text("Sign out").font(.system(size: 13.5, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Palette.cardAlt)).foregroundStyle(Palette.ink)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "icloud").font(.system(size: 22)).foregroundStyle(Palette.wine)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep your progress safe").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("Sign in with Apple and your level, XP, streak, profile, tastings and cellar follow you to any phone. No password to remember.")
                            .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                SignInWithAppleButton(.signIn) { req in
                    req.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        if let c = auth.credential as? ASAuthorizationAppleIDCredential { account.signedIn(with: c) }
                    case .failure(let e):
                        if (e as? ASAuthorizationError)?.code != .canceled { error = "Sign in didn't work. Please try again." }
                    }
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if let error { Text(error).font(.system(size: 12)).foregroundStyle(Palette.wrong) }
            }
        }
        .cardStyle(padding: 16)
    }
}
