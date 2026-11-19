import SwiftUI

/// A ten-question quiz that places a new player: three easy, four medium, three hard questions, drawn from
/// one of three different sets. Every answer comes with a "did you know?" explanation.
struct PlacementQuestion {
    let level: Int            // 1 easy, 2 medium, 3 hard
    let text: String
    let options: [String]     // the correct answer comes first; the card shuffles them
    let explain: String
    var visual: String? = nil
}

enum PlacementBank {
    static let sets: [[PlacementQuestion]] = [setA, setB, setC]

    static let setA: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape is behind a bottle labeled Blanc de Blancs?",
              options: ["Chardonnay", "Pinot Noir", "Riesling", "Sauvignon Blanc"],
              explain: "Blanc de Blancs means white from whites: 100% Chardonnay. Champagne's other main grapes, Pinot Noir and Meunier, are black, but their juice is clear, so pressed gently they make white wine too (Blanc de Noirs)."),
        .init(level: 1, text: "Red wine gets its color from the grape juice.",
              options: ["False", "True"],
              explain: "Almost all grape juice is clear, even from black grapes. Red color comes from the skins steeping in the juice during fermentation. Only a few rare grapes, like Alicante Bouschet, are red inside."),
        .init(level: 1, text: "Which famous region is highlighted?",
              options: ["Rioja", "Priorat", "Rías Baixas", "Jerez"],
              explain: "Rioja, in northern Spain, built its name on Tempranillo aged in oak. The label tells you the aging: Crianza, Reserva and Gran Reserva each require a legal minimum time in barrel and bottle.",
              visual: "map:spain:rioja"),
        .init(level: 2, text: "Which grape makes Chianti?",
              options: ["Sangiovese", "Nebbiolo", "Montepulciano", "Barbera"],
              explain: "Chianti Classico must be at least 80% Sangiovese. The name is often traced to sanguis Jovis, the blood of Jupiter."),
        .init(level: 2, text: "What does tannin feel like in your mouth?",
              options: ["A drying, grippy feel on your gums and cheeks", "A tingle, like bubbles", "A thick, sweet weight", "A burning warmth"],
              explain: "Tannin comes from skins, seeds, stems and oak, and it binds to the proteins in your saliva. That is why a tannic red tastes softer with a steak: fat and protein take the grip away."),
        .init(level: 2, text: "Which Burgundy village is highlighted?",
              options: ["Chablis", "Pouilly-Fuissé", "Meursault", "Gevrey-Chambertin"],
              explain: "Chablis is Chardonnay grown on ancient Kimmeridgian limestone, packed with fossilized oyster shells. Maybe that's why it is the classic partner of fresh oysters.",
              visual: "map:burgundy:chablis"),
        .init(level: 2, text: "Which Spanish sparkling wine is made like Champagne, with the second fermentation in the bottle?",
              options: ["Cava", "Prosecco", "Asti", "Crémant"],
              explain: "Cava uses the traditional method, mostly from Macabeo, Xarel·lo and Parellada around Penedès. Prosecco is Italian and usually gets its bubbles in a big tank, which keeps it fresh and fruity."),
        .init(level: 3, text: "Which white grape is often co-fermented with Syrah in Côte-Rôtie?",
              options: ["Viognier", "Marsanne", "Roussanne", "Grenache Blanc"],
              explain: "Up to 20% Viognier is allowed in Côte-Rôtie. Fermenting the two together helps lock in color and adds an apricot-and-flowers perfume to the Syrah."),
        .init(level: 3, text: "What happens during malolactic fermentation?",
              options: ["Sharp malic acid turns into softer lactic acid", "Sugar turns into alcohol", "Tannins turn into color", "Carbon dioxide is trapped for bubbles"],
              explain: "Bacteria convert malic acid (green apples) to lactic acid (milk). It softens the wine and makes buttery diacetyl, which is why oaky Chardonnay can taste creamy. Crisp whites often block it to stay zesty."),
        .init(level: 3, text: "Which region was fixed by law in 1756, one of the first demarcated wine regions in the world?",
              options: ["Douro", "Dão", "Alentejo", "Vinho Verde"],
              explain: "The Douro Valley in Portugal. Port is made here by adding grape spirit mid-fermentation, which stops the yeast and keeps the natural sweetness. The steep terraces are still mostly picked by hand.",
              visual: "map:portugal:douro"),
    ]

    static let setB: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape is Sancerre made from?",
              options: ["Sauvignon Blanc", "Chardonnay", "Chenin Blanc", "Riesling"],
              explain: "Sauvignon Blanc from the Loire: grapefruit, gooseberry and wet stone. The classic local pairing is Crottin de Chavignol, a goat's cheese from the same hills."),
        .init(level: 1, text: "Real Champagne can only come from Champagne, France.",
              options: ["True", "False"],
              explain: "The name is legally protected. The same method elsewhere has to go by another name: Cava in Spain, Crémant elsewhere in France, Franciacorta in Italy, Cap Classique in South Africa."),
        .init(level: 1, text: "Which famous sparkling region is this?",
              options: ["Champagne", "Alsace", "The Loire", "Chablis"],
              explain: "Champagne is one of the coolest major wine regions, so grapes keep the high acidity sparkling wine needs. Chalk cellars hold the bottles cool during their long aging.",
              visual: "map:champagne"),
        .init(level: 2, text: "Malbec is the star of Argentina, but which French region first made it famous?",
              options: ["Cahors", "Médoc", "Beaujolais", "Alsace"],
              explain: "Cahors, in southwest France, once made inky 'black wine' from Malbec. In Argentina the grape found its second home in the high-altitude vineyards of Mendoza."),
        .init(level: 2, text: "Which of these wines is typically the sweetest?",
              options: ["Sauternes", "Chablis", "Sancerre", "Muscadet"],
              explain: "Sauternes comes from grapes shriveled by noble rot (botrytis), which concentrates sugar and adds flavors of honey and saffron. A single vine may yield only a glass of Château d'Yquem."),
        .init(level: 2, text: "What does Reserva on a Spanish label tell you?",
              options: ["A minimum aging time set by law", "It's from a single vineyard", "It's organic", "It's from old vines only"],
              explain: "In Rioja, a red Reserva spends at least three years aging, with at least one in oak. Crianza is shorter, Gran Reserva longer. The label tells you how long the wine rested before you."),
        .init(level: 2, text: "Which Piedmont wine comes from the highlighted zone?",
              options: ["Barolo", "Chianti", "Amarone", "Brunello"],
              explain: "Barolo is 100% Nebbiolo, a name that likely comes from nebbia, the fog of the autumn harvest. It is pale in color but huge in tannin and acid, with tar-and-roses aromas. It must age at least 38 months before release.",
              visual: "map:piedmont:barolo"),
        .init(level: 3, text: "How many Grand Cru vineyards does Chablis have?",
              options: ["Seven", "Three", "Twelve", "Thirty-three"],
              explain: "Seven, all on a single south-west facing slope above the town: Bougros, Preuses, Vaudésir, Grenouilles, Valmur, Les Clos and Blanchots."),
        .init(level: 3, text: "Which Austrian grape is known for a white-pepper note?",
              options: ["Grüner Veltliner", "Welschriesling", "Zweigelt", "Blaufränkisch"],
              explain: "Grüner Veltliner carries rotundone, the same aromatic compound found in black pepper and in peppery Syrah. Our noses are extremely sensitive to it, a few parts per trillion are enough."),
        .init(level: 3, text: "Steep slate slopes above a winding river: which German region is this?",
              options: ["Mosel", "Rheingau", "Pfalz", "Baden"],
              explain: "The Mosel has some of the steepest vineyards in Europe, with slopes of 60 degrees or more at Calmont. The dark slate absorbs heat and the river reflects light, ripening Riesling that is light, racy and low in alcohol.",
              visual: "map:germany:mosel"),
    ]

    static let setC: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape made Marlborough, New Zealand famous?",
              options: ["Sauvignon Blanc", "Chardonnay", "Merlot", "Riesling"],
              explain: "Marlborough Sauvignon Blanc exploded in the 1980s with its burst of passion fruit and grapefruit. Warm sunny days and cold nights keep the grapes aromatic and fresh."),
        .init(level: 1, text: "What is the best serving temperature for most reds?",
              options: ["A little cool: about 60–65°F (16–18°C)", "Warm room temperature, about 75°F", "Ice cold", "Straight from the freezer"],
              explain: "'Room temperature' comes from drafty old castles. Served too warm, red wine tastes flabby and the alcohol burns. Twenty minutes in the fridge brings most reds to the sweet spot."),
        .init(level: 1, text: "Which of these is a fortified wine?",
              options: ["Port", "Cava", "Chablis", "Rioja"],
              explain: "Port is fortified: grape spirit is added during fermentation, killing the yeast and leaving natural sugar in the wine. That is why it is both sweet and around 20% alcohol."),
        .init(level: 2, text: "Which grape makes Brunello di Montalcino?",
              options: ["Sangiovese", "Nebbiolo", "Montepulciano", "Merlot"],
              explain: "Sangiovese, locally called Brunello. It is among Italy's longest-aged reds: it cannot be released until five years after harvest, with at least two of them in oak.",
              visual: "map:tuscany:montalcino"),
        .init(level: 2, text: "Which best describes terroir?",
              options: ["The place: soil, slope, climate and tradition that shape a wine", "A type of oak barrel", "A winemaking yeast", "A wine's legal classification"],
              explain: "Terroir is why two Pinot Noirs from vineyards a few meters apart can taste different, and why Burgundy classifies individual vineyards, not just villages."),
        .init(level: 2, text: "Which wine ages in a solera system of stacked barrels?",
              options: ["Sherry", "Rioja", "Cava", "Txakoli"],
              explain: "Sherry. Each year some wine is taken from the oldest row of barrels and replaced from the row above, so every bottle holds traces of very old wine. Under a layer of flor yeast, fino sherry stays pale and dry."),
        .init(level: 2, text: "What gives Amarone its power?",
              options: ["Grapes dried for months before fermenting", "Aging in new oak for a decade", "Late harvest after frost", "Adding grape spirit"],
              explain: "Amarone is made in Valpolicella from Corvina and other grapes dried on racks for months, losing much of their water. What's left is concentrated, rich and often 15% alcohol or more."),
        .init(level: 3, text: "How many grape varieties does Châteauneuf-du-Pape allow?",
              options: ["Thirteen", "Three", "Five", "Twenty-five"],
              explain: "Thirteen (eighteen counting color variants), led by Grenache. The vineyards are covered with large round stones that store the day's heat and keep the grapes ripening at night.",
              visual: "map:rhone:chateauneuf-du-pape"),
        .init(level: 3, text: "Which compounds give Sauvignon Blanc its cut-grass and green-pepper smell?",
              options: ["Methoxypyrazines", "Tannins", "Diacetyl", "Brettanomyces"],
              explain: "Methoxypyrazines, the same family of molecules that make a green bell pepper smell green. They fall as grapes ripen, so cooler sites keep more. Passion fruit and grapefruit come from other compounds, thiols."),
        .init(level: 3, text: "How much added sugar does a Champagne labeled Brut Nature have?",
              options: ["None, 0–3 g/L", "6–12 g/L", "About 50 g/L", "More than 100 g/L"],
              explain: "After aging, Champagne gets a top-up called dosage. Brut Nature gets none: bone dry. Extra Brut has up to 6 g/L, Brut up to 12 and Demi-sec 32–50, which tastes noticeably sweet."),
    ]

    static func cards(for set: Int) -> [Card] {
        sets[set % sets.count].enumerated().map { i, q in
            Card(id: "pq\(set)-\(i)", kind: .choice, question: q.text, options: q.options, answer: 0, explain: q.explain, visual: q.visual)
        }
    }

    static func level(of set: Int) -> [Int] { sets[set % sets.count].map(\.level) }
}

