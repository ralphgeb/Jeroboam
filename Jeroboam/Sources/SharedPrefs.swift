import Foundation
import WidgetKit

/// Settings the widgets read too, kept in the shared app group.
enum SharedPrefs {
    static let group = "group.com.ralphgeb.jero"
    private static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    /// 0 automatic (follows the phone), 1 white, 2 dark.
    static var widgetTheme: Int {
        get { defaults.integer(forKey: "jero.widgetTheme") }
        set { defaults.set(newValue, forKey: "jero.widgetTheme"); WidgetCenter.shared.reloadAllTimelines() }
    }
}
