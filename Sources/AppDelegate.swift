import AppKit

enum AppRuntime {
    static let isPreview = Bundle.main.bundleIdentifier != "com.playground.tonica"
    static var canUpdate: Bool {
        #if DEBUG
        false
        #else
        !isPreview
        #endif
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.lifecycle.notice("Launched native AppKit Tonica \(AppMetadata.versionDescription, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")
        ProcessInfo.processInfo.disableAutomaticTermination("Keep menu bar app alive")
        NSApp.appearance = TonicaAppearance.appearance
        configureMenu()
        AppController.shared.start()
        if AppRuntime.isPreview || AppController.shared.model.showOnLaunch { AppController.shared.revealPanel(source: .appLaunch) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppController.shared.revealPanel(); return true
    }
    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        let about = NSMenuItem(title: "About Tonica", action: #selector(about), keyEquivalent: "")
        let settings = NSMenuItem(title: "Settings…", action: #selector(settings), keyEquivalent: ",")
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(updates), keyEquivalent: "")
        for item in [about, settings, updates] { item.target = self }
        updates.isEnabled = AppRuntime.canUpdate
        appMenu.autoenablesItems = false
        appMenu.items = [about, settings, updates, .separator(), NSMenuItem(title: "Hide Tonica", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"), NSMenuItem(title: "Quit Tonica", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")]
        appItem.submenu = appMenu; menu.addItem(appItem)
        let windowItem = NSMenuItem(); let windowMenu = NSMenu(title: "Window")
        let show = NSMenuItem(title: "Show Circle", action: #selector(showCircle), keyEquivalent: "1"); show.target = self
        windowMenu.items = [show, NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"), NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")]
        windowItem.submenu = windowMenu; menu.addItem(windowItem)
        NSApp.mainMenu = menu; NSApp.windowsMenu = windowMenu
    }
    @objc private func settings() { AppController.shared.openSettingsWindow() }
    @objc private func about() { AppController.shared.showAboutPanel() }
    @objc private func updates() { AppController.shared.checkForUpdates() }
    @objc private func showCircle() { AppController.shared.revealPanel() }
}
