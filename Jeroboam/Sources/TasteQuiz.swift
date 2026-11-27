import SwiftUI

/// "Not sure what to try first?" Six everyday questions (coffee, fruit, food, mood…) point to a wine style, three grapes to start
/// with and one classic bottle from the Atlas. Shown big on a new journal, and as a small card at the bottom once it fills up.
enum TasteStyle: String, CaseIterable, Codable {
    case crisp, aromatic, rich, rose, light, medium, bold, sparkling, sweet

    var title: String {
        switch self {
        case .crisp: return "Crisp, fresh whites"
        case .aromatic: return "Fragrant whites"
        case .rich: return "Rich, creamy whites"
        case .rose: return "Dry rosé"
        case .light: return "Light, silky reds"
        case .medium: return "Smooth, juicy reds"
        case .bold: return "Bold, structured reds"
        case .sparkling: return "Sparkling wine"
        case .sweet: return "Sweet and luscious"
        }
    }
    var why: String {
        switch self {
        case .crisp: return "You like bright, zesty flavours: citrus, green apple and a clean, mouth-watering finish."
        case .aromatic: return "You love perfume and fruit: peach, flowers and spice, with little or no oak."
        case .rich: return "You like comfort and texture: ripe fruit, cream and a touch of toasty oak."
        case .rose: return "Summer in a glass: red berries, citrus and a dry, refreshing finish."
        case .light: return "You like elegance over power: red berries, soft tannins and fresh acidity."
        case .medium: return "Easy to love: ripe plum and cherry, gentle tannins, a round finish."
        case .bold: return "You like intensity: dark fruit, firm tannins and a long, warming finish."
        case .sparkling: return "Bubbles for any moment: crisp, lively and often toasty."
        case .sweet: return "You have a sweet tooth: honey, apricot and candied fruit, balanced by acidity."
        }
    }
    var grapes: [String] {
        switch self {
        case .crisp: return ["Sauvignon Blanc", "Albariño", "Grüner Veltliner"]
        case .aromatic: return ["Riesling", "Gewürztraminer", "Viognier"]
        case .rich: return ["Chardonnay", "Viognier", "Chenin Blanc"]
        case .rose: return ["Grenache", "Cinsault", "Pinot Noir"]
        case .light: return ["Pinot Noir", "Gamay", "Nebbiolo"]
        case .medium: return ["Merlot", "Sangiovese", "Tempranillo"]
        case .bold: return ["Cabernet Sauvignon", "Malbec", "Syrah"]
        case .sparkling: return ["Chardonnay", "Pinot Noir", "Glera"]
        case .sweet: return ["Muscat", "Riesling", "Chenin Blanc"]
        }
    }
    /// Wines of the world styles to pick a classic from.
    var wineStyles: [String] {
        switch self {
        case .crisp: return ["light-white"]
        case .aromatic: return ["aromatic-white"]
        case .rich: return ["full-white"]
        case .rose: return ["rose"]
        case .light: return ["light-red"]
        case .medium: return ["medium-red"]
        case .bold: return ["full-red"]
        case .sparkling: return ["champagne-style", "prosecco", "cava"]
        case .sweet: return ["noble-sweet", "asti", "dried-grape"]
        }
    }
    var glass: Color {
        switch self {
        case .crisp, .aromatic: return Color(hex: "#E8D27A")
        case .rich: return Color(hex: "#DDB54F")
        case .rose: return Color(hex: "#E58BA2")
        case .light: return Color(hex: "#B0303F")
        case .medium: return Color(hex: "#8B1538")
        case .bold: return Color(hex: "#5A0F25")
        case .sparkling: return Color(hex: "#F1E3A6")
        case .sweet: return Color(hex: "#C98B3C")
        }
    }
}

enum TasteQuiz {
    struct Question { let text: String; let options: [(String, [TasteStyle])] }

