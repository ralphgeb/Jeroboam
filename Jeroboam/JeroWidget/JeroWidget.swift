import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Data (bundled in the widget, so it needs no shared storage with the app)

struct WidgetWine: Decodable {
    let id: String, name: String, zone: String, color: String, why: String
    let price: Int?, score: Int?
}
struct WidgetData: Decodable {
    let facts: [String]
    let wines: [WidgetWine]

    static let shared: WidgetData = {
        guard let url = Bundle.main.url(forResource: "widget", withExtension: "json"),
              let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(WidgetData.self, from: d) else {
            return WidgetData(facts: ["Wine is grape juice that yeast has turned into alcohol."], wines: [])
        }
        return v
    }()
    init(facts: [String], wines: [WidgetWine]) { self.facts = facts; self.wines = wines }
}

/// One new pick a day, the same for everyone, so a fact and a wine never repeat for months.
func dayNumber(_ date: Date) -> Int { Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0 }

/// The brand splash (the app's SplashMark, without the app's palette).
struct SplashMark: View {
    var color: Color
    var body: some View {
        ZStack { SplashBodyShape().fill(color); SplashDropShape().fill(color) }.aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Colors

extension Color {
    static func dyn(_ light: String, _ dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}
extension UIColor {
    convenience init(hex: String) {
        let s = hex.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}
/// The look chosen on the widget itself (Edit Widget > Appearance): 0 automatic, 1 white, 2 dark.
enum WTheme {
    static var current = 0
    static func pick(_ light: String, _ dark: String) -> Color {
        switch current {
        case 1: return Color(UIColor(hex: light))
        case 2: return Color(UIColor(hex: dark))
        default: return Color.dyn(light, dark)
        }
    }
}

enum WidgetThemeOption: String, AppEnum {
    case automatic, white, dark
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Appearance"
    static var caseDisplayRepresentations: [WidgetThemeOption: DisplayRepresentation] = [
        .automatic: "Automatic", .white: "White", .dark: "Dark",
    ]
    var index: Int { self == .white ? 1 : (self == .dark ? 2 : 0) }
}

struct ThemeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Appearance"
    static var description = IntentDescription("Automatic follows your phone; or always white, or always dark.")
    @Parameter(title: "Appearance", default: .automatic) var theme: WidgetThemeOption
}

enum WPalette {
    static var paper: Color { WTheme.pick("#F5F4F2", "#1A0910") }
    static var ink: Color { WTheme.pick("#1B0D12", "#F0D9C4") }
    static var soft: Color { WTheme.pick("#6B5C61", "#B8A394") }
    static var wine: Color { WTheme.pick("#8B1538", "#F0D9C4") }
    static let bordeaux = Color(UIColor(hex: "#8B1538"))
    static let deep = Color(UIColor(hex: "#5E0F26"))
}

// MARK: - Provider

struct DayEntry: TimelineEntry { let date: Date; var theme = 0 }

struct DailyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: .now) }
    func snapshot(for configuration: ThemeIntent, in context: Context) async -> DayEntry { DayEntry(date: .now, theme: configuration.theme.index) }
    func timeline(for configuration: ThemeIntent, in context: Context) async -> Timeline<DayEntry> {
        // one entry per day for two weeks, each starting at midnight
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        var entries = [DayEntry(date: .now, theme: configuration.theme.index)]
        for d in 1...14 { if let day = cal.date(byAdding: .day, value: d, to: start) { entries.append(DayEntry(date: day, theme: configuration.theme.index)) } }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Fun fact

struct FactView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family
    private var fact: String {
        let f = WidgetData.shared.facts
        return f.isEmpty ? "" : f[dayNumber(entry.date) % f.count]
    }
    var body: some View {
        let _ = (WTheme.current = entry.theme)
        let medium = family == .systemMedium
        VStack(alignment: .leading, spacing: medium ? 10 : 8) {
            HStack(spacing: 6) {
                SplashMark(color: WPalette.wine).frame(width: 16, height: 16)
                Text("DID YOU KNOW").font(.system(size: 9.5, weight: .semibold)).kerning(1.1).foregroundStyle(WPalette.wine)
            }
            Text(fact)
                .font(.system(size: medium ? 18 : 13.5, weight: .semibold))
                .foregroundStyle(WPalette.ink).lineSpacing(1.5)
                .minimumScaleFactor(0.7).lineLimit(medium ? 5 : 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { WPalette.paper }
        .widgetURL(URL(string: "jero://learn"))
    }
}

struct FactWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JeroFact", intent: ThemeIntent.self, provider: DailyProvider()) { FactView(entry: $0) }
            .configurationDisplayName("Wine fact of the day")
            .description("A new wine fun fact on your home screen every day.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}

// MARK: - Wine to try

struct WineView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family
    private var wine: WidgetWine? {
        let w = WidgetData.shared.wines
        return w.isEmpty ? nil : w[(dayNumber(entry.date) * 7 + 3) % w.count]
    }
    private func bottle(_ id: String) -> UIImage? {
        Bundle.main.path(forResource: id, ofType: "png", inDirectory: "Bottles").flatMap { UIImage(contentsOfFile: $0) }
    }
    private func detail(_ w: WidgetWine) -> String {
        var parts: [String] = []
        if let p = w.price { parts.append("About US$\(p)") }
        if let s = w.score { parts.append("\(s) pts") }
        return parts.joined(separator: " · ")
    }
    var body: some View {
        let _ = (WTheme.current = entry.theme)
        Group {
            if let w = wine {
                let medium = family == .systemMedium
                HStack(alignment: .center, spacing: medium ? 14 : 10) {
                    if let img = bottle(w.id) {
                        Image(uiImage: img).resizable().scaledToFit().frame(width: medium ? 52 : 38).shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                    }
                    VStack(alignment: .leading, spacing: medium ? 5 : 4) {
                        Text("WINE TO TRY").font(.system(size: 9.5, weight: .semibold)).kerning(1.1).foregroundStyle(WPalette.wine)
                        Text(w.name).font(.system(size: medium ? 18 : 13.5, weight: .bold)).foregroundStyle(WPalette.ink)
                            .lineLimit(medium ? 2 : 3).minimumScaleFactor(0.75)
                        Text(w.zone).font(.system(size: medium ? 12 : 10)).foregroundStyle(WPalette.soft).lineLimit(1)
                        if medium {
                            Text(w.why).font(.system(size: 12)).foregroundStyle(WPalette.ink.opacity(0.85)).lineLimit(3).lineSpacing(1)
                        }
                        Spacer(minLength: 0)
                        Text(detail(w)).font(.system(size: medium ? 11.5 : 9.5, weight: .semibold)).foregroundStyle(WPalette.wine).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .padding(16)
                .widgetURL(URL(string: "jero://wine/\(w.id)"))
            } else {
                Text("Open Jero to see a wine to try").font(.footnote).foregroundStyle(WPalette.soft)
            }
        }
        .containerBackground(for: .widget) { WPalette.paper }
    }
}

struct WineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JeroWine", intent: ThemeIntent.self, provider: DailyProvider()) { WineView(entry: $0) }
            .configurationDisplayName("Wine to try")
            .description("One great wine from the top 100 each day, with the story behind it.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}

@main
struct JeroWidgets: WidgetBundle {
    var body: some Widget {
        FactWidget()
        WineWidget()
    }
}
