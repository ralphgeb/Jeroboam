import SwiftUI

/// What a lesson session is made of: a list of cards plus where it came from.
struct Session: Identifiable {
    let id = UUID()
    let title: String
    let lessonID: String?        // nil for practice
    let cards: [Card]
    var accent: Color = Palette.wine
}

/// Plays a session card by card, with feedback and an end screen.
struct LessonPlayer: View {
    let session: Session
    var onFinish: () -> Void = {}

    @Environment(GameProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Card] = []
    @State private var index = 0
    @State private var answeredCount = 0
    @State private var firstTryCorrect = 0
    @State private var questionTotal = 0
    @State private var retried: Set<String> = []
    @State private var feedback: Feedback? = nil
    @State private var finished = false
    @State private var reward: GameProgress.Reward? = nil
    @State private var combo = 0
    @State private var confirmQuit = false
    @State private var started = Date()
    @State private var panelHeight: CGFloat = 200

    struct Feedback: Equatable {
        let correct: Bool
        let answer: String?
        let explain: String?
        let visual: String?
    }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if finished {
                LessonComplete(session: session, accuracy: accuracy, reward: reward, seconds: Int(Date().timeIntervalSince(started))) {
                    onFinish()
                    dismiss()
                }
                .transition(.opacity)
            } else if index < queue.count {
                VStack(spacing: 0) {
                    header
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                CardView(card: queue[index], locked: feedback != nil, onAnswer: answer)
                                    .id(queue[index].id + "\(index)")
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 12)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                            removal: .move(edge: .leading).combined(with: .opacity)))
                                Color.clear.frame(height: 1).id("cardEnd")
                                // room for the feedback panel, so the chosen answer is never hidden under it
                                Color.clear.frame(height: feedback == nil ? 140 : panelHeight + 16)
                            }
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: feedback) { _, fb in
                            guard fb != nil else { return }
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("cardEnd", anchor: .bottom) }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if queue[index].kind == .learn && feedback == nil {
                        Button("Continue") { advance() }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, Metrics.margin)
                            .padding(.bottom, 12)
                            .background(LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper], startPoint: .top, endPoint: .center)
                                .ignoresSafeArea())
                    }
                }
                .overlay(alignment: .bottom) {
                    if let fb = feedback {
                        FeedbackPanel(feedback: fb, combo: combo) { advance() }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: index)
        .animation(.spring(response: 0.38, dampingFraction: 0.9), value: feedback)
        .animation(.easeInOut(duration: 0.3), value: finished)
        .onAppear {
            if queue.isEmpty {
                queue = session.cards
                questionTotal = session.cards.filter(\.isQuestion).count
            }
            #if DEBUG
            if DebugScreens.autoFinish {
                firstTryCorrect = max(0, questionTotal - 1)
                finish()
            } else if DebugScreens.autoAnswerWrong, let c = queue.first, c.isQuestion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    answer(false, c.options?[safe: c.answer ?? 0] ?? c.answers?.joined(separator: ", "))
                }
            }
            #endif
        }
        .confirmationDialog("Leave this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave lesson", role: .destructive) { dismiss() }
            Button("Keep learning", role: .cancel) {}
        } message: {
            Text("Your progress in this lesson will be lost.")
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                if answeredCount == 0 && index == 0 { dismiss() } else { confirmQuit = true }
            } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.inkSoft)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close lesson")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(height: 6)
                    Capsule().fill(session.accent)
                        .frame(width: max(6, geo.size.width * progressFraction), height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressFraction)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 32)
            if combo >= 3 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 12))
                    Text("\(combo)").font(.numeric(14, .semibold))
                }
                .foregroundStyle(Palette.flame)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.spring(), value: combo >= 3)
    }

    private var progressFraction: CGFloat {
        guard !queue.isEmpty else { return 0 }
        return CGFloat(index) / CGFloat(queue.count)
    }

    private var accuracy: Double {
        questionTotal == 0 ? 1 : Double(firstTryCorrect) / Double(questionTotal)
    }

    private func answer(_ correct: Bool, _ correctText: String?) {
        let card = queue[index]
        let isRetry = retried.contains(card.id)
        progress.recordAnswer(cardID: card.id, correct: correct)
        answeredCount += 1
        if correct {
            if !isRetry { firstTryCorrect += 1 }
            combo += 1
            Haptics.success()
        } else {
            combo = 0
            Haptics.error()
            if !isRetry {
                retried.insert(card.id)
                queue.append(card)   // try it again at the end, Duolingo-style
            }
        }
        feedback = Feedback(correct: correct, answer: correct ? nil : correctText, explain: card.explain, visual: card.visual)
    }

    private func advance() {
        feedback = nil
        if index + 1 < queue.count {
            index += 1
        } else {
            finish()
        }
    }

    private func finish() {
        let base = session.lessonID == nil ? 8 : 10
        let xp = base + firstTryCorrect + (accuracy >= 0.999 && questionTotal > 0 ? 5 : 0)
        if let id = session.lessonID {
            progress.completeLesson(id, accuracy: accuracy)
        } else {
            progress.data.practiceSessions += 1
        }
        reward = progress.award(xp: xp)
        finished = true
        Haptics.success()
    }
}