    static let questions: [Question] = [
        Question(text: "How do you take your coffee?", options: [
            ("Black, strong", [.bold, .medium]), ("With milk", [.rich, .medium]),
            ("I'd rather have tea", [.crisp, .light, .aromatic]), ("Sweet, like a latte with syrup", [.sweet, .aromatic, .rose])]),
        Question(text: "Pick a fruit", options: [
            ("Lemon or green apple", [.crisp, .sparkling]), ("Peach or apricot", [.aromatic, .rich, .sweet]),
            ("Strawberry or cherry", [.rose, .light]), ("Blackberry or plum", [.bold, .medium])]),
        Question(text: "Dark chocolate?", options: [
            ("Yes, the darker the better", [.bold]), ("Sometimes", [.medium, .light]),
            ("Milk chocolate for me", [.sweet, .rose, .rich])]),
        Question(text: "What's for dinner?", options: [
            ("Seafood or a salad", [.crisp, .sparkling]), ("Roast chicken or creamy pasta", [.rich, .light]),
            ("Steak or barbecue", [.bold, .medium]), ("Something spicy", [.aromatic, .rose, .sweet])]),
        Question(text: "Pick a moment", options: [
            ("A sunny terrace", [.rose, .crisp]), ("A cosy dinner", [.medium, .bold, .light]),
            ("Celebrating", [.sparkling]), ("Dessert on the sofa", [.sweet])]),
        Question(text: "Your usual drink when out?", options: [
            ("Gin and tonic", [.crisp, .aromatic]), ("A fruity cocktail", [.rose, .aromatic, .sweet]),
            ("Negroni or whisky", [.bold, .medium]), ("Spritz or prosecco", [.sparkling, .light])]),
    ]

    /// The style the answers point to most (ties: the earlier answer's first style wins).
    static func result(_ answers: [Int]) -> TasteStyle {
        var score: [TasteStyle: Double] = [:]
        for (q, a) in answers.enumerated() where q < questions.count && a < questions[q].options.count {
            for (i, s) in questions[q].options[a].1.enumerated() { score[s, default: 0] += i == 0 ? 2 : 1 }
        }
        return score.max { $0.value < $1.value || ($0.value == $1.value && $0.key.rawValue > $1.key.rawValue) }?.key ?? .medium
    }

    /// The saved result. The TestFlight "fresh journal" keeps its own, so a new-user test starts without one.
    static var saved: TasteStyle? {
        get { UserDefaults.standard.string(forKey: key).flatMap(TasteStyle.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: key) }
    }
    private static var key: String { JournalPreview.fresh ? "jero.tasteQuiz.fresh" : "jero.tasteQuiz" }

    static func classic(for s: TasteStyle) -> Wine? {
        (ContentStore.shared.library.wines ?? []).first { s.wineStyles.contains($0.style) }
    }
}

/// TestFlight: show the journal as a brand-new user sees it. Nothing is deleted; the real bottles and tastings come back when off.
enum JournalPreview {
    static var fresh: Bool { Distribution.isTestFlight && UserDefaults.standard.bool(forKey: "jero.freshJournal") }
    /// The empty journal used while `fresh` is on (kept in memory only).
    static let blank = JournalStore.blank()
}

/// The quiz card: big with an invitation on a new journal, small at the bottom once it fills up; shows your result once taken.
struct TasteQuizCard: View {
    var big = false
    @State private var open = false
    @State private var result: TasteStyle? = TasteQuiz.saved

    var body: some View {
        Button { open = true } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(result == nil ? "NOT SURE WHAT TO TRY?" : "YOUR WINE STYLE").font(.jero(size: 11, weight: .semibold)).kerning(1.2)
                        .foregroundStyle(Palette.wine)
                    Text(result?.title ?? "Take the 1-minute taste quiz").font(.jero(size: big ? 19 : 16.5, weight: .semibold))
                        .foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Text(result.map { "Start with " + $0.grapes.prefix(2).joined(separator: " or ") + ". Tap to see more or retake." }
                         ?? "Six everyday questions, coffee, fruit, dinner, and Jero suggests the wines to start with.")
                        .font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(Palette.wineSoft).frame(width: big ? 64 : 50, height: big ? 64 : 50)
                    if let r = result {
                        SilhouetteGlass(color: r.glass, fill: 0.55).frame(width: big ? 26 : 20, height: big ? 44 : 34)
                    } else {
                        Image(systemName: "questionmark.bubble").font(.system(size: big ? 24 : 19)).foregroundStyle(Palette.wine)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 0)
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $open, onDismiss: { result = TasteQuiz.saved }) { TasteQuizView() }
    }
}

