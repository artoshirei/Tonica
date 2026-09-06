import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private weak var controller: AppController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "Show Tonica", action: #selector(togglePanel), keyEquivalent: "")
    private let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    init(controller: AppController) {
        self.controller = controller
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        shortcutItem.isEnabled = false
        let title = NSMenuItem(title: "Tonica \(AppMetadata.versionDescription)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        let about = NSMenuItem(title: "About Tonica", action: #selector(openAbout), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit Tonica", action: #selector(quitApp), keyEquivalent: "q")
        for item in [toggleItem, updateItem, settings, about, quit] { item.target = self }
        menu.items = [title, toggleItem, shortcutItem, .separator(), settings, updateItem, about, .separator(), quit]
        guard let button = statusItem.button else { return }
        button.image = Self.makeStatusBarImage()
        button.imagePosition = .imageOnly
        button.target = self; button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel(AppRuntime.isPreview ? "Tonica Preview" : "Tonica")
        statusItem.isVisible = true
        AppLogger.lifecycle.notice("Installed static AppKit status item")
    }
    func update(isPanelVisible: Bool, shortcutDescription: String) {
        toggleItem.title = isPanelVisible ? "Hide Tonica" : "Show Tonica"
        shortcutItem.title = "Shortcut: \(shortcutDescription)"
        statusItem.button?.toolTip = "Tonica · \(shortcutDescription)\nClick to open. Right-click for settings and updates."
    }
    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { controller?.togglePanelFromMenuBar() }
    }
    func menuWillOpen(_ menu: NSMenu) { updateItem.isEnabled = controller?.canCheckForUpdates ?? false }
    @objc private func togglePanel() { controller?.togglePanelFromMenuBar() }
    @objc private func openSettings() { controller?.openSettingsWindow() }
    @objc private func checkForUpdates() { controller?.checkForUpdates() }
    @objc private func openAbout() { controller?.showAboutPanel() }
    @objc private func quitApp() { NSApp.terminate(nil) }
    private static func makeStatusBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { rect in
            NSColor.black.setStroke()
            for ratio: CGFloat in [1, 496.0 / 652.0, 292.0 / 652.0] {
                let d = 17 * ratio
                let p = NSBezierPath(ovalIn: NSRect(x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d))
                p.lineWidth = 1.3; p.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