// MARK: - Feedback panel

struct FeedbackPanel: View {
    let feedback: LessonPlayer.Feedback
    let combo: Int
    let onContinue: () -> Void
    @State private var expanded = false

    var body: some View {
        let tint = feedback.correct ? Palette.correct : Palette.wrong
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: feedback.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
                Text(feedback.correct ? praise : "Not quite")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }
            if let a = feedback.answer {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Correct answer", color: tint)
                    Text(rich(a)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                }
            }
            if let e = feedback.explain {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rich(e)).font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.85)).lineSpacing(2.5)
                        .lineLimit(expanded ? nil : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if expanded, let v = feedback.visual, !v.hasPrefix("map"), !v.hasPrefix("glassonly") {
                        VisualView(spec: v, compact: true)
                    }
                    if !expanded && e.count > 90 {
                        Button("Why?") { withAnimation(.easeOut(duration: 0.2)) { expanded = true } }
                            .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(tint)
                    }
                }
            }
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(color: tint))
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(feedback.correct ? Palette.correctBG : Palette.wrongBG)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.06), radius: 16, y: -4)
        )
    }

    private var praise: String {
        if combo >= 5 { return "\(combo) in a row" }
        return ["Correct", "Exactly", "Well tasted", "Spot on", "Nicely done"][abs(feedback.explain?.count ?? 0) % 5]
    }
}

// MARK: - Cards

struct CardView: View {
    let card: Card
    let locked: Bool
    let onAnswer: (Bool, String?) -> Void

    var body: some View {
        switch card.kind {
        case .learn: LearnCard(card: card)
        case .choice: ChoiceCard(card: card, locked: locked, onAnswer: onAnswer)
        case .tf: TrueFalseCard(card: card, locked: locked, onAnswer: onAnswer)
        case .blank: BlankCard(card: card, locked: locked, onAnswer: onAnswer)
        case .match: MatchCard(card: card, locked: locked, onAnswer: onAnswer)
        }
    }
}

struct LearnCard: View {
    let card: Card
    /// Guidebook numbering: shows "Topic 01" above the title instead of "Learn".
    var topic: Int? = nil
    @Environment(\.isWide) private var isWide