struct PlacementQuizView: View {
    var onFinish: (Int?) -> Void
    @State private var set = Int.random(in: 0..<PlacementBank.sets.count)
    @State private var index = -1            // -1 intro, 0..9 questions, 10 result
    @State private var points = 0
    @State private var feedback: Bool? = nil
    @State private var results: [Bool] = []

    private var cards: [Card] { PlacementBank.cards(for: set) }
    private var levels: [Int] { PlacementBank.level(of: set) }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if index < 0 { intro.transition(.opacity) }
            else if index < cards.count { question.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)) }
            else { result.transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
    }

    private var intro: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button { onFinish(nil) } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.inkSoft).padding(8) } }
                .padding(.horizontal, Metrics.margin).padding(.top, 8)
            Spacer()
            ZStack {
                Circle().fill(Palette.wineSoft).frame(width: 150, height: 150)
                Image(systemName: "wineglass").font(.system(size: 60, weight: .light)).foregroundStyle(Palette.wine)
            }
            Text("Find your level").font(.serif(34)).foregroundStyle(Palette.ink).padding(.top, 30)
            Text("Ten questions, about two minutes. We start easy and get harder, then place you where you'll learn the most.")
                .font(.system(size: 16)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).lineSpacing(3)
                .padding(.horizontal, 30).padding(.top, 10)
            HStack(spacing: 10) {
                pill("Easy", Palette.level(1)); pill("Medium", Palette.level(2)); pill("Hard", Palette.level(3))
            }.padding(.top, 24)
            Text("Don't worry about getting them wrong. That's where the fun facts are.")
                .font(.system(size: 13.5)).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 18)
            Spacer()
            Button("Start the quiz") { index = 0 }.buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.margin).padding(.bottom, 16)
        }
    }

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(c)
            .padding(.horizontal, 14).frame(height: 30).background(Capsule().fill(c.opacity(0.12)))
    }

    private var question: some View {
        let card = cards[index]
        let level = levels[index]
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { onFinish(nil) } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.inkSoft) }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule().fill(Palette.wine).frame(width: g.size.width * CGFloat(index + (feedback == nil ? 0 : 1)) / CGFloat(cards.count))
                    }
                }.frame(height: 6)
                Text("\(index + 1)/\(cards.count)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, Metrics.margin).padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(["Warm-up", "Getting warmer", "Expert territory"][level - 1].uppercased())
                        .font(.system(size: 11.5, weight: .bold)).kerning(1.2).foregroundStyle(Palette.level(level))
                    CardView(card: card, locked: feedback != nil, onAnswer: { ok, _ in
                        feedback = ok
                        if ok { points += level == 1 ? 1 : (level == 2 ? 2 : 3) }
                        results.append(ok)
                        ok ? Haptics.success() : Haptics.tap()
                    })
                    Color.clear.frame(height: feedback == nil ? 20 : 300)
                }
                .id(card.id)
                .padding(.horizontal, Metrics.margin).padding(.top, 18)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) {
            if let ok = feedback { panel(ok, card).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.easeOut(duration: 0.25), value: feedback)
    }

    private func panel(_ ok: Bool, _ card: Card) -> some View {
        let tint = ok ? Palette.correct : Palette.wrong
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: ok ? "checkmark.circle.fill" : "lightbulb.fill").font(.system(size: 22)).foregroundStyle(tint)
                Text(ok ? "You knew it" : "Did you know?").font(.system(size: 19, weight: .semibold)).foregroundStyle(tint)
            }
            if !ok, let a = card.options?.first {
                Text("Answer: \(a)").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            Text(card.explain ?? "").font(.system(size: 14.5)).foregroundStyle(Palette.ink.opacity(0.85)).lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            Button(index == cards.count - 1 ? "See my level" : "Next") {
                feedback = nil
                index += 1
            }.buttonStyle(PrimaryButtonStyle(color: tint))
        }
        .padding(.horizontal, Metrics.margin).padding(.top, 16).padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(ok ? Palette.correctBG : Palette.wrongBG).ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.06), radius: 16, y: -4)
        )
    }

    private var placed: Int { points >= 14 ? 3 : (points >= 8 ? 2 : 1) }

    private var result: some View {
        let n = placed
        let names = [1: "New to wine", 2: "Growing palate", 3: "Ready for depth"]
        return VStack(spacing: 0) {
            Spacer()
            Text("\(results.filter { $0 }.count) of \(cards.count) right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.inkSoft)
            Text("Level \(n)").font(.system(size: 64, weight: .bold)).foregroundStyle(Palette.level(n)).padding(.top, 8)
            Text(names[n] ?? "").font(.serif(26)).foregroundStyle(Palette.ink)
            HStack(spacing: 6) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, ok in
                    Circle().fill(ok ? Palette.correct : Palette.wrong.opacity(0.7)).frame(width: 10, height: 10)
                }
            }.padding(.top, 18)
            Text("We'll start you at Level \(n). It's the free level in Jero; the other two come with Jero Plus.")
                .font(.system(size: 15.5)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).lineSpacing(3)
                .padding(.horizontal, 34).padding(.top, 26)
            Spacer()
            VStack(spacing: 10) {
                Button("Start at Level \(n)") { onFinish(n) }.buttonStyle(PrimaryButtonStyle())
                Button("Choose a level myself") { onFinish(nil) }.buttonStyle(SecondaryButtonStyle(color: Palette.inkSoft))
            }
            .padding(.horizontal, Metrics.margin).padding(.bottom, 16)
        }
    }
}
