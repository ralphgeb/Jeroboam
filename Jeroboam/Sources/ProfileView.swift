import SwiftUI

struct ProfileView: View {
    @Environment(GameProgress.self) private var progress
    @Environment(JournalStore.self) private var journal
    @State private var confirmReset = false
    @State private var limitTick = 0
    @Environment(\.dismiss) private var dismiss
    private var journalLookups: Int { journal.lookups }
    private var journalSpent: Double { journal.spentUSD }
    private var lookupLine: String {
        let today = String(format: "%.3f", DailyBudget.spent), cap = String(format: "%.2f", DailyBudget.limitUSD)
        let total = String(format: "%.3f", journalSpent)
        return (journalLookups > 0 ? "Wine lookups: \(journalLookups) · ≈ $\(total) in AI cost" : "No wine lookups yet") + " · today $\(today) of $\(cap)"
    }

    @State private var currencyCode = Currency.code
    @State private var showExtraAtlas = false
    @State private var settingsOpen = false
    @State private var showCredits = false
    @State private var showScanTimings = false
    @State private var showPrintCheck = false
    @State private var showFreezes = false
    @State private var sidePane = 0   // Duo sideways: 0 collection, 1 achievements on the right
    @Environment(\.coverClose) private var coverClose
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
                    // Duo sideways: you, the two cards and your settings on the left; the collection or the achievements open
                    // on the right, with a switch to flip between them
                    HStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                leftColumn()
                                CollectionAndAchievementsTiles(selected: sidePane) { p in withAnimation(.snappy) { sidePane = p } }
                                rightColumn()
                            }
                            .padding(.horizontal, Metrics.margin).padding(.top, 8).containerRelativeFrame(.horizontal).clipped()
                        }
                        .scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize, axes: .horizontal).frame(width: width / 2)
                        .environment(\.windowWidth, width / 2).environment(\.isWide, false)
                        Rectangle().fill(Palette.line.opacity(0.6)).frame(width: 0.5).ignoresSafeArea()
                        VStack(spacing: 0) {
                            Picker("Show", selection: $sidePane) {
                                Text("Collection").tag(0)
                                Text("Achievements").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, Metrics.margin).padding(.top, 10).padding(.bottom, 4)
                            if sidePane == 0 { CollectionView() } else { AchievementsView() }
                        }
                        .frame(width: width / 2 - 0.5)
                        .environment(\.windowWidth, width / 2).environment(\.isWide, false)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            leftColumn()
                            achievements()
                            rightColumn()
                        }
                        .padding(.horizontal, Metrics.margin)
                        .readable(720)
                        .containerRelativeFrame(.horizontal)
                        .clipped()
                    }
                    .scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .environment(\.windowWidth, width).environment(\.isWide, false)
                }
            }
            .padding(.top, coverClose != nil ? 30 : 0)
            .background(Palette.paper.ignoresSafeArea())
            .overlay(alignment: .topTrailing) {
                if let close = coverClose {
                    Button { close() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                            .frame(width: 34, height: 34).background(Circle().fill(Palette.card))
                            .overlay(Circle().strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
                    }
                    .accessibilityLabel("Close")
                    .padding(.top, 32).padding(.trailing, Metrics.margin)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CollectionRoute.self) { _ in CollectionView() }
            .navigationDestination(for: AchievementsRoute.self) { _ in AchievementsView() }
            .onAppear { progress.checkAchievements() }
            .statusBarBackdrop()
            .plusSheetHost()
            .sheet(isPresented: $showExtraAtlas) { ExtraAtlasView() }
            .sheet(isPresented: $showCredits) { CreditsView() }
            .sheet(isPresented: $showScanTimings) { ScanTimingsView() }
            .sheet(isPresented: $showPrintCheck) { FingerprintCheckView() }
            .sheet(isPresented: $showFreezes) { StreakFreezeSheet().presentationDetents([.medium, .large]) }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { progress.reset() }
            } message: {
                Text("Your streak, XP and finished lessons will be cleared.")
            }
        }
    }

    @ViewBuilder private func leftColumn() -> some View {
                    VStack(alignment: .leading, spacing: 12) {
                        AboutYouSection()
                        settingsCard()
                    }
                    .padding(.top, 16)
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
                                Text("\(next.xp - progress.data.xp) XP to \(next.title)").font(.jero(size: 13)).foregroundStyle(Palette.inkSoft)
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
                        // tap: how streak freezes work
                        Button { showFreezes = true } label: {
                            stat("\(progress.data.freezes) of \(progress.maxFreezes)", "Streak freezes · how they work", "snowflake", Palette.slate)
                        }
                        .buttonStyle(PressableStyle())
                    }

                    WeekStrip()

    }

    @ViewBuilder private func achievements() -> some View {
                    // two cards side by side: the stamp album and the badges, each opens its own page
                    CollectionAndAchievementsTiles()

    }

    @ViewBuilder private func rightColumn() -> some View {
                    PlusStatusCard()

                    // Only in TestFlight installs (sandbox receipt); hidden in App Store downloads.
                    if Distribution.isTestFlight {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionTitle(text: "TestFlight").padding(.bottom, 10)
                            Text(lookupLine)
                                .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).padding(.bottom, 8)
                            Text("iCloud photos: " + JournalCloud.status)
                                .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft).padding(.bottom, 8)
                                .textSelection(.enabled).id(limitTick)
                            Button { showExtraAtlas = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "map").font(.system(size: 15)).foregroundStyle(Palette.wine).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("More maps").font(.jero(size: 16)).foregroundStyle(Palette.ink)
                                        Text("Wine places that are not in the course").font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                                }
                                .padding(.vertical, 12).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Hairline()
                            Button { showScanTimings = true } label: { testRow("Scan timings", "stopwatch") }
                            Hairline()
                            Button { showPrintCheck = true } label: { testRow("Fingerprint check", "viewfinder") }
                            Hairline()
                            DuoPreviewPicker().padding(.vertical, 12)
                            Hairline()
                            Button {
                                if let c = coverClose { c() } else { dismiss() }
                                Task { try? await Task.sleep(for: .milliseconds(500)); progress.data.onboarded = false }
                            } label: { testRow("Replay the welcome", "arrow.counterclockwise") }
                            Hairline()
                            Button { Plus.shared.reset() } label: { testRow(Plus.shared.active ? "Reset Jero Plus (back to free)" : "Jero Plus is off", "creditcard") }
                                .disabled(!Plus.shared.active)
                            Hairline()
                            Button { AtlasQuota.reset() } label: { testRow("Reset the free atlas cards", "rectangle.stack") }
                            Hairline()
                            Button { Notifications.shared.sendTestFact() } label: { testRow("Send a fun fact now", "bell.badge") }
                            Hairline()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Badge animations").font(.jero(size: 16)).foregroundStyle(Palette.ink)
                                Text("Tap the play button to see one. Tap the circle to make it the one the app uses.")
                                    .font(.system(size: 12.5)).foregroundStyle(Palette.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            ForEach(BadgeStyle.allCases) { st in
                                HStack(spacing: 12) {
                                    Button { BadgeStyle.active = st; limitTick += 1 } label: {
                                        Image(systemName: BadgeStyle.active == st ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 20)).foregroundStyle(Palette.wine)
                                    }
                                    .buttonStyle(.plain).accessibilityLabel("Use " + st.title)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(st.title).font(.jero(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                                        Text(st.blurb).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 6)
                                    Button {
                                        let a = Achievement.all.first { $0.id == "streak-7" } ?? Achievement.all[0]
                                        BadgeCelebration.shared.play(a, date: Date(), style: st)
                                    } label: {
                                        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.onWine)
                                            .frame(width: 38, height: 32).background(Capsule().fill(Palette.wine))
                                    }
                                    .buttonStyle(.plain).accessibilityLabel("Play " + st.title)
                                }
                                .padding(.vertical, 8)
                                Hairline()
                            }
                            .id(limitTick)
                            Button { DailyBudget.testLimit.toggle(); limitTick += 1 } label: {
                                testRow(DailyBudget.testLimit ? "Limit reached (tap to switch off)" : "Pretend today's limit is reached", "hand.raised")
                            }
                            .id(limitTick)
                        }
                    }

                    VStack(spacing: 6) {
                        Wordmark(size: 18)
                        Text("Jero™").font(.jero(size: 12, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                        Text("Course structure inspired by the WSET levels. Not affiliated with or endorsed by WSET.")
                            .font(.system(size: 11)).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10).padding(.bottom, 30)
    }

    /// All the settings in one card that opens like "About you", right under it.
    @ViewBuilder private func settingsCard() -> some View {
        let p = Bindable(progress)
        GroupCard {
            Button { withAnimation(.easeInOut(duration: 0.2)) { settingsOpen.toggle() } } label: {
                HStack {
                    Image(systemName: "gearshape").foregroundStyle(Palette.wine)
                    Text("Settings").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft).rotationEffect(.degrees(settingsOpen ? 90 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 14).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if settingsOpen {
                Hairline()
                VStack(alignment: .leading, spacing: 0) {
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
                        settingRow("Drinking-window alerts") {
                            Toggle("", isOn: Binding(get: { DrinkAlerts.enabled }, set: {
                                DrinkAlerts.enabled = $0; limitTick += 1; progress.scheduleReminder()
                            }))
                            .labelsHidden().tint(Palette.wine).id(limitTick)
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
                    settingRow("Widgets") {
                        Picker("Widgets", selection: Binding(get: { widgetTheme }, set: { widgetTheme = $0; WidgetSettings.theme = $0 })) {
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
                    Button { showCredits = true } label: {
                        HStack {
                            Text("Map and photo credits").font(.jero(size: 16)).foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                        }
                        .padding(.vertical, 14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline()
                    Button(role: .destructive) { confirmReset = true } label: {
                        Text("Reset progress").font(.jero(size: 16)).foregroundStyle(Palette.wrong)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
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
                Text(label).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
    }

    private func testRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Palette.wine).frame(width: 22)
            Text(title).font(.jero(size: 16)).foregroundStyle(Palette.ink)
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func settingRow<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(title).font(.jero(size: 16)).foregroundStyle(Palette.ink)
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
                    Text("Jero Plus").font(.jero(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("Everything is unlocked. Thank you!").font(.jero(size: 13)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Text("Manage").font(.jero(size: 13, weight: .semibold)).foregroundStyle(Palette.bordeaux)
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
                        Text("Get Jero Plus").font(.jero(size: 16, weight: .semibold)).foregroundStyle(.white)
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

/// How streak freezes work (Profile > Streak freezes).
struct StreakFreezeSheet: View {
    @Environment(GameProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(eyebrow: "Your streak", title: "Streak freezes",
                                 subtitle: "A freeze keeps your streak alive when you miss a day.")
                    HStack(spacing: 8) {
                        ForEach(0..<progress.maxFreezes, id: \.self) { i in
                            Image(systemName: "snowflake").font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(i < progress.data.freezes ? Palette.slate : Palette.inkFaint.opacity(0.5))
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(i < progress.data.freezes ? Palette.slate.opacity(0.12) : Palette.cardAlt))
                        }
                        Text("You have \(progress.data.freezes) of \(progress.maxFreezes)").font(.jero(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.ink).padding(.leading, 6)
                    }
                    if progress.freezeCoversYesterday {
                        Label("A freeze is covering yesterday. Do a lesson today to keep your streak.", systemImage: "snowflake")
                            .font(.jero(size: 14, weight: .medium)).foregroundStyle(Palette.slate)
                    }
                    GroupCard {
                        row("calendar.badge.exclamationmark", "Miss one day", "A freeze covers it by itself; it is used when you do your next lesson.", false)
                        row("xmark.circle", "Miss two days or more", "The streak starts again, freeze or not.", false)
                        row("flame.fill", "7 days in a row", "Earn a freeze every 7 days of streak.", false)
                        row("rosette", "Finish a level", "Earn a freeze when a new level opens.", false)
                        row("checkmark.seal", "Pass a mock exam", "70% or more earns a freeze (once a week).", false)
                        row("sparkles", "Hold up to \(progress.maxFreezes)", Plus.shared.active ? "Jero Plus lets you hold 3." : "Hold 2, or 3 with Jero Plus.", true)
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func row(_ icon: String, _ title: String, _ detail: String, _ last: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Palette.slate).frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 48) } }
    }
}
