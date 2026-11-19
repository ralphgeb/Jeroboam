import SwiftUI
import AuthenticationServices

/// Sign in with Apple identity + iCloud key-value sync of progress, profile details and avatar.
/// No passwords and no server: the player's Apple ID is the account, iCloud carries the data to a new phone.
@Observable
final class Account {
    static let shared = Account()
    private(set) var userID: String? = UserDefaults.standard.string(forKey: "jero.appleUserID")
    private(set) var email: String? = UserDefaults.standard.string(forKey: "jero.appleEmail")
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
        CloudSync.shared.syncNow()
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

/// iCloud key-value store: small (1 MB), automatic, per Apple ID. Progress merges by keeping the furthest-along copy.
final class CloudSync {
    static let shared = CloudSync()
    private let kv = NSUbiquitousKeyValueStore.default
    private weak var progress: GameProgress?
    private let profileKeys = ["jero.name", "jero.ageRange", "jero.experience", "jero.country", "jero.favorite"]

    func start(_ progress: GameProgress) {
        self.progress = progress
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv, queue: .main) { [weak self] _ in
            self?.pull()
        }
        kv.synchronize()
        pull()
        Account.shared.checkCredential()
    }

    var enabled: Bool { Account.shared.signedIn }

    func syncNow() { pull(); pushAll() }

    func pushProgress(_ raw: Data) {
        guard enabled else { return }
        kv.set(raw, forKey: "progress")
        kv.synchronize()
        Account.shared.markSynced()
    }

    func pushAll() {
        guard enabled else { return }
        if let p = progress, let raw = try? JSONEncoder().encode(p.data) { kv.set(raw, forKey: "progress") }
        var profile: [String: String] = [:]
        for k in profileKeys { if let v = UserDefaults.standard.string(forKey: k), !v.isEmpty { profile[k] = v } }
        kv.set(profile, forKey: "profile")
        if let img = UserProfile.photo(), let small = Self.thumbnail(img) { kv.set(small, forKey: "avatar") }
        kv.synchronize()
        Account.shared.markSynced()
    }

    private func pull() {
        guard enabled else { return }
        if let raw = kv.data(forKey: "progress"), let remote = try? JSONDecoder().decode(ProgressData.self, from: raw),
           let p = progress {
            // keep whichever copy is further along
            if remote.xp > p.data.xp || (remote.xp == p.data.xp && remote.lessons.count > p.data.lessons.count) {
                p.data = remote
            }
        }
        if let profile = kv.dictionary(forKey: "profile") as? [String: String] {
            for (k, v) in profile where (UserDefaults.standard.string(forKey: k) ?? "").isEmpty { UserDefaults.standard.set(v, forKey: k) }
        }
        if UserProfile.photo() == nil, let data = kv.data(forKey: "avatar"), let img = UIImage(data: data) {
            UserProfile.savePhoto(img)
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "jero.avatarVersion") + 1, forKey: "jero.avatarVersion")
        }
        Account.shared.markSynced()
    }

    static func thumbnail(_ image: UIImage) -> Data? {
        let side: CGFloat = 200
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
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
                        Text(account.lastSync.map { "Progress saved to iCloud · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Progress syncs with iCloud")
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
                        Text("Sign in with Apple and your XP, lessons, streak and profile follow you to a new phone. No password to remember.")
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
