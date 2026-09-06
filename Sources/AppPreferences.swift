import AppKit

@MainActor
enum TonicaAppearance {
    static let accent = NSColor(srgbRed: 0.64, green: 0.72, blue: 1, alpha: 1)
    static let background = NSColor(srgbRed: 0.045, green: 0.045, blue: 0.052, alpha: 1)
    static let surface = NSColor(srgbRed: 0.075, green: 0.075, blue: 0.085, alpha: 1)
    static let border = NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1)
    static let appearance = NSAppearance(named: .darkAqua)
}

enum Instrument: String, CaseIterable { case piano, guitar
    var title: String { rawValue.capitalized }
}

enum AppPreferences {
    static func loadPanelFrame() -> CGRect? {
        guard let f = UserDefaults.standard.dictionary(forKey: "panelFrame"),
              let x = f["x"] as? Double, let y = f["y"] as? Double,
              let w = f["width"] as? Double, let h = f["height"] as? Double,
              [x, y, w, h].allSatisfy(\.isFinite), w > 0, h > 0 else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
    static func savePanelFrame(_ frame: CGRect) {
        UserDefaults.standard.set(["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height], forKey: "panelFrame")
    }
}
