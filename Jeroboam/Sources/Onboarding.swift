import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(GameProgress.self) private var progress
    @State private var step = 0
    @State private var level = 1
    @State private var goal = 20
    @State private var appear = false
    @State private var quiz = false
    @State private var account = Account.shared
    // welcome back (steps 10, 11, 12)
    @AppStorage("jero.avatarVersion") private var avatarVersion = 0
    @AppStorage("jero.name") private var storedName = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var placed: Int? = nil
    @State private var levelBefore = 1

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                if step > 0 && step < 10 {
                    HStack(spacing: 6) {
                        ForEach(1..<4) { i in
                            Capsule().fill(i <= step ? Palette.wine : Palette.line).frame(height: 3)
                        }
                    }
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 12)
                }
                Group {
                    switch step {
                    case 0: welcome
                    case 1: levelStep
                    case 2: goalStep
                    case 3: reminderStep
                    case 10: welcomeBack
                    case 11: pickUp
                    default: quizResult
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(step)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .fullScreenCover(isPresented: $quiz) {
            PlacementQuizView { result in
                if step >= 10 {
                    // coming back: the quiz can only open more levels, never take any away
                    if let result { levelBefore = currentLevel; placed = result; unlock(upTo: result); step = 12 }
                } else if let result { level = result; step = 2 }
                quiz = false
            }
        }
        // iCloud found this player's progress: go to the welcome back, from the first page after a short pause, or from the
        // middle of the new-player pages straight away
        .onChange(of: account.returning, initial: true) { _, back in
            guard back, step < 10 else { return }
            if step == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if step == 0 && account.returning { step = 10 } }
            } else {
                step = 10
            }
        }
        .onChange(of: photoItem) { _, it in
            guard let it else { return }
            Task {
                if let data = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    UserProfile.savePhoto(img)
                    avatarVersion += 1
                    CloudSync.shared.profileChanged()
                    Haptics.success()
                }
            }
        }
    }

    // MARK: Welcome back

    private var displayName: String {
        let n = storedName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? progress.data.name.trimmingCharacters(in: .whitespaces) : n
    }
    private var currentLevel: Int { max(progress.data.startLevel, progress.data.unlockedLevels.max() ?? 1) }

    private var welcomeBack: some View {
        VStack(spacing: 0) {
            Spacer()
            Avatar(size: 128, version: avatarVersion, name: displayName)
                .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 4))
                .shadow(color: Palette.wine.opacity(0.18), radius: 18, y: 8)
            Text(displayName.isEmpty ? "Welcome back" : "Welcome back, \(displayName)")
                .font(.jero(size: 30, weight: .bold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).padding(.top, 28)
            Text("Your progress, cellar and tastings came back with your iCloud account.")
                .font(.jero(size: 15.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.top, 8)
            HStack(spacing: 10) {
                stat("\(currentLevel)", "Level")
                stat("\(progress.data.xp)", "XP")
                stat("\(progress.data.lessons.count)", progress.data.lessons.count == 1 ? "Lesson" : "Lessons")
            }
            .padding(.top, 26)
            Spacer()
            VStack(spacing: 10) {
                Button("Continue") { Haptics.tap(); step = 11 }
                    .buttonStyle(PrimaryButtonStyle())
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(UserProfile.photo() == nil ? "Add a picture" : "Change picture", systemImage: "camera")
                        .font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.wine)
                        .frame(maxWidth: .infinity).frame(height: 46)
                }
                .id(avatarVersion)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.numeric(20, .semibold)).foregroundStyle(Palette.ink)
            Text(label).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }

    private var pickUp: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How would you like to pick up?").font(.jero(size: 28, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Carry on where you were, or see whether your level has gone up since.")
                    .font(.jero(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 36)
            VStack(spacing: 12) {
                choice("arrow.forward.circle", "Carry on where I left off",
                       "Level \(currentLevel), with everything you have done so far.") { finishReturning() }
                choice("sparkles", "Test my knowledge again",
                       "10 quick questions. If you have moved up, the next level opens; nothing you have is taken away.") { quiz = true }
            }
            .padding(.top, 28)
            Spacer()
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func choice(_ icon: String, _ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(Palette.wine).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.jero(size: 14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint).padding(.top, 4)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var quizResult: some View {
        let p = placed ?? levelBefore
        let up = p > levelBefore
        return VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.wineSoft).frame(width: 130, height: 130)
                Image(systemName: up ? "arrow.up.circle" : "checkmark.circle").font(.system(size: 50, weight: .light)).foregroundStyle(Palette.wine)
            }
            Text(up ? "You have moved up" : "Right where you are")
                .font(.jero(size: 30, weight: .bold)).foregroundStyle(Palette.ink).padding(.top, 30)
            Text(up ? "The quiz placed you at Level \(p). It is open now, next to everything you had."
                    : "The quiz placed you at Level \(p). You are on Level \(levelBefore), so nothing changes: carry on from there.")
                .font(.jero(size: 15.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.top, 10)
            Spacer()
            Button("Continue") { finishReturning() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func unlock(upTo n: Int) {
        guard n > currentLevel else { return }
        var d = progress.data
        for k in 1...n where !d.unlockedLevels.contains(k) { d.unlockedLevels.append(k) }
        d.startLevel = max(d.startLevel, n)
        progress.data = d
    }

    private func finishReturning() {
        Haptics.success()
        account.returning = false
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            BrandDroplet(size: 104)
                .scaleEffect(appear ? 1 : 0.85)
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 36)
            Text("Jero").font(.system(size: 52, weight: .bold)).kerning(-0.8).foregroundStyle(Palette.ink)
            Text("Learn wine. Taste better.")
                .font(.system(size: 16)).foregroundStyle(Palette.inkSoft).padding(.top, 2)
            VStack(alignment: .leading, spacing: 16) {
                bullet("graduationcap", "Three levels, from first sip to advanced study")
                bullet("map", "Illustrated maps of the world’s great regions")
                bullet("flame", "Short daily lessons that build a streak")
                bullet("camera", "A tasting journal that recognises your bottles")
            }
            .padding(.top, 44)
            .opacity(appear ? 1 : 0)
            Spacer()
            VStack(spacing: 10) {
                Button(account.returning ? "Continue" : "Get started") { step = account.returning ? 10 : 1 }
                    .buttonStyle(PrimaryButtonStyle())
                // a new phone looks for the player's progress in iCloud first (no sign-in: it follows the iCloud account);
                // when it is found, the app opens straight on the player's level
                if account.returning {
                    Text("We found your progress in iCloud.")
                        .font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
                        .frame(height: 46)
                } else if account.restoring {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Looking for your progress in iCloud…")
                            .font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
                    }
                    .frame(height: 46)
                } else {
                    Text("Your progress and journal follow your iCloud account.")
                        .font(.system(size: 12.5)).foregroundStyle(Palette.inkFaint)
                        .frame(height: 46)
                }
            }
            .padding(.horizontal, Metrics.margin).padding(.bottom, 16)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { appear = true } }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .light)).foregroundStyle(Palette.wine).frame(width: 24)
            Text(text).font(.jero(size: 15.5)).foregroundStyle(Palette.ink.opacity(0.85))
        }
    }

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 0) {
          ScrollView {
           VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Find your level").font(.serif(30)).foregroundStyle(Palette.ink)
                Text("Take the quiz and we'll place you, or pick a level yourself below.").font(.jero(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 30)
            // the quiz comes first: a big, inviting card at the top
            Button { Haptics.tap(); quiz = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "wineglass.fill").font(.system(size: 96)).foregroundStyle(.white.opacity(0.13)).rotationEffect(.degrees(14)).offset(x: 14, y: -6)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("TAKE A QUIZ TO KNOW YOUR LEVEL").font(.jero(size: 11.5, weight: .bold)).kerning(0.8)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        Text("Think you know wine?").font(.jero(size: 22, weight: .bold)).foregroundStyle(.white)
                        Text("10 quick questions, 3 minutes, a fun fact with every answer. Most people are surprised.")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.88)).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text("Start the quiz").font(.jero(size: 14.5, weight: .semibold))
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Palette.wine).padding(.horizontal, 16).frame(height: 38)
                        .background(Capsule().fill(.white)).padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.wine, Palette.wine.mix(with: .black, 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Palette.wine.opacity(0.25), radius: 14, y: 6)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 20)
            Text("OR CHOOSE YOURSELF").font(.jero(size: 11.5, weight: .bold)).kerning(1).foregroundStyle(Palette.inkFaint).padding(.top, 22)
            VStack(spacing: 10) {
                levelOption(1, "New to wine", "How wine is made, tasting and the great grapes.")
                levelOption(2, "I drink it, I'd like to understand it", "The wine world, food pairing, serving and scores.")
                levelOption(3, "I know a little", "Vineyard, winery, labels and more grapes.")
                levelOption(4, "Keen and studying", "Sparkling, sweet, viticulture, winemaking, Bordeaux and Burgundy.")
                levelOption(5, "Ready for the great regions", "Every classic region in depth, from the Rhône to the New World.")
            }
            .padding(.top, 10)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "gift.fill").font(.system(size: 15)).foregroundStyle(Palette.wine)
                Text("**Level \(level) will be unlocked for you.** Whichever level you choose is yours to use.")
                    .font(.system(size: 14)).foregroundStyle(Palette.ink.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wineSoft))
            .padding(.top, 14)
           }
          }
          .scrollIndicators(.hidden)
            Button("Continue with Level \(level)") { step = 2 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8).padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func levelOption(_ n: Int, _ title: String, _ detail: String) -> some View {
        Button {
            Haptics.tap()
            level = n
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Text("\(n)").font(.serif(26, .light)).foregroundStyle(Palette.level(n)).frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.jero(size: 14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: level == n ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(level == n ? Palette.wine : Palette.inkFaint)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(level == n ? Palette.wineSoft : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(level == n ? Palette.wine.opacity(0.6) : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick a daily goal").font(.serif(30)).foregroundStyle(Palette.ink)
                Text("A lesson takes about five minutes and earns 10–20 XP.").font(.jero(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 36)
            VStack(spacing: 0) {
                goalOption(10, "Casual", "About 5 minutes a day")
                Hairline()
                goalOption(20, "Regular", "About 10 minutes a day")
                Hairline()
                goalOption(30, "Serious", "About 15 minutes a day")
                Hairline()
                goalOption(50, "Intense", "About 25 minutes a day")
            }
            .cardStyle(padding: 4)
            .padding(.top, 30)
            Spacer()
            Button("Continue") { step = 3 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func goalOption(_ xp: Int, _ title: String, _ detail: String) -> some View {
        Button {
            Haptics.tap()
            goal = xp
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.jero(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Text("\(xp) XP").font(.numeric(15, .medium)).foregroundStyle(goal == xp ? Palette.wine : Palette.inkSoft)
                Image(systemName: goal == xp ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(goal == xp ? Palette.wine : Palette.inkFaint)
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var reminderStep: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.wineSoft).frame(width: 130, height: 130)
                Image(systemName: "bell").font(.system(size: 44, weight: .light)).foregroundStyle(Palette.wine)
            }
            Text("A gentle nudge?").font(.serif(30)).foregroundStyle(Palette.ink).padding(.top, 32)
            Text("A fun wine fact each morning, and a quiet nudge to practice in the evening. You can change this in your profile.")
                .font(.system(size: 15.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .lineSpacing(3).padding(.horizontal, 20).padding(.top, 10)
            Spacer()
            VStack(spacing: 10) {
                Button("Turn on notifications") { finish(reminders: true) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Not now") { finish(reminders: false) }
                    .buttonStyle(SecondaryButtonStyle(color: Palette.inkSoft))
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func finish(reminders: Bool) {
        var d = progress.data
        d.startLevel = level
        d.dailyGoal = goal
        for n in 1...level where !d.unlockedLevels.contains(n) { d.unlockedLevels.append(n) }
        d.onboarded = true
        progress.data = d
        if reminders { progress.setReminders(true) }
        Haptics.success()
    }
}
