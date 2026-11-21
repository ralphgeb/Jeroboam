import SwiftUI

/// A ten-question quiz that places a new player on one of five levels: two questions for each level, getting harder
/// as it goes, drawn from one of three different sets. Every answer comes with a "did you know?" explanation.
struct PlacementQuestion {
    let level: Int            // as written: 1 easy, 2 medium, 3 hard (the quiz re-tiers them 1…5 by position)
    let text: String
    let options: [String]     // the correct answer comes first; the card shuffles them
    let explain: String
    var visual: String? = nil
}

enum PlacementBank {
    static let sets: [[PlacementQuestion]] = [setA, setB, setC]

    static let setA: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape is Argentina's signature red?",
              options: ["Malbec", "Tempranillo", "Syrah", "Pinot Noir"],
              explain: "Malbec. It began in Cahors, France, but found its true home in Mendoza, where vineyards at 900–1,500 m give it deep color, ripe plum fruit and fresh acidity from cool nights."),
        .init(level: 1, text: "Red wine gets its color from the grape juice.",
              options: ["False", "True"],
              explain: "Almost all grape juice is clear, even from black grapes. Red color comes from the skins steeping in the juice during fermentation. Only a few rare grapes, like Alicante Bouschet, are red inside."),
        .init(level: 2, text: "Chianti is made mainly from which grape?",
              options: ["Sangiovese", "Nebbiolo", "Barbera", "Montepulciano"],
              explain: "Sangiovese, Tuscany's signature red: cherry, dried herbs and high acidity. Chianti Classico requires at least 80%, and the black rooster on the neck label marks the heartland between Florence and Siena."),
        .init(level: 2, text: "Amarone della Valpolicella is made from grapes that are…",
              options: ["Dried for months before fermenting", "Picked after the first frost", "Fermented with the stems only", "Aged in a solera"],
              explain: "Appassimento: Corvina and other grapes are dried on racks for months, losing a third of their weight. What's left is concentrated and, fermented dry, gives a rich red of 15% alcohol or more."),
        .init(level: 2, text: "Which South African grape is a cross of Pinot Noir and Cinsault?",
              options: ["Pinotage", "Chenin Blanc", "Shiraz", "Carmenère"],
              explain: "Pinotage, created at Stellenbosch University in 1925. Cinsault was then called Hermitage in South Africa, which is where the second half of the name comes from."),
        .init(level: 2, text: "Which Burgundy village is highlighted?",
              options: ["Chablis", "Pouilly-Fuissé", "Meursault", "Gevrey-Chambertin"],
              explain: "Chablis is Chardonnay grown on ancient Kimmeridgian limestone, packed with fossilized oyster shells. Maybe that's why it is the classic partner of fresh oysters.",
              visual: "map:burgundy:chablis"),
        .init(level: 3, text: "Which white grape makes Santorini's famous mineral wines, keeping its acidity in the heat?",
              options: ["Assyrtiko", "Moschofilero", "Vidiano", "Roditis"],
              explain: "Assyrtiko. The vines are twisted into low baskets (kouloura) to shelter the grapes from wind and sun, and the volcanic ash soil spared them from phylloxera, so some vines are centuries old."),
        .init(level: 3, text: "Austria's most planted red grape, a 1922 cross, is…",
              options: ["Zweigelt", "Blaufränkisch", "St. Laurent", "Blauburger"],
              explain: "Zweigelt, a cross of Blaufränkisch and St. Laurent made by Dr. Fritz Zweigelt. It is juicy and cherry-scented, while its parent Blaufränkisch makes the more serious, peppery reds of Burgenland."),
        .init(level: 3, text: "Which compound gives aged Riesling its famous petrol note?",
              options: ["TDN", "Diacetyl", "Methoxypyrazine", "Rotundone"],
              explain: "TDN (a carotenoid breakdown product) forms as Riesling ages in bottle, faster in warm, sunny vineyards. Diacetyl is butter, methoxypyrazine is green pepper and rotundone is black pepper."),
        .init(level: 3, text: "Which Barolo commune is best known for the most powerful, structured, long-lived wines?",
              options: ["Serralunga d'Alba", "La Morra", "Barolo", "Verduno"],
              explain: "Serralunga d'Alba, on older, compact Helvetian soils, gives austere, tannic Barolo that needs 15 years or more. La Morra, on softer Tortonian marl, makes more perfumed, earlier-drinking wines."),
    ]

    static let setB: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape made Marlborough, New Zealand famous?",
              options: ["Sauvignon Blanc", "Chardonnay", "Merlot", "Riesling"],
              explain: "Marlborough Sauvignon Blanc exploded in the 1980s with its burst of passion fruit and grapefruit. Warm sunny days and cold nights keep the grapes aromatic and fresh."),
        .init(level: 1, text: "Real Champagne can only come from Champagne, France.",
              options: ["True", "False"],
              explain: "The name is legally protected. The same method elsewhere has to go by another name: Cava in Spain, Crémant elsewhere in France, Franciacorta in Italy, Cap Classique in South Africa."),
        .init(level: 2, text: "Which region makes most of Spain's Cava?",
              options: ["Penedès", "Rioja", "Jerez", "Rías Baixas"],
              explain: "Penedès, near Barcelona. Cava is made by the traditional method (second fermentation in the bottle) mostly from Macabeo, Xarel·lo and Parellada, and the best must age at least nine months on the lees."),
        .init(level: 2, text: "Albariño is the pride of which Spanish region?",
              options: ["Rías Baixas", "Rueda", "Penedès", "Bierzo"],
              explain: "Rías Baixas, on Galicia's cool, wet Atlantic coast. Vines are trained high on pergolas to stay dry in the damp air, and the fresh, saline whites pair with the local shellfish.",
              visual: "map:spain:rias-baixas"),
        .init(level: 2, text: "Which Piedmont wine comes from the highlighted zone?",
              options: ["Barolo", "Chianti", "Amarone", "Brunello"],
              explain: "Barolo is 100% Nebbiolo, a name that likely comes from nebbia, the fog of the autumn harvest. It is pale in color but huge in tannin and acid, and must age at least 38 months before release.",
              visual: "map:piedmont:barolo"),
        .init(level: 2, text: "What does Reserva on a Spanish red label tell you?",
              options: ["A minimum aging time set by law", "It's from a single vineyard", "It's organic", "It's from old vines only"],
              explain: "In Rioja a red Reserva spends at least three years aging, with at least one in oak. Crianza is shorter and Gran Reserva longer, so the label tells you how long the wine rested before you."),
        .init(level: 3, text: "Which grape is Chile's signature, long mistaken for Merlot until 1994?",
              options: ["Carmenère", "Carignan", "País", "Cabernet Franc"],
              explain: "Carmenère, a Bordeaux variety wiped out in France by phylloxera. Planted in Chile among Merlot vines, it was only identified by a French ampelographer in 1994. It ripens late, so it tastes green if picked too early."),
        .init(level: 3, text: "Henschke's Hill of Grace Shiraz comes from which Australian region?",
              options: ["Eden Valley", "Barossa Valley", "McLaren Vale", "Coonawarra"],
              explain: "Eden Valley, a cooler, higher part of the Barossa zone. Hill of Grace was planted in the 1860s on its own roots, and is one of the world's most prized old-vine Shiraz wines."),
        .init(level: 3, text: "Which grape makes the dry white wines of Savennières in the Loire?",
              options: ["Chenin Blanc", "Melon de Bourgogne", "Sauvignon Blanc", "Cabernet Franc"],
              explain: "Chenin Blanc, grown on schist and sandstone slopes above the Loire. Savennières is dry, steely and waxy, with quince and honey notes, and it can age for decades."),
        .init(level: 3, text: "The Montrachet Grand Cru vineyard is shared by which two villages?",
              options: ["Puligny and Chassagne", "Meursault and Volnay", "Aloxe and Savigny", "Vosne and Flagey"],
              explain: "Puligny-Montrachet and Chassagne-Montrachet each own a slice, and both added the vineyard's name to their own in the 1870s. Le Montrachet makes arguably the world's greatest dry Chardonnay."),
    ]

    static let setC: [PlacementQuestion] = [
        .init(level: 1, text: "Which grape is Sancerre made from?",
              options: ["Sauvignon Blanc", "Chardonnay", "Chenin Blanc", "Riesling"],
              explain: "Sauvignon Blanc from the Loire: grapefruit, gooseberry and wet stone. The classic local pairing is Crottin de Chavignol, a goat's cheese from the same hills."),
        .init(level: 1, text: "What is the best serving temperature for most reds?",
              options: ["A little cool: about 60–65°F (16–18°C)", "Warm room temperature, about 75°F", "Ice cold", "Straight from the freezer"],
              explain: "'Room temperature' comes from drafty old castles. Served too warm, red wine tastes flabby and the alcohol burns. Twenty minutes in the fridge brings most reds to the sweet spot."),
        .init(level: 2, text: "What does 'Brut' on a Champagne label tell you?",
              options: ["It is dry, with little added sugar", "It is sweet", "It was aged in oak", "It is from a single vintage"],
              explain: "Brut means dry: up to 12 g/L of sugar, and most Champagne is Brut. Extra Brut is drier still, while Demi-Sec at 32 to 50 g/L tastes properly sweet."),
        .init(level: 2, text: "Which grape makes Brunello di Montalcino?",
              options: ["Sangiovese", "Nebbiolo", "Montepulciano", "Merlot"],
              explain: "Sangiovese, locally called Brunello. It cannot be released until five years after harvest, with at least two of them in oak.",
              visual: "map:tuscany:montalcino"),
        .init(level: 2, text: "Which wine ages in a solera system of stacked barrels?",
              options: ["Sherry", "Rioja", "Cava", "Txakoli"],
              explain: "Sherry. Each year some wine is taken from the oldest row of barrels and replaced from the row above, so every bottle holds traces of very old wine. Under a layer of flor yeast, fino sherry stays pale and dry."),
        .init(level: 2, text: "How is Beaujolais Nouveau's banana-and-bubblegum character made?",
              options: ["Carbonic maceration of whole bunches", "Aging in new oak", "Adding sugar before bottling", "Freezing the grapes"],
              explain: "Whole bunches ferment inside their own berries in a CO₂-filled vat, producing fruity esters and almost no tannin. It's released on the third Thursday of November, weeks after harvest."),
        .init(level: 3, text: "Which Umbrian grape produces some of the world's most tannic red wines?",
              options: ["Sagrantino", "Sangiovese", "Aglianico", "Nero d'Avola"],
              explain: "Sagrantino, grown only around Montefalco. It has the highest polyphenol (tannin) levels of any grape tested, so the wine needs years in oak and bottle to soften. It was once made only as a sweet, dried-grape wine."),
        .init(level: 3, text: "Greece's Xinomavro, often compared to Nebbiolo, is most famous in which appellation?",
              options: ["Naoussa", "Nemea", "Mantinia", "Santorini"],
              explain: "Naoussa, in northern Greece. Xinomavro, meaning acid-black, is pale, high in tannin and acid, with tomato, olive and dried-cherry notes, and it ages for decades like Barolo."),
        .init(level: 3, text: "Which South African wine estate was famous for a sweet Muscat wine that Napoleon asked for on St Helena?",
              options: ["Constantia", "Stellenbosch", "Paarl", "Swartland"],
              explain: "Constantia, near Cape Town. Vin de Constance, a sweet wine of Muscat de Frontignan, was famous across 18th- and 19th-century Europe, and Klein Constantia revived it in 1986."),
        .init(level: 3, text: "What is the maximum share of white Viognier allowed in a red Côte-Rôtie?",
              options: ["20%", "5%", "35%", "50%"],
              explain: "Up to 20%, though most growers use far less. The Viognier is fermented together with the Syrah, which fixes the color and lifts the aroma with apricot and violets."),
    ]

    static func cards(for set: Int) -> [Card] {
        sets[set % sets.count].enumerated().map { i, q in
            Card(id: "pq\(set)-\(i)", kind: .choice, question: q.text, options: q.options, answer: 0, explain: q.explain, visual: q.visual)
        }
    }

    /// Two questions per level, easiest first.
    static func level(of set: Int) -> [Int] { (0..<sets[set % sets.count].count).map { min(5, $0 / 2 + 1) } }
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
            Text("Ten questions from around the world, about three minutes. They start easy and finish very hard, so we can place you on one of five levels.")
                .font(.system(size: 16)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).lineSpacing(3)
                .padding(.horizontal, 30).padding(.top, 10)
            HStack(spacing: 10) {
                pill("Easy", Palette.level(1)); pill("Medium", Palette.level(2)); pill("Hard", Palette.level(3)); pill("Expert", Palette.level(4))
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
                    Text(["Warm-up", "Getting warmer", "Getting serious", "Expert territory", "Sommelier level"][level - 1].uppercased())
                        .font(.system(size: 11.5, weight: .bold)).kerning(1.2).foregroundStyle(Palette.level(level))
                    CardView(card: card, locked: feedback != nil, onAnswer: { ok, _ in
                        feedback = ok
                        if ok { points += level }
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

    // two questions per level: 30 points in all. Guessing the easy ones puts you on Level 1 or 2; Level 5 needs most of the hard ones too.
    private var placed: Int { points >= 23 ? 5 : (points >= 17 ? 4 : (points >= 11 ? 3 : (points >= 5 ? 2 : 1))) }

    private var result: some View {
        let n = placed
        let names = [1: "New to wine", 2: "Curious drinker", 3: "Growing palate", 4: "Serious student", 5: "Ready for the great regions"]
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
            Text("We'll start you at Level \(n), and it's unlocked for you. You can always change your level later.")
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
