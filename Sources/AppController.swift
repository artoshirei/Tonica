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
    private var isSettingsVisible = false

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

        if updaterController == nil && AppRuntime.canUpdate {
            updaterController = AppUpdaterController()
            updaterController?.onUpdateCycleFinished = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.updateActivationPolicyIfNeeded(reason: "sparkleCycleFinished")
                }
            }
            AppLogger.lifecycle.debug("Created Sparkle updater controller")
        }

        refreshShortcutDescription()
        if !AppRuntime.isPreview {
            observeShortcutChangesIfNeeded()
            registerHotKeyHandlerIfNeeded()
        }
        refreshStatusItem()
    }

    func togglePanel(source: PanelToggleSource = .direct) {
        AppLogger.panel.debug("Toggling panel from \(source.rawValue, privacy: .public)")

        if model.isPanelVisible && !NSApp.isHidden && panelController?.window?.isMiniaturized != true {
            hidePanel()
        } else {
            revealPanel(source: source)
        }
    }

    func togglePanelFromMenuBar() {
        togglePanel(source: .menuBar)
    }

    func openSettingsWindow() {
        start()
        AppLogger.lifecycle.notice("Opening settings window")
        setActivationPolicy(.regular, reason: "settingsOpen")
        isSettingsVisible = true
        settingsWindowController?.present()
    }

    func showAboutPanel() {
        start()
        AppLogger.lifecycle.notice("Opening about panel")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: AppMetadata.aboutPanelOptions)
    }

    func checkForUpdates() {
        guard AppRuntime.canUpdate else { return }
        start()
        AppLogger.updates.notice("Checking for updates with Sparkle")
        setActivationPolicy(.regular, reason: "sparkleCheck")
        updaterController?.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.automaticallyChecksForUpdates ?? false }
        set { updaterController?.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController?.automaticallyDownloadsUpdates ?? false }
        set { updaterController?.automaticallyDownloadsUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        updaterController?.canCheckForUpdates ?? false
    }

    func revealPanel(source: PanelToggleSource = .direct) {
        start()
        AppLogger.panel.notice("Revealing panel from \(source.rawValue, privacy: .public)")
        setActivationPolicy(.regular, reason: "reveal")
        NSApp.unhide(nil)
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
        isSettingsVisible = false
        AppLogger.lifecycle.notice("Settings window closed")
        updateActivationPolicyIfNeeded(reason: "settingsClose")
    }

    nonisolated private static func toggleFromHotKey() {
        Task { @MainActor in
            AppController.shared.togglePanel(source: .hotKey)
        }
    }

    func resetHotKeyToDefault() {
        guard !AppRuntime.isPreview else { return }
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
        model.shortcutDescription = AppRuntime.isPreview ? "Preview" : PanelHotKey.description
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
        let policy: NSApplication.ActivationPolicy = (model.isPanelVisible || isSettingsVisible) ? .regular : .accessory
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