    var body: some View {
        if isWide, let v = card.visual {
            // wide window (foldable opened flat, or sideways): picture on the left, writing on the right
            HStack(alignment: .top, spacing: 32) {
                VisualView(spec: v).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { heading; text }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                heading
                if let v = card.visual {
                    VisualView(spec: v).padding(.vertical, 4)
                }
                text
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(topic.map { String(format: "Topic %02d", $0) } ?? "Learn", color: Palette.wine)
            if let t = card.title {
                Text(t).font(.system(size: 26, weight: .bold)).kerning(-0.3).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var text: some View {
        if let b = card.body {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(b.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                    paragraph(para)
                }
            }
        }
    }

    @ViewBuilder private func paragraph(_ p: String) -> some View {
        if p.hasPrefix("- ") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(p.components(separatedBy: "\n").map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(Palette.wine).frame(width: 4.5, height: 4.5).offset(y: -3)
                        Text(rich(line)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            Text(rich(p)).font(.system(size: 16)).foregroundStyle(Palette.ink.opacity(0.88)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct QuestionHeader: View {
    let label: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(label)
            Text(rich(text)).font(.system(size: 21, weight: .semibold)).foregroundStyle(Palette.ink).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChoiceCard: View {
    let card: Card
    let locked: Bool
    let onAnswer: (Bool, String?) -> Void
    @State private var order: [Int] = []
    @State private var picked: Int? = nil

    var body: some View {
        let options = card.options ?? []
        // wine-color answers get a small glass of that color, unless the question itself shows the glass
        let showColorGlasses = !(card.visual ?? "").hasPrefix("glass")
        VStack(alignment: .leading, spacing: 22) {
            QuestionHeader(label: "Choose the best answer", text: card.question ?? "")
            if let v = card.visual, v.hasPrefix("map") || v.hasPrefix("glassonly") || v.hasPrefix("grape") || v.hasPrefix("colors") || v.hasPrefix("diagram") {
                VisualView(spec: v, compact: true, hideAnswers: true)
            }
            VStack(spacing: 10) {
                ForEach(order, id: \.self) { i in
                    Button {
                        guard !locked, picked == nil else { return }
                        picked = i
                        let correct = i == card.answer
                        onAnswer(correct, options[safe: card.answer ?? 0])
                    } label: {
                        HStack(spacing: 12) {
                            if showColorGlasses, let c = ContentStore.shared.library.colors.first(where: { $0.name.caseInsensitiveCompare(options[i]) == .orderedSame }) {
                                SilhouetteGlass(shape: c.family == "red" ? .red : .white, color: Color(hex: c.hex), fill: 0.55)
                                    .frame(width: 18, height: 30)
                            }
                            Text(rich(options[i])).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if let p = picked {
                                if i == card.answer { Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)) }
                                else if i == p { Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)) }
                            }
                        }
                    }
                    .buttonStyle(TileStyle(state: state(i)))
                    .disabled(locked)
                }
            }
        }
        .onAppear {
            if order.isEmpty { order = Array(options.indices).shuffled() }
        }
    }

    private func state(_ i: Int) -> TileStyle.TileState {
        guard let p = picked else { return .idle }
        if i == card.answer { return .correct }
        if i == p { return .wrong }
        return .disabled
    }
}

struct TrueFalseCard: View {
    let card: Card
    let locked: Bool
    let onAnswer: (Bool, String?) -> Void
    @State private var picked: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            QuestionHeader(label: "True or false", text: card.question ?? "")
            if let v = card.visual, v.hasPrefix("map") || v.hasPrefix("glassonly") || v.hasPrefix("grape") {
                VisualView(spec: v, compact: true, hideAnswers: true)
            }
            HStack(spacing: 12) {
                option(true)
                option(false)
            }
        }
    }

    private func option(_ value: Bool) -> some View {
        Button {
            guard !locked, picked == nil else { return }
            picked = value
            onAnswer(value == card.truth, (card.truth ?? true) ? "True" : "False")
        } label: {
            Text(value ? "True" : "False").frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(TileStyle(state: state(value)))
    }

    private func state(_ v: Bool) -> TileStyle.TileState {
        guard let p = picked else { return .idle }
        if v == card.truth { return .correct }
        if v == p { return .wrong }
        return .disabled
    }
}

/// Fill in the blank(s) from a word bank. Blanks are written as "___" in the question.
struct BlankCard: View {
    let card: Card
    let locked: Bool
    let onAnswer: (Bool, String?) -> Void
    @State private var filled: [String?] = []
    @State private var bank: [String] = []
    @State private var checked = false

    private var answers: [String] { card.answers ?? [] }
    private var pieces: [String] { (card.question ?? "").components(separatedBy: "___") }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Eyebrow("Fill in the blank")
            sentence
            if let v = card.visual, v.hasPrefix("map") || v.hasPrefix("glassonly") || v.hasPrefix("grape") {
                VisualView(spec: v, compact: true, hideAnswers: true)
            }
            Hairline()
            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(bank, id: \.self) { w in
                    let used = filled.contains(where: { $0 == w })
                    Button {
                        guard !checked, !used, let i = filled.firstIndex(where: { $0 == nil }) else { return }
                        Haptics.tap()
                        filled[i] = w
                    } label: {
                        Text(w)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(used ? Color.clear : Palette.ink)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(used ? Palette.cardAlt : Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(used ? Color.clear : Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !checked {
                Button("Check") { check() }
                    .buttonStyle(PrimaryButtonStyle(enabled: filled.allSatisfy { $0 != nil } && !filled.isEmpty))
                    .disabled(!filled.allSatisfy { $0 != nil } || filled.isEmpty)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            if bank.isEmpty {
                var words = card.options ?? []
                for a in answers where !words.contains(a) { words.append(a) }
                bank = words.shuffled()
                filled = Array(repeating: nil, count: max(1, pieces.count - 1))
            }
        }
    }

    private var sentence: some View {
        FlowLayout(spacing: 6, lineSpacing: 12) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, t in
                switch t {
                case .word(let w):
                    Text(w).font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
                case .slot(let i):
                    slot(i)
                }
            }
        }
    }

    private enum Token { case word(String), slot(Int) }

    private var tokens: [Token] {
        var out: [Token] = []
        for (i, piece) in pieces.enumerated() {
            for w in piece.split(separator: " ", omittingEmptySubsequences: true) { out.append(.word(String(w))) }
            if i < pieces.count - 1 { out.append(.slot(i)) }
        }
        return out
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        let value = i < filled.count ? filled[i] : nil
        let isRight = checked && i < answers.count && value?.lowercased() == answers[i].lowercased()
        Button {
            guard !checked, i < filled.count else { return }
            filled[i] = nil
        } label: {
            Text(value ?? "      ")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(checked ? (isRight ? Palette.correct : Palette.wrong) : Palette.wine)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .frame(minWidth: 78)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(value == nil ? Palette.cardAlt : (checked ? (isRight ? Palette.correctBG : Palette.wrongBG) : Palette.wineSoft)))
                .overlay(alignment: .bottom) {
                    if value == nil { Rectangle().fill(Palette.inkFaint).frame(height: 1.5).padding(.horizontal, 10).padding(.bottom, 5) }
                }
        }
        .buttonStyle(.plain)
    }

    private func check() {
        checked = true
        let ok = zip(filled, answers).allSatisfy { ($0 ?? "").lowercased() == $1.lowercased() }
        let full = pieces.enumerated().map { i, p in p + (i < answers.count ? "**\(answers[i])**" : "") }.joined()
        onAnswer(ok, full.trimmingCharacters(in: .whitespaces))
    }
}

/// Tap matching pairs, two columns.
struct MatchCard: View {
    let card: Card
    let locked: Bool
    let onAnswer: (Bool, String?) -> Void
    @State private var left: [String] = []
    @State private var right: [String] = []
    @State private var selL: String? = nil
    @State private var selR: String? = nil
    @State private var matched: Set<String> = []
    @State private var wrongFlash: Set<String> = []
    @State private var mistakes = 0
    @State private var done = false

    private var pairs: [[String]] { (card.pairs ?? []).filter { $0.count == 2 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            QuestionHeader(label: "Match the pairs", text: card.question ?? "Tap the matching pairs")
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) { ForEach(left, id: \.self) { tile($0, isLeft: true) } }
                VStack(spacing: 10) { ForEach(right, id: \.self) { tile($0, isLeft: false) } }
            }
        }
        .onAppear {
            if left.isEmpty {
                left = pairs.map { $0[0] }.shuffled()
                right = pairs.map { $0[1] }.shuffled()
            }
        }
    }

    private func tile(_ text: String, isLeft: Bool) -> some View {
        let isMatched = matched.contains(text)
        let isSel = isLeft ? selL == text : selR == text
        let isWrong = wrongFlash.contains(text)
        let state: TileStyle.TileState = isMatched ? .correct : (isWrong ? .wrong : (isSel ? .selected : .idle))
        return Button {
            guard !done, !isMatched else { return }
            Haptics.tap()
            if isLeft { selL = text } else { selR = text }
            evaluate()
        } label: {
            Text(text).font(.system(size: 14.5, weight: .medium)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(TileStyle(state: state))
        .opacity(isMatched ? 0.55 : 1)
        .animation(.easeOut(duration: 0.2), value: state)
    }

    private func evaluate() {
        guard let l = selL, let r = selR else { return }
        if pairs.contains(where: { $0[0] == l && $0[1] == r }) {
            matched.insert(l); matched.insert(r)
            Haptics.soft()
        } else {
            mistakes += 1
            wrongFlash = [l, r]
            Haptics.error()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { wrongFlash = [] }
        }
        selL = nil; selR = nil
        if matched.count == pairs.count * 2 {
            done = true
            onAnswer(mistakes <= 1, pairs.map { "\($0[0]) → \($0[1])" }.joined(separator: "\n"))
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - Complete

struct LessonComplete: View {
    let session: Session
    let accuracy: Double
    let reward: GameProgress.Reward?
    let seconds: Int
    let onDone: () -> Void
    @Environment(GameProgress.self) private var progress
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.wineSoft).frame(width: 150, height: 150).scaleEffect(appear ? 1 : 0.6)
                WineGlass(color: Color(hex: "#7D1D3F"), rim: Color(hex: "#B04A68"), fill: appear ? 0.7 : 0.05)
                    .frame(height: 110)
                    .animation(.easeOut(duration: 1.1).delay(0.2), value: appear)
            }
            .padding(.bottom, 28)
            Eyebrow(session.lessonID == nil ? "Practice complete" : "Lesson complete", color: Palette.wine)
            Text(headline).font(.system(size: 29, weight: .semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                .padding(.top, 8).padding(.horizontal, Metrics.margin)

            HStack(spacing: 0) {
                stat("\(reward?.xp ?? 0)", "XP earned", "sparkle", Palette.brass)
                Rectangle().fill(Palette.line).frame(width: 0.5, height: 44)
                stat("\(Int((accuracy * 100).rounded()))%", "Accuracy", "scope", Palette.wine)
                Rectangle().fill(Palette.line).frame(width: 0.5, height: 44)
                stat(timeString, "Time", "clock", Palette.slate)
            }
            .padding(.vertical, 18)
            .cardStyle(padding: 8)
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 32)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            if let r = reward, r.streakIncreased {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill").font(.system(size: 22)).foregroundStyle(Palette.flame)
                        .symbolEffect(.bounce, value: appear)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(r.newStreak)-day streak").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(r.usedFreeze ? "A streak freeze covered yesterday." : "Come back tomorrow to keep it going.")
                            .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 22)
                .opacity(appear ? 1 : 0)
            }
            if let r = reward, !r.newAchievements.isEmpty {
                ForEach(r.newAchievements) { a in
                    HStack(spacing: 10) {
                        Image(systemName: a.icon).font(.system(size: 18)).foregroundStyle(Palette.brass).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Achievement: \(a.title)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(a.detail).font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Metrics.margin).padding(.top, 14)
                }
            }
            Spacer()
            Button("Continue", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 12)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true } }
    }

    private var headline: String {
        if accuracy >= 0.999 { return "A flawless pour" }
        if accuracy >= 0.8 { return "Beautifully done" }
        if accuracy >= 0.5 { return "Good progress" }
        return "Every glass counts"
    }

    private var timeString: String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m):" + String(format: "%02d", s) : "\(s)s"
    }

    private func stat(_ v: String, _ label: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(c)
            Text(v).font(.numeric(20, .semibold)).foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}
