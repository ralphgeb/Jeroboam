import SwiftUI

struct ProfileView: View {
    @Environment(GameProgress.self) private var progress
    @Environment(JournalStore.self) private var journal
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss
    private var journalLookups: Int { journal.lookups }
    private var journalSpent: Double { journal.spentUSD }

    @State private var currencyCode = Currency.code
    @State private var showExtraAtlas = false
    @State private var widgetTheme = WidgetSettings.theme

    var body: some View {
        // measured here, not taken from the page: this screen opens in a sheet, whose width is its own
        GeometryReader { geo in
            content(width: geo.size.width)
        }
    }

    private func content(width: CGFloat) -> some View {
        NavigationStack {
            Group {
                if width >= AdaptiveLayout.twoPaneThreshold {
                    // Duo sideways: you and your progress on the left, the settings on the right
                    HStack(spacing: 0) {
                        ScrollView { VStack(alignment: .leading, spacing: 30) { leftColumn() }.padding(.horizontal, Metrics.margin).padding(.top, 8) }
                            .scrollIndicators(.hidden).frame(width: width / 2)
                            .environment(\.windowWidth, width / 2).environment(\.isWide, false)
                        Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                        ScrollView { VStack(alignment: .leading, spacing: 30) { rightColumn() }.padding(.horizontal, Metrics.margin).padding(.top, 8) }
                            .scrollIndicators(.hidden).frame(width: width / 2 - 0.5)
                            .environment(\.windowWidth, width / 2).environment(\.isWide, false)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            leftColumn()
                            rightColumn()
                        }
                        .padding(.horizontal, Metrics.margin)
                        .readable(720)
                    }
                    .scrollIndicators(.hidden)
                    .environment(\.windowWidth, width).environment(\.isWide, false)
                }
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { progress.checkAchievements() }
            .statusBarBackdrop()
            .plusSheetHost()
            .sheet(isPresented: $showExtraAtlas) { ExtraAtlasView() }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { progress.reset() }
            } message: {
                Text("Your streak, XP and finished lessons will be cleared.")
            }
        }
    }

    @ViewBuilder private func leftColumn() -> some View {
                    AboutYouSection().padding(.top, 16)
                    // Rank
                    VStack(alignment: .leading, spacing: 10) {
                      HStack(spacing: 16) {
                        RankEmblem(rankIndex: GameProgress.ranks.lastIndex { progress.data.xp >= $0.xp } ?? 0)
                        VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Your cellar · " + RankEmblem.bottles[min(7, GameProgress.ranks.lastIndex { progress.data.xp >= $0.xp } ?? 0)])
                        Text(progress.rank).font(.screenTitle).foregroundStyle(Palette.ink)
                        }
                      }
                        if let next = progress.nextRank {
                            VStack(alignment: .leading, spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Palette.line)
                                        Capsule().fill(Palette.wine).frame(width: geo.size.width * progress.rankProgress)
                                    }
                                }
                                .frame(height: 4)
                                Text("\(next.xp - progress.data.xp) XP to \(next.title)").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        stat("\(progress.data.streak)", "Day streak", "flame.fill", Palette.flame)
                        stat("\(progress.data.bestStreak)", "Best streak", "trophy", Palette.brass)
                        stat("\(progress.data.xp)", "Total XP", "sparkle", Palette.brass)
                        stat("\(progress.completedCount)/\(ContentStore.shared.totalLessons)", "Lessons", "book.closed", Palette.wine)
                        stat("\(Int((progress.accuracy * 100).rounded()))%", "Accuracy", "scope", Palette.sage)
                        stat("\(progress.data.freezes)", "Streak freezes", "snowflake", Palette.slate)
                    }

                    WeekStrip()

                    // Achievements
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(text: "Achievements")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .center, spacing: 18) {
                            ForEach(Achievement.all) { a in
                                let got = progress.data.achievements.contains(a.id)
                                VStack(spacing: 6) {
                                    AchievementBadge(achievement: a, unlocked: got, size: 78)
                                        .frame(width: 78, height: 78)
                                    Text(a.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(got ? Palette.ink : Palette.inkSoft)
                                        .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                                    Text(a.detail).font(.system(size: 10.5)).foregroundStyle(Palette.inkFaint)
                                        .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                    }

    }

    @ViewBuilder private func rightColumn() -> some View {
        let p = Bindable(progress)
                    PlusStatusCard()

                    // Settings
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: "Settings").padding(.bottom, 10)
                        settingRow("Daily goal") {
                            Picker("Daily goal", selection: p.data.dailyGoal) {
                                Text("Casual · 10 XP").tag(10)
                                Text("Regular · 20 XP").tag(20)
                                Text("Serious · 30 XP").tag(30)
                                Text("Intense · 50 XP").tag(50)
                            }
                            .tint(Palette.wine)
                        }
                        Hairline()
                        settingRow("Notifications") {
                            Toggle("", isOn: Binding(get: { progress.data.reminders }, set: { progress.setReminders($0) }))
                                .labelsHidden().tint(Palette.wine)
                        }
                        if progress.data.reminders {
                            Hairline()
                            settingRow("Morning fun fact") {
                                Toggle("", isOn: Binding(get: { progress.data.morningFacts ?? true }, set: {
                                    progress.data.morningFacts = $0; progress.scheduleReminder()
                                }))
                                .labelsHidden().tint(Palette.wine)
                            }
                            Hairline()
                            settingRow("Evening practice at") {
                                Picker("Time", selection: Binding(get: { progress.data.reminderHour }, set: {
                                    progress.data.reminderHour = $0
                                    progress.setReminders(true)
                                })) {
                                    ForEach([8, 12, 17, 18, 19, 20, 21], id: \.self) { h in Text(hourString(h)).tag(h) }
                                }
                                .tint(Palette.wine)
                            }
                        }
                        Hairline()
                        settingRow("Appearance") {
                            Picker("Appearance", selection: p.data.appearance) {
                                Text("Automatic").tag(0)
                                Text("Light").tag(1)
                                Text("Dark").tag(2)
                            }
                            .tint(Palette.wine)
                        }
                        Hairline()
                        settingRow("Currency") {
                            Picker("Currency", selection: Binding(get: { currencyCode }, set: { currencyCode = $0; Currency.code = $0 })) {
                                ForEach(Currency.choices, id: \.self) { c in Text("\(c) · \(Locale.current.localizedString(forCurrencyCode: c) ?? c)").tag(c) }
                            }
                            .tint(Palette.wine)
                        }
                        Hairline()
                        settingRow("Widgets") {
                            Picker("Widgets", selection: Binding(get: { widgetTheme }, set: { widgetTheme = $0; WidgetSettings.theme = $0 })) {
                                Text("Automatic").tag(0)
                                Text("White").tag(1)
                                Text("Dark").tag(2)
                            }
                            .tint(Palette.wine)
                        }
                        Hairline()
                        Button(role: .destructive) { confirmReset = true } label: {
                            Text("Reset progress").font(.system(size: 16)).foregroundStyle(Palette.wrong)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                        }
                    }

                    // maps for places that are not in the atlas
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(text: "More maps").padding(.bottom, 10)
                        Button { showExtraAtlas = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "map").font(.system(size: 16)).foregroundStyle(Palette.wine).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Maps beyond the atlas").font(.system(size: 16)).foregroundStyle(Palette.ink)
                                    Text("Wine places that are not in the course").font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(.vertical, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Only in TestFlight installs (sandbox receipt); hidden in App Store downloads.
                    if Distribution.isTestFlight {
                        DuoPreviewPicker()
                        VStack(alignment: .leading, spacing: 0) {
                            SectionTitle(text: "TestFlight").padding(.bottom, 10)
                            Button {
                                dismiss()
                                Task { try? await Task.sleep(for: .milliseconds(500)); progress.data.onboarded = false }
                            } label: { testRow("Replay the welcome", "arrow.counterclockwise") }
                            Hairline()
                            Button { Plus.shared.reset() } label: { testRow(Plus.shared.active ? "Reset Jero Plus (back to free)" : "Jero Plus is off", "creditcard") }
                                .disabled(!Plus.shared.active)
                            Hairline()
                            Button { AtlasQuota.reset() } label: { testRow("Reset the free atlas cards", "rectangle.stack") }
                            Hairline()
                            Button { Notifications.shared.sendTestFact() } label: { testRow("Send a fun fact now", "bell.badge") }
                        }
                    }

                    VStack(spacing: 6) {
                        Wordmark(size: 18)
                        if journalLookups > 0 {
                            Text("Wine lookups: \(journalLookups) · ≈ $\(String(format: "%.3f", journalSpent)) in AI cost")
                                .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                        }
                        Text("Course structure inspired by the WSET levels. Not affiliated with or endorsed by WSET.")
                            .font(.system(size: 11)).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10).padding(.bottom, 30)
    }

    private func hourString(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }

    private func stat(_ v: String, _ label: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(c).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(v).font(.numeric(20, .semibold)).foregroundStyle(Palette.ink)
                Text(label).font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
    }

    private func testRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Palette.wine).frame(width: 22)
            Text(title).font(.system(size: 16)).foregroundStyle(Palette.ink)
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func settingRow<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(title).font(.system(size: 16)).foregroundStyle(Palette.ink)
            Spacer()
            control()
        }
        .padding(.vertical, 8)
        .frame(minHeight: 48)
    }
}

