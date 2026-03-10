import Foundation
import SwiftUI

enum PanelTheme: String, CaseIterable, Identifiable {
    case midnight
    case ocean
    case ember

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight:
            return "Midnight"
        case .ocean:
            return "Ocean"
        case .ember:
            return "Ember"
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.06, green: 0.08, blue: 0.12),
                Color(red: 0.08, green: 0.12, blue: 0.20),
                Color(red: 0.12, green: 0.10, blue: 0.08)
            ]
        case .ocean:
            return [
                Color(red: 0.04, green: 0.10, blue: 0.16),
                Color(red: 0.05, green: 0.22, blue: 0.28),
                Color(red: 0.09, green: 0.16, blue: 0.18)
            ]
        case .ember:
            return [
                Color(red: 0.12, green: 0.07, blue: 0.06),
                Color(red: 0.22, green: 0.11, blue: 0.08),
                Color(red: 0.16, green: 0.08, blue: 0.12)
            ]
        }
    }

    var highlightColor: Color {
        switch self {
        case .midnight:
            return Color(red: 0.23, green: 0.55, blue: 0.98)
        case .ocean:
            return Color(red: 0.12, green: 0.78, blue: 0.72)
        case .ember:
            return Color(red: 0.96, green: 0.55, blue: 0.22)
        }
    }

    var accentGlowColor: Color {
        switch self {
        case .midnight:
            return Color(red: 0.96, green: 0.63, blue: 0.23)
        case .ocean:
            return Color(red: 0.48, green: 0.77, blue: 0.96)
        case .ember:
            return Color(red: 0.96, green: 0.76, blue: 0.25)
        }
    }
}

enum AppPreferences {
    private enum Key {
        static let theme = "theme"
        static let panelFrame = "panelFrame"
    }

    static func loadTheme() -> PanelTheme {
        let defaults = UserDefaults.standard

        guard let rawValue = defaults.string(forKey: Key.theme),
              let theme = PanelTheme(rawValue: rawValue) else {
            return .midnight
        }

        return theme
    }

    static func saveTheme(_ theme: PanelTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: Key.theme)
    }

    static func loadPanelFrame() -> CGRect? {
        let defaults = UserDefaults.standard

        guard let frame = defaults.dictionary(forKey: Key.panelFrame) else { return nil }
        guard let x = frame["x"] as? Double,
              let y = frame["y"] as? Double,
              let width = frame["width"] as? Double,
              let height = frame["height"] as? Double else {
            return nil
        }

        let rect = CGRect(x: x, y: y, width: width, height: height)
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    static func savePanelFrame(_ frame: CGRect) {
        UserDefaults.standard.set(
            [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.width,
                "height": frame.height
            ],
            forKey: Key.panelFrame
        )
    }
}
