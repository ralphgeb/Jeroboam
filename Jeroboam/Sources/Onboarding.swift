import SwiftUI

struct OnboardingView: View {
    @Environment(GameProgress.self) private var progress
    @State private var step = 0
    @State private var level = 1
    @State private var goal = 20
    @State private var appear = false

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                if step > 0 {
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
                    default: reminderStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(step)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
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
            Button("Get started") { step = 1 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.margin).padding(.bottom, 16)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { appear = true } }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .light)).foregroundStyle(Palette.wine).frame(width: 24)
            Text(text).font(.system(size: 15.5)).foregroundStyle(Palette.ink.opacity(0.85))
        }
    }

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Where would you like to start?").font(.serif(30)).foregroundStyle(Palette.ink)
                Text("You can switch levels at any time.").font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 36)
            VStack(spacing: 12) {
                levelOption(1, "New to wine", "Grapes, styles, tasting basics and food pairing.")
                levelOption(2, "I know a little", "Why wines taste the way they do: climate, winemaking and the major regions.")
                levelOption(3, "Ready for depth", "Viticulture, winemaking and the classic regions in detail; structured tasting.")
            }
            .padding(.top, 30)
            Spacer()
            Button("Continue") { step = 2 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 16)
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
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.system(size: 14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
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
                Text("A lesson takes about five minutes and earns 10–20 XP.").font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
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
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.system(size: 13.5)).foregroundStyle(Palette.inkSoft)
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