/// The quiz itself: one question at a time, then the result with grapes and a classic to open.
struct TasteQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [Int] = []
    @State private var done: TasteStyle? = nil
    @State private var grapePage: Grape? = nil
    @State private var winePage: Wine? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let r = done { result(r) } else { question }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .navigationDestination(item: $grapePage) { g in GrapeDetailView(grape: g) }
            .navigationDestination(item: $winePage) { w in WineDetailView(wine: w) }
        }
    }

    @ViewBuilder private var question: some View {
        let i = answers.count
        let q = TasteQuiz.questions[i]
        VStack(alignment: .leading, spacing: 6) {
            Text("QUESTION \(i + 1) OF \(TasteQuiz.questions.count)").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.wine)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cardAlt)
                    Capsule().fill(Palette.wine).frame(width: g.size.width * CGFloat(i) / CGFloat(TasteQuiz.questions.count))
                }
            }
            .frame(height: 4)
            Text(q.text).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink).padding(.top, 8)
        }
        VStack(spacing: 10) {
            ForEach(Array(q.options.enumerated()), id: \.offset) { n, o in
                Button {
                    Haptics.tap()
                    withAnimation(.smooth(duration: 0.25)) {
                        answers.append(n)
                        if answers.count == TasteQuiz.questions.count {
                            let r = TasteQuiz.result(answers)
                            TasteQuiz.saved = r
                            done = r
                        }
                    }
                } label: {
                    Text(o.0).font(.jero(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
        if i > 0 {
            Button("Back") { withAnimation { _ = answers.popLast() } }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine)
        }
    }

    @ViewBuilder private func result(_ r: TasteStyle) -> some View {
        VStack(spacing: 10) {
            SilhouetteGlass(color: r.glass, fill: 0.6).frame(width: 54, height: 92)
            Text("YOUR WINE STYLE").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Palette.wine)
            Text(r.title).font(.screenTitle).kerning(-0.4).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text(r.why).font(.jero(size: 15)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.top, 8)
        SectionTitle(text: "Grapes to start with")
        GroupCard {
            let gs = r.grapes.compactMap(matchGrape)
            ForEach(Array(gs.enumerated()), id: \.element.id) { n, g in
                Button { grapePage = g } label: {
                    IconRow(title: g.name, detail: g.berry == .white ? "White grape" : "Black grape", last: n == gs.count - 1) {
                        GrapeBadge(grape: g, size: 34, disc: false)
                    }
                }
                .buttonStyle(RowPressStyle())
            }
        }
        if let w = TasteQuiz.classic(for: r) {
            SectionTitle(text: "A classic to look for")
            Button { winePage = w } label: {
                HStack(spacing: 12) {
                    WineGlassIcon(wine: w, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.name).font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(w.summary).font(.jero(size: 13)).foregroundStyle(Palette.inkSoft).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: 0)
            }
            .buttonStyle(PressableStyle())
        }
        Text("Next time you buy a bottle, scan it: Jero keeps it in your journal and learns what you like.")
            .font(.jero(size: 13.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 12) {
            Button("Retake") { withAnimation { answers = []; done = nil } }.buttonStyle(SecondaryButtonStyle())
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// A brand-new journal: a welcome instead of an empty list or made-up charts.
struct JournalWelcome: View {
    var onScan: () -> Void
    var onBlind: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // the invitation
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR WINE JOURNAL").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(.white.opacity(0.75))
                Text("Every bottle you open, remembered").font(.jero(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Snap a label: Jero finds the wine, its grapes, region and price. Keep a cellar, taste blind, and watch your palate take shape.")
                    .font(.jero(size: 14)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                Button(action: onScan) {
                    Label("Scan your first bottle", systemImage: "camera.viewfinder")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))

            TasteQuizCard(big: true)

            SectionTitle(text: "What your journal will show")
            HStack(alignment: .top, spacing: 10) {
                preview("square.stack.3d.up.fill", "Your cellar", "What every bottle is worth, and when to open it")
                preview("chart.pie.fill", "Your palate", "The grapes and styles you keep coming back to")
                preview("seal.fill", "Your stamps", "A stamp for every grape and country you taste")
            }
        }
    }

    private func preview(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Palette.wine)
                .frame(width: 38, height: 38).background(Circle().fill(Palette.wineSoft))
            Text(title).font(.jero(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(text).font(.jero(size: 12)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .cardStyle(padding: 0)
    }
}
