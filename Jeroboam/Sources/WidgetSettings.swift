import Foundation
import WidgetKit

/// The home-screen widgets' look (Automatic, White or Dark), chosen in the app and shared with the widgets through the App Group.
enum WidgetSettings {
    static let group = "group.com.ralphgeb.jero"
    static var theme: Int {
        get { UserDefaults(suiteName: group)?.integer(forKey: "widgetTheme") ?? UserDefaults.standard.integer(forKey: "widgetTheme") }
        set {
            UserDefaults(suiteName: group)?.set(newValue, forKey: "widgetTheme")
            UserDefaults.standard.set(newValue, forKey: "widgetTheme")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