/// The last seven days, with XP earned each day.
struct WeekStrip: View {
    @Environment(GameProgress.self) private var progress
    var body: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        let maxXP = max(progress.data.dailyGoal, days.map { progress.data.dailyXP[GameProgress.day($0)] ?? 0 }.max() ?? 0)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "This week")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.self) { d in
                    let xp = progress.data.dailyXP[GameProgress.day(d)] ?? 0
                    let isToday = cal.isDateInToday(d)
                    VStack(spacing: 8) {
                        Text(xp > 0 ? "\(xp)" : "").font(.numeric(10, .medium)).foregroundStyle(Palette.inkSoft).frame(height: 12)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(xp >= progress.data.dailyGoal ? Palette.wine : (xp > 0 ? Palette.wine.opacity(0.4) : Palette.line))
                            .frame(height: max(6, 70 * CGFloat(xp) / CGFloat(max(1, maxXP))))
                        Text(d.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 12, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Palette.ink : Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 112, alignment: .bottom)
            .cardStyle(padding: 16)
        }
    }
}

/// Jero Plus in the profile: what you have, or what it adds.
struct PlusStatusCard: View {
    var body: some View {
        if Plus.shared.active {
            HStack(spacing: 14) {
                SplashMark(color: .white, surface: Palette.cork).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jero Plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("Everything is unlocked. Thank you!").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Text("Manage").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                        .padding(.horizontal, 12).frame(height: 30).background(Capsule().fill(.white))
                }
            }
            .padding(16)
            .background(HeroCardBackground().clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)))
        } else {
            Button { PaywallPresenter.shared.show("Every level, the whole atlas and your journal.") } label: {
                HStack(spacing: 14) {
                    SplashMark(color: .white, surface: Palette.cork).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get Jero Plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        Text("Every level, every country, your journal · \(Plus.shared.price)/month")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .background(HeroCardBackground().clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)))
            }
            .buttonStyle(PressableStyle())
        }
    }
}
