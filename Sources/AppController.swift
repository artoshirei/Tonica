import AppKit
import KeyboardShortcuts

enum PanelToggleSource: String {
    case appLaunch
    case hotKey
    case menuBar
    case direct
}

@MainActor
final class AppController {
    static let shared = AppController()

    let model = AppModel()

    private var statusBarController: StatusBarController?
    private var panelController: FloatingPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var updaterController: AppUpdaterController?
    private var hotKeyDefaultsObserver: NSObjectProtocol?
    private var hasRegisteredHotKeyHandler = false

    private init() {}

    func start() {
        AppLogger.lifecycle.notice("Starting app controller")

        if statusBarController == nil {
            statusBarController = StatusBarController(controller: self)
            AppLogger.lifecycle.debug("Created status bar controller")
        }

        if panelController == nil {
            panelController = FloatingPanelController(model: model)
            AppLogger.panel.debug("Created floating panel controller")
        }

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(controller: self)
            AppLogger.lifecycle.debug("Created settings window controller")
        }

        if updaterController == nil {
            updaterController = AppUpdaterController()
            updaterController?.onUpdateCycleFinished = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.updateActivationPolicyIfNeeded(reason: "sparkleCycleFinished")
                }
            }
            AppLogger.lifecycle.debug("Created Sparkle updater controller")
        }

        PanelHotKey.ensureDefaultShortcut()
        refreshShortcutDescription()
        observeShortcutChangesIfNeeded()
        registerHotKeyHandlerIfNeeded()
        refreshStatusItem()
    }

    func togglePanel(source: PanelToggleSource = .direct) {
        AppLogger.panel.debug("Toggling panel from \(source.rawValue, privacy: .public)")

        if model.isPanelVisible {
            hidePanel()
        } else {
            revealPanel(source: source)
        }
    }

    func togglePanelFromMenuBar() {
        togglePanel(source: .menuBar)
    }

    func updateTheme(_ theme: PanelTheme) {
        guard model.theme != theme else { return }
        model.theme = theme
        AppLogger.lifecycle.notice("Updated panel theme to \(theme.title, privacy: .public)")
    }

    func openSettingsWindow() {
        start()
        AppLogger.lifecycle.notice("Opening settings window")
        setActivationPolicy(.regular, reason: "settingsOpen")
        settingsWindowController?.present()
    }

    func showAboutPanel() {
        start()
        AppLogger.lifecycle.notice("Opening about panel")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: AppMetadata.aboutPanelOptions)
    }

    func checkForUpdates() {
        start()
        AppLogger.updates.notice("Checking for updates with Sparkle")
        setActivationPolicy(.regular, reason: "sparkleCheck")
        updaterController?.checkForUpdates()
    }

    var canCheckForUpdates: Bool {
        updaterController?.canCheckForUpdates ?? false
    }

    func revealPanel(source: PanelToggleSource = .direct) {
        start()
        AppLogger.panel.notice("Revealing panel from \(source.rawValue, privacy: .public)")
        setActivationPolicy(.regular, reason: "reveal")
        panelController?.present()
        model.isPanelVisible = true
        refreshStatusItem()
    }

    func hidePanel() {
        AppLogger.panel.notice("Hiding panel")
        panelController?.dismiss()
        model.isPanelVisible = false
        updateActivationPolicyIfNeeded(reason: "hide")
        refreshStatusItem()
    }

    func panelDidClose() {
        AppLogger.panel.notice("Panel closed")
        model.isPanelVisible = false
        updateActivationPolicyIfNeeded(reason: "windowClose")
        refreshStatusItem()
    }

    func settingsDidClose() {
        AppLogger.lifecycle.notice("Settings window closed")
        updateActivationPolicyIfNeeded(reason: "settingsClose")
    }

    nonisolated private static func toggleFromHotKey() {
        Task { @MainActor in
            AppController.shared.togglePanel(source: .hotKey)
        }
    }

    func resetHotKeyToDefault() {
        PanelHotKey.resetToDefault()
        refreshShortcutDescription()
        refreshStatusItem()
        AppLogger.hotKey.notice("Reset panel hot key to default: \(self.model.shortcutDescription, privacy: .public)")
    }

    private func registerHotKeyHandlerIfNeeded() {
        guard !hasRegisteredHotKeyHandler else { return }
        hasRegisteredHotKeyHandler = true

        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            AppController.toggleFromHotKey()
        }

        AppLogger.hotKey.notice("Registered panel hot key handler for \(self.model.shortcutDescription, privacy: .public)")
    }

    private func observeShortcutChangesIfNeeded() {
        guard hotKeyDefaultsObserver == nil else { return }

        hotKeyDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleShortcutDefaultsChange()
            }
        }
    }

    private func handleShortcutDefaultsChange() {
        let previousDescription = model.shortcutDescription
        refreshShortcutDescription()
        guard model.shortcutDescription != previousDescription else { return }
        refreshStatusItem()
        AppLogger.hotKey.notice("Updated panel hot key to \(self.model.shortcutDescription, privacy: .public)")
    }

    private func refreshShortcutDescription() {
        model.shortcutDescription = PanelHotKey.description
    }

    private func refreshStatusItem() {
        statusBarController?.update(
            isPanelVisible: model.isPanelVisible,
            shortcutDescription: model.shortcutDescription
        )
    }

    private func setActivationPolicy(_ policy: NSApplication.ActivationPolicy, reason: String) {
        let didApply = NSApp.setActivationPolicy(policy)
        AppLogger.lifecycle.debug(
            "Activation policy -> \(policy.label, privacy: .public) [\(reason, privacy: .public)] success=\(didApply)"
        )
    }

    private func updateActivationPolicyIfNeeded(reason: String) {
        let settingsVisible = settingsWindowController?.window?.isVisible == true
        let policy: NSApplication.ActivationPolicy = (model.isPanelVisible || settingsVisible) ? .regular : .accessory
        setActivationPolicy(policy, reason: reason)
    }
}

private extension NSApplication.ActivationPolicy {
    var label: String {
        switch self {
        case .regular:
            return "regular"
        case .accessory:
            return "accessory"
        case .prohibited:
            return "prohibited"
        @unknown default:
            return "unknown"
        }
    }
}
